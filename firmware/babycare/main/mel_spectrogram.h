// mel_spectrogram.h — On-device log-mel spectrogram, bit-for-bit parity
// target with librosa.feature.melspectrogram + librosa.power_to_db as used
// in the production pipeline (D:\nxm\ML_pipeline\inference\preprocess.py)
// and ported host-side at D:\nxm\ML_pipeline_edge\export\preprocess.py.
//
// See D:\nxm\ML_pipeline_edge\docs\ENGINEERING_DECISIONS.md #4 for why this
// targets exact parity (precomputed filterbank) rather than an approximation.
#ifndef MEL_SPECTROGRAM_H_
#define MEL_SPECTROGRAM_H_

#include <stdint.h>
#include "cry_gate_params.h"

#ifdef __cplusplus
extern "C" {
#endif

// Output buffer layout: row-major [CRY_GATE_N_MEL][CRY_GATE_TARGET_T],
// z-score normalized, ready to be quantized and fed to the model.
typedef struct {
    float data[CRY_GATE_N_MEL * CRY_GATE_TARGET_T];
} mel_features_t;

// One-time setup: initializes the ESP-DSP FFT tables. Call once at startup.
// Returns ESP_OK on success.
int mel_spectrogram_init(void);

// Computes the normalized log-mel spectrogram of a fixed-length audio clip.
//
// audio: pointer to CRY_GATE_N_SAMPLES float32 samples, already:
//   - resampled to CRY_GATE_SR (22050 Hz) mono
//   - peak-normalized to [-1, 1]
//   - center-cropped or loop-tiled to exactly CRY_GATE_N_SAMPLES
// (i.e. equivalent to preprocess_audio() in the Python reference — this
// function only covers extract_mel() + normalize_mel()).
//
// out: destination for the (128, 431) normalized log-mel features.
//
// Returns 0 on success, negative on error (e.g. FFT not initialized).
int mel_spectrogram_compute(const float *audio, mel_features_t *out);

#ifdef __cplusplus
}
#endif

#endif  // MEL_SPECTROGRAM_H_
