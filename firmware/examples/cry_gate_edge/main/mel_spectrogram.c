// mel_spectrogram.c — see mel_spectrogram.h for the parity contract this
// implementation targets.
//
// Implementation notes (each one is a place a naive port silently diverges
// from librosa — call these out explicitly rather than let them hide):
//
// 1. Window: librosa's default window='hann' is generated with
//    scipy.signal.get_window(..., fftbins=True), i.e. the *periodic*
//    (DFT-even) Hann window: w[n] = 0.5*(1 - cos(2*pi*n/N)), n=0..N-1.
//    This is NOT the symmetric textbook Hann window (which divides by
//    N-1) — using N-1 here would silently shift every frame's spectrum.
//
// 2. Framing: librosa's melspectrogram/stft uses center=True by default,
//    so frame t is centered at sample t*hop_length, which is why 431
//    frames come out of a 220500-sample clip: 1 + floor(N/hop). The pad
//    mode is librosa's default `pad_mode='constant'` (i.e. ZERO-padding
//    by n_fft/2 samples on both ends) — NOT 'reflect'. This was verified
//    empirically against librosa 0.11.0 (export/validate_firmware_algorithms.py,
//    ML_pipeline_edge/benchmarks/firmware_algorithm_validation_report.json):
//    'reflect' padding produced avg_max_abs_diff=0.83 (worst 2.61) against
//    ground truth in normalized units, while 'constant' padding matched
//    exactly (diff ~0.0). Earlier revisions of this file assumed 'reflect'
//    based on stale knowledge of librosa's old default — that assumption
//    was wrong and is the reason this validation step exists at all.
//
// 3. Normalization reference: librosa.power_to_db(mel + 1e-6, ref=np.max)
//    uses a SINGLE global max over the entire (128, 431) mel power array
//    as the reference — not a per-frame or per-bin max. That means the
//    full spectrogram must be computed before any element can be
//    converted to dB; this cannot be streamed frame-by-frame.
//
// 4. top_db clipping: librosa's power_to_db defaults to top_db=80.0.
//    Because ref=np.max makes the post-subtraction max exactly 0.0, the
//    clip simplifies to `max(log_spec, -80.0)` — implemented directly
//    below rather than literally computing log_spec.max() again.

#include "mel_spectrogram.h"

#include <math.h>
#include <string.h>
#include <stdbool.h>

#include "esp_err.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "dsps_fft2r.h"

#include "mel_filterbank_data.h"
#include "norm_stats_data.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static const char *TAG = "mel_spectrogram";

#define N_FFT       CRY_GATE_N_FFT          // 2048
#define HOP_LENGTH  CRY_GATE_HOP_LENGTH      // 512
#define N_FREQ      MEL_FB_N_FREQ            // 1025 = N_FFT/2 + 1
#define N_MEL       CRY_GATE_N_MEL           // 128
#define TARGET_T    CRY_GATE_TARGET_T        // 431
#define N_SAMPLES   CRY_GATE_N_SAMPLES        // 220500

static float s_hann_window[N_FFT];
static bool  s_initialized = false;

// mel_power holds the full (128, 431) linear-power spectrogram — kept
// entirely in memory because the dB conversion needs the global max
// (see note #3 above) before any single element can be finalized.
// 128*431*4 bytes = ~220 KB — allocated from PSRAM, not the small internal
// SRAM heap.
static float *s_mel_power = NULL;

int mel_spectrogram_init(void) {
    if (s_initialized) {
        return ESP_OK;
    }

    esp_err_t err = dsps_fft2r_init_fc32(NULL, N_FFT);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "dsps_fft2r_init_fc32 failed: %d", err);
        return err;
    }

    // Periodic Hann window (fftbins=True), NOT the symmetric variant.
    for (int n = 0; n < N_FFT; n++) {
        s_hann_window[n] = 0.5f * (1.0f - cosf(2.0f * (float)M_PI * n / N_FFT));
    }

    s_mel_power = (float *)heap_caps_malloc(
        (size_t)N_MEL * TARGET_T * sizeof(float), MALLOC_CAP_SPIRAM);
    if (s_mel_power == NULL) {
        ESP_LOGE(TAG, "Failed to allocate mel_power buffer in PSRAM");
        return ESP_ERR_NO_MEM;
    }

    s_initialized = true;
    return ESP_OK;
}

