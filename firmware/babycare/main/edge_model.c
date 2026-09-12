// edge_model.c — see edge_model.h.
#include "edge_model.h"

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_timer.h"

#include "mel_spectrogram.h"
#include "cry_gate_inference.h"

static const char *TAG = "edge_model";

static mel_features_t *s_mel_features = NULL;
static bool s_available = false;
static float s_last_latency_ms = 0.0f;
static float s_last_mel_ms = 0.0f;
static float s_last_infer_ms = 0.0f;

// Real-hardware crash, 2026-08-10: a LoadProhibited panic on real
// ESP32-S3 hardware traced to concurrent calls into edge_model_score()
// from both cry_candidate_infer_task (Decision 1) and app_main's main
// task (Decision 2). Both mel_spectrogram.c (a single static s_mel_power
// buffer) and cry_gate_inference.cc (one TFLite Micro MicroInterpreter
// instance, not reentrant) use shared mutable state with no locking --
// this was previously masked by cry_candidate_infer_task running at a
// HIGHER priority than main, which meant main could never actually
// preempt it mid-call. Fixing the resulting starvation bug (see
// cry_candidate.c's task-creation comment) by making the two tasks equal
// priority made genuine interleaving possible for the first time, which
// is what actually triggered the crash -- both are real bugs, this one
// was just unreachable until the other was fixed. A mutex around the
// whole mel+inference sequence is the correct fix: enforce the mutual
// exclusion this module's shared state has always required, instead of
// relying on priority ordering to accidentally provide it.
static SemaphoreHandle_t s_model_mutex = NULL;

int edge_model_init(void) {
    if (mel_spectrogram_init() != 0) {
        ESP_LOGE(TAG, "mel_spectrogram_init failed -- edge model unavailable");
        return -1;
    }
    if (cry_gate_inference_init() != 0) {
        ESP_LOGE(TAG, "cry_gate_inference_init failed -- edge model unavailable");
        return -1;
    }
    s_mel_features = (mel_features_t *)heap_caps_malloc(sizeof(mel_features_t), MALLOC_CAP_SPIRAM);
    if (s_mel_features == NULL) {
        ESP_LOGE(TAG, "Failed to allocate mel features buffer in PSRAM -- edge model unavailable");
        return -1;
    }
    s_model_mutex = xSemaphoreCreateMutex();
    if (s_model_mutex == NULL) {
        ESP_LOGE(TAG, "Failed to create edge model mutex -- edge model unavailable");
        return -1;
    }
    s_available = true;
    ESP_LOGI(TAG, "Edge model ready (native %dHz, %d-sample window, threshold=%.2f)",
             CRY_GATE_SR, CRY_GATE_N_SAMPLES, (double)CRY_GATE_THRESHOLD);
    return 0;
}

bool edge_model_available(void) {
    return s_available;
}

float edge_model_score(const float *audio_n_samples) {
    if (!s_available) {
        return -1.0f;
    }
    // Serializes Decision 1 (cry_candidate_infer_task) and Decision 2
    // (app_main's main task) -- see s_model_mutex's declaration comment.
    // Worst-case wait is one full inference (~2.3s), not a busy-spin.
    xSemaphoreTake(s_model_mutex, portMAX_DELAY);

    // Split timing: real-hardware measurement (2026-08-10) found a 4x
    // reduction in the CNN's tensor arena (via an architecture change)
    // only cut TOTAL latency ~1.4x, well short of proportional -- strong
    // sign the CNN inference isn't actually the dominant cost. Splitting
    // mel-extraction time from inference time here to confirm which one
    // really dominates before changing anything else.
    int64_t t0 = esp_timer_get_time();
    if (mel_spectrogram_compute(audio_n_samples, s_mel_features) != 0) {
        ESP_LOGW(TAG, "mel_spectrogram_compute failed");
        xSemaphoreGive(s_model_mutex);
        return -1.0f;
    }
    int64_t t_mel = esp_timer_get_time();
    float score = cry_gate_inference_run(s_mel_features);
    int64_t t1 = esp_timer_get_time();
    s_last_mel_ms = (float)((t_mel - t0) / 1000.0);
    s_last_infer_ms = (float)((t1 - t_mel) / 1000.0);
    s_last_latency_ms = (float)((t1 - t0) / 1000.0);

    xSemaphoreGive(s_model_mutex);
    return score;
}

float edge_model_last_latency_ms(void) {
    return s_last_latency_ms;
}

float edge_model_last_mel_ms(void) {
    return s_last_mel_ms;
}

float edge_model_last_infer_ms(void) {
    return s_last_infer_ms;
}
