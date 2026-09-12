// cry_gate_feature.c -- Two-decision ML cry-gate feature for BabyCare.
//
// Replaces the old single-shot design (capture first, score once, upload
// if passes) with the fully validated continuous-listening two-decision
// pipeline from examples/cry_gate_edge:
//
//   Mic (16kHz, via bsp_board codec, already running)
//     -> audio_capture_cry_task (continuous I2S reader, core 1)
//        -> chunk callback: cry_candidate_on_chunk()
//           -> Stage A: adaptive RMS energy gate (trigger.c)
//              -> if gate open: schedule Decision 1 inference
//                 -> cry_candidate_infer_task (core 0)
//                    -> Decision 1: edge16k ML model on rolling ~10s window
//                       -> if score >= threshold: audio_capture_cry_signal_trigger()
//                          -> audio_capture_cry starts capturing ~21.5s clip
//                             -> Decision 2: SAME model re-run 3x (start/center/end)
//                                -> NOT CRY: discard, short lockout, re-arm
//                                -> CRY: upload to Cloud Run, long lockout
//
// MQTT control: {"cmd":"start_cry_monitor"} / {"cmd":"stop_cry_monitor"}
// Mutex exclusion with on-demand recording and lullaby playback (shared I2S).
//
// NOTE: the 16kHz model matches the codec's native rate exactly -- NO I2S
// clock rate switch is needed. g_record_dev (bsp_board) is already at 16kHz.
#include "cry_gate_feature.h"

#include <stdbool.h>
#include <string.h>
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/idf_additions.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_task.h"

#include "trigger.h"
#include "edge_model.h"
#include "cry_candidate.h"
#include "audio_capture_cry.h"
#include "sd_upload.h"
#include "cry_gate_params.h"

static const char *TAG = "cry_gate_feature";

static volatile bool s_monitoring = false;
static volatile bool s_stop_requested = false;
static bool s_deps_initialized = false;

// From app_main.c -- mutual exclusion: cry-monitoring, recording, and
// lullaby playback share babycare's one physical I2S clock.
extern volatile bool g_audio_playing;
extern volatile bool recording_active;

// ----- Decision 2: re-score completed clip on 3 windows -----
// The clip (~21.5s) is longer than the model's 10s input, so we score
// start, center, and end windows and take the MAX score -- recall over
// precision, same principle as everywhere else.
#define DECISION2_N_WINDOWS 3

static bool run_decision2(const float *clip, int n_clip_samples) {
    if (!edge_model_available()) {
        // Fail open: model unavailable -> upload rather than silently discard
        ESP_LOGW(TAG, "Decision 2: edge model unavailable -- failing open (upload)");
        return true;
    }

    // Allocate a scratch window buffer (10s at 16kHz = CRY_GATE_N_SAMPLES)
    float *win = (float *)heap_caps_malloc(CRY_GATE_N_SAMPLES * sizeof(float), MALLOC_CAP_SPIRAM);
    if (win == NULL) {
        ESP_LOGE(TAG, "Decision 2: OOM -- failing open (upload)");
        return true;
    }

    // Window offsets: start, center, end (clamped to clip bounds)
    int offsets[DECISION2_N_WINDOWS];
    offsets[0] = 0;
    offsets[1] = (n_clip_samples - CRY_GATE_N_SAMPLES) / 2;
    offsets[2] =  n_clip_samples - CRY_GATE_N_SAMPLES;
    for (int w = 0; w < DECISION2_N_WINDOWS; w++) {
        if (offsets[w] < 0) offsets[w] = 0;
    }

    float max_score = -1.0f;
    for (int w = 0; w < DECISION2_N_WINDOWS; w++) {
        // Copy window and peak-normalize
        memcpy(win, clip + offsets[w], CRY_GATE_N_SAMPLES * sizeof(float));
        float peak = 0.0f;
        for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
            float a = fabsf(win[i]);
            if (a > peak) peak = a;
        }
        if (peak > 0.0f) {
            for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) win[i] /= peak;
        }

        float score = edge_model_score(win);
        ESP_LOGI(TAG, "Decision 2 window %d/%d: offset=%d score=%.4f",
                 w + 1, DECISION2_N_WINDOWS, offsets[w], (double)score);
        if (score > max_score) max_score = score;
    }

    heap_caps_free(win);

    bool is_cry = edge_model_is_cry(max_score);
    ESP_LOGI(TAG, "Decision 2 result: max_score=%.4f threshold=%.2f -> %s",
             (double)max_score, (double)CRY_GATE_THRESHOLD,
             is_cry ? "CRY -- uploading" : "NOT CRY -- discarding");
    return is_cry;
}