// Zero-pad sample lookup, matching librosa's actual default pad_mode=
// 'constant' (verified against librosa 0.11.0 — see file header note #2).
// Samples outside [0, N_SAMPLES) read as 0.0, matching numpy's
// mode='constant' (default fill value 0).
static inline float padded_sample(const float *audio, int idx) {
    if (idx < 0 || idx >= N_SAMPLES) {
        return 0.0f;
    }
    return audio[idx];
}

int mel_spectrogram_compute(const float *audio, mel_features_t *out) {
    if (!s_initialized || s_mel_power == NULL) {
        ESP_LOGE(TAG, "mel_spectrogram_init() was not called");
        return -1;
    }

    // FFT working buffer: interleaved [Re0, Im0, Re1, Im1, ...], N_FFT
    // complex points. Allocated once per call from PSRAM to keep the
    // internal-SRAM footprint small; this function is not on a hot loop
    // (runs once per 10s clip).
    float *fft_buf = (float *)heap_caps_malloc(2 * N_FFT * sizeof(float), MALLOC_CAP_SPIRAM);
    if (fft_buf == NULL) {
        ESP_LOGE(TAG, "Failed to allocate FFT buffer");
        return -1;
    }

    const int half_window = N_FFT / 2;  // 1024, centered framing offset

    for (int t = 0; t < TARGET_T; t++) {
        int center = t * HOP_LENGTH;

        for (int n = 0; n < N_FFT; n++) {
            int sample_idx = center - half_window + n;
            float sample = padded_sample(audio, sample_idx);
            fft_buf[2 * n]     = sample * s_hann_window[n];  // Re
            fft_buf[2 * n + 1] = 0.0f;                        // Im
        }

        dsps_fft2r_fc32(fft_buf, N_FFT);
        dsps_bit_rev_fc32(fft_buf, N_FFT);

        // Power spectrum for bins 0..N_FFT/2 (1025 bins) — real input means
        // the upper half is redundant (Hermitian symmetry), matching
        // librosa/numpy.rfft-based STFT which only keeps these bins.
        float power[N_FREQ];
        for (int k = 0; k < N_FREQ; k++) {
            float re = fft_buf[2 * k];
            float im = fft_buf[2 * k + 1];
            power[k] = re * re + im * im;
        }

        // Apply the precomputed librosa mel filterbank (dense matmul).
        for (int m = 0; m < N_MEL; m++) {
            const float *row = &g_mel_filterbank[m * N_FREQ];
            float acc = 0.0f;
            for (int k = 0; k < N_FREQ; k++) {
                acc += row[k] * power[k];
            }
            s_mel_power[m * TARGET_T + t] = acc;
        }
    }

    heap_caps_free(fft_buf);

    // Global max over (mel_power + 1e-6), exactly matching
    // librosa.power_to_db(mel + 1e-6, ref=np.max). See note #3.
    float global_max = -INFINITY;
    for (int i = 0; i < N_MEL * TARGET_T; i++) {
        float s = s_mel_power[i] + 1e-6f;
        if (s > global_max) {
            global_max = s;
        }
    }
    const float amin = 1e-10f;
    if (global_max < amin) {
        global_max = amin;
    }
    float ref_db = 10.0f * log10f(global_max);

    // dB conversion + top_db=80 clip (simplifies to max(., -80) — note #4)
    // + z-score normalize per mel bin using the production norm_stats.
    for (int m = 0; m < N_MEL; m++) {
        float mean = g_mel_mean[m];
        float std  = g_mel_std[m];
        if (std < 1e-8f) {
            std = 1.0f;
        }
        for (int t = 0; t < TARGET_T; t++) {
            float s = s_mel_power[m * TARGET_T + t] + 1e-6f;
            if (s < amin) {
                s = amin;
            }
            float log_spec = 10.0f * log10f(s) - ref_db;
            if (log_spec < -80.0f) {
                log_spec = -80.0f;
            }
            out->data[m * TARGET_T + t] = (log_spec - mean) / std;
        }
    }

    return 0;
}