// ----- Main monitor task (Decision 2 + upload loop) -----
// Runs as app_main's task context -- blocks on audio_capture_cry_wait_for_clip().
static void monitor_task(void *pv) {
    if (!s_deps_initialized) {
        if (sd_upload_init() != 0) {
            ESP_LOGW(TAG, "SD unavailable -- accepted clips will upload directly (no spill)");
        }
        if (edge_model_init() != 0) {
            ESP_LOGE(TAG, "edge_model_init failed -- aborting cry monitor");
            s_monitoring = false;
            vTaskDelete(NULL);
            return;
        }
        s_deps_initialized = true;
    }

    // Start the continuous audio capture (core 1, uses bsp_board codec)
    if (audio_capture_cry_init() != 0) {
        ESP_LOGE(TAG, "audio_capture_cry_init failed -- aborting cry monitor");
        s_monitoring = false;
        vTaskDelete(NULL);
        return;
    }

    // Wire up the chunk pipeline: audio_capture_cry -> cry_candidate -> edge_model
    trigger_init(CRY_GATE_SR);
    cry_candidate_init();
    audio_capture_cry_set_chunk_callback(cry_candidate_on_chunk);

    ESP_LOGI(TAG, "Cry monitor started: continuous 16kHz listening, two-decision ML gate");

    while (!s_stop_requested) {
        audio_cry_clip_t clip;
        // Blocks until a clip is ready (trigger fired + 21.5s captured)
        if (audio_capture_cry_wait_for_clip(&clip) != 0) {
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        if (s_stop_requested) {
            audio_capture_cry_release_clip(false);
            break;
        }

        ESP_LOGI(TAG, "Clip ready: %d samples (%.1fs @ %dHz) -- running Decision 2",
                 clip.n_samples,
                 (double)clip.n_samples / (double)clip.sample_rate,
                 clip.sample_rate);

        bool is_cry = run_decision2(clip.audio, clip.n_samples);

        if (is_cry) {
            // sd_upload_save_and_queue expects exactly CRY_GATE_N_SAMPLES (10s).
            // The full clip is ~21.5s, so pick the center window -- this is the
            // window that Decision 2's majority vote most likely confirmed as cry.
            int center_offset = (clip.n_samples - CRY_GATE_N_SAMPLES) / 2;
            if (center_offset < 0) center_offset = 0;
            cloud_upload_ram_wav((float *)clip.audio + center_offset, CRY_GATE_N_SAMPLES, CRY_GATE_SR);
            ESP_LOGI(TAG, "Cry confirmed -- RAM upload sent (center window, offset=%d)", center_offset);
        } else {
            ESP_LOGI(TAG, "Not a cry -- clip discarded");
        }

        audio_capture_cry_release_clip(is_cry);
    }

    // Remove callback so the capture task stops dispatching decisions
    audio_capture_cry_set_chunk_callback(NULL);
    s_monitoring = false;
    ESP_LOGI(TAG, "Cry monitor stopped");
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
    vTaskDeleteWithCaps(NULL);
#else
    vTaskDelete(NULL);
#endif
}

// ----- Public API (unchanged from cry_gate_feature.h contract) -----
void cry_gate_feature_set_i2s_channels(i2s_chan_handle_t rx_chan,
                                        i2s_chan_handle_t tx_chan) {
    // Deprecated -- no-op. bsp_board codec handle used directly.
    (void)rx_chan; (void)tx_chan;
}

bool cry_gate_start_monitor(void) {
    if (s_monitoring) {
        ESP_LOGW(TAG, "Already monitoring");
        return false;
    }
    if (recording_active || g_audio_playing) {
        ESP_LOGW(TAG, "Cannot start cry monitor: recording or playback active "
                      "(shared I2S -- see cry_gate_feature.h)");
        return false;
    }
    s_stop_requested = false;
    s_monitoring = true;
    BaseType_t ok = pdFAIL;
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
    ok = xTaskCreateWithCaps(monitor_task, "cry_monitor", 8192, NULL, ESP_TASK_MAIN_PRIO, NULL, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
#endif
    if (ok != pdPASS) {
        ok = xTaskCreate(monitor_task, "cry_monitor", 8192, NULL, ESP_TASK_MAIN_PRIO, NULL);
    }
    if (ok != pdPASS) {
        ESP_LOGE(TAG, "Failed to create cry_monitor task");
        s_monitoring = false;
        return false;
    }
    return true;
}

void cry_gate_stop_monitor(void) {
    s_stop_requested = true;
}

bool cry_gate_is_monitoring(void) {
    return s_monitoring;
}
