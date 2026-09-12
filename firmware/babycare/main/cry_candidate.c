// cry_candidate.c — see cry_candidate.h.
//
// IMPORTANT (real hardware finding, 2026-08-07): an earlier version of this
// file ran edge_model_score() directly inside cry_candidate_on_chunk(),
// which is called synchronously from audio_capture.c's time-critical I2S
// read task. On real ESP32-S3 Korvo-2 hardware this tripped the task
// watchdog (~16s after boot, right as the rolling window first warmed up
// and the first inference call ran) -- mel+inference took long enough to
// starve the I2S read loop. This is not a tuning problem, it's a hard
// architectural rule: nothing slow/variable-latency may run inline in that
// task. Fixed by moving the actual ML call onto its own dedicated task
// (cry_candidate_infer_task below); the chunk callback only ever does cheap
// O(chunk) work (ring write + Stage A gate) and, when it decides an
// inference is worth running, wakes the inference task via a semaphore and
// returns immediately. The inference task, once it decides CRY, calls
// audio_capture_signal_trigger() to arm a capture asynchronously -- see
// audio_capture.h for that side of the contract.
#include "cry_candidate.h"

#include <math.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/idf_additions.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_timer.h"
#include "esp_task.h"  // ESP_TASK_MAIN_PRIO
#include "sdkconfig.h"

#include "trigger.h"
#include "edge_model.h"
#include "audio_capture_cry.h"  // audio_capture_cry_signal_trigger()
#include "mel_spectrogram.h"   // CRY_GATE_N_SAMPLES

static const char *TAG = "cry_candidate";

// Rolling window = exactly the model's fixed input length (10s native
// 16kHz). Rate-limit between inference REQUESTS while Stage A stays open,
// so a sustained loud sound (e.g. someone talking for a minute) asks for
// the classifier periodically rather than every single ~32ms chunk --
// bounds how often the (now off-hot-path, but still real) inference work
// happens. PROVISIONAL like every other timing constant in this firmware.
// Rate-limit: run inference at most once per 3000ms while Stage A is open.
// Prevents back-to-back mel+CNN calls during sustained loud sounds.
#define MIN_INFER_INTERVAL_MS  3000

static float *s_ring = NULL;          /* PSRAM, CRY_GATE_N_SAMPLES floats -- written by the capture task only */
static int s_ring_write_idx = 0;
static long long s_ring_samples_written = 0;  /* saturates at CRY_GATE_N_SAMPLES to mark "filled" */

static float *s_scratch = NULL;       /* PSRAM, CRY_GATE_N_SAMPLES floats -- linearized window + normalize, infer task only */

static int64_t s_last_infer_request_us = 0;

static float s_last_score = -1.0f;
static float s_last_latency_ms = 0.0f;

// Binary semaphore: the capture task (cheap, hot path) gives it to request
// an inference; cry_candidate_infer_task (its own, lower-priority task)
// takes it and does the real work. A request arriving while one is already
// pending is naturally coalesced (giving an already-full binary semaphore
// is a no-op) rather than queued -- exactly the desired behavior, since a
// rolling ~10s window a few chunks staler by the time the task gets to it
// is inconsequential.
static SemaphoreHandle_t s_infer_request_sem = NULL;

static void cry_candidate_infer_task(void *arg);

void cry_candidate_init(void) {
    s_ring = (float *)heap_caps_malloc(CRY_GATE_N_SAMPLES * sizeof(float), MALLOC_CAP_SPIRAM);
    s_scratch = (float *)heap_caps_malloc(CRY_GATE_N_SAMPLES * sizeof(float), MALLOC_CAP_SPIRAM);
    s_infer_request_sem = xSemaphoreCreateBinary();
    if (s_ring == NULL || s_scratch == NULL || s_infer_request_sem == NULL) {
        ESP_LOGE(TAG, "OOM allocating rolling-window buffers/semaphore -- "
                      "cry candidate detection cannot run");
        return;
    }
    s_ring_write_idx = 0;
    s_ring_samples_written = 0;
    s_last_infer_request_us = 0;

    // Pinned to core 0 -- the SAME core as app_main's main task
    // (CONFIG_ESP_MAIN_TASK_AFFINITY_CPU0=y) and explicitly NOT core 1
    // (audio_capture_task's pinned core, priority 10, time-critical I2S
    // reads -- this task must never contend with that one). Generous stack
    // (matches CONFIG_ESP_MAIN_TASK_STACK_SIZE's reasoning: TFLite Micro +
    // FFT need more than the 3584-byte IDF default) since
    // mel_spectrogram_compute() + cry_gate_inference_run()'s C++ call
    // chain is the same class of work that justified that constant
    // elsewhere in this firmware.
    //
    // Priority: real-hardware finding, 2026-08-10 -- an earlier version
    // used priority 4, ABOVE app_main's main task (ESP_TASK_MAIN_PRIO ==
    // 1, see esp_task.h). Since main is pinned to core 0 and this task can
    // also land on core 0, during sustained rapid triggering (repeated
    // household bangs/knocks) this task stayed continuously ready and
    // being higher priority than main, it could occupy core 0 exclusively
    // for 40+ seconds straight -- main (which runs Decision 2) never got
    // scheduled at all, repeatedly tripping the watchdog even with a 20ms
    // yield point (the yield only guarantees a context-switch opportunity,
    // not that the SPECIFIC lower-priority task waiting -- main -- is the
    // one that gets it over IDLE0 or anything else same-or-higher
    // priority). Matching main's own priority instead makes FreeRTOS
    // round-robin between them fairly whenever both are ready, so neither
    // can starve the other.
    BaseType_t ok = pdFAIL;
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
    ok = xTaskCreatePinnedToCoreWithCaps(cry_candidate_infer_task, "cry_infer", 8192, NULL,
                                         ESP_TASK_MAIN_PRIO, NULL, 0, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
#endif
    if (ok != pdPASS) {
        ok = xTaskCreatePinnedToCore(cry_candidate_infer_task, "cry_infer", 8192, NULL,
                                     ESP_TASK_MAIN_PRIO, NULL, 0);
    }
    if (ok != pdPASS) {
        ESP_LOGE(TAG, "Failed to create cry_infer task");
    }

    ESP_LOGI(TAG, "cry_candidate_init: %d-sample (%.1fs) rolling window @ %dHz, "
                  "min_infer_interval=%dms, inference runs on its own task (not the I2S task)",
             CRY_GATE_N_SAMPLES, (double)CRY_GATE_N_SAMPLES / (double)CRY_GATE_SR,
             CRY_GATE_SR, MIN_INFER_INTERVAL_MS);
}

static void ring_write(const float *mono, int n_frames) {
    int idx = s_ring_write_idx;
    for (int i = 0; i < n_frames; i++) {
        s_ring[idx] = mono[i];
        idx = (idx + 1) % CRY_GATE_N_SAMPLES;
    }
    s_ring_write_idx = idx;
    if (s_ring_samples_written < CRY_GATE_N_SAMPLES) {
        s_ring_samples_written += n_frames;
    }
}

// Copies the ring into s_scratch in chronological order (oldest-first) and
// peak-normalizes it, matching preprocess_audio()'s normalization contract
// (see edge_model.h). s_ring_write_idx always points at the next slot to be
// overwritten, i.e. the oldest sample currently in the (always-full once
// warmed-up) ring. Called only from cry_candidate_infer_task while the
// capture task keeps writing concurrently -- a torn/slightly-stale read of
// a few samples at the boundary is possible and harmless (same tolerance
// already documented for trigger_get_last_arm_info() elsewhere in this
// firmware); nothing here needs a lock.
static void linearize_and_normalize(void) {
    int idx = s_ring_write_idx;
    for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
        s_scratch[i] = s_ring[idx];
        idx = (idx + 1) % CRY_GATE_N_SAMPLES;
    }
    float peak = 0.0f;
    for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
        float a = fabsf(s_scratch[i]);
        if (a > peak) peak = a;
    }
    if (peak > 0.0f) {
        for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
            s_scratch[i] /= peak;
        }
    }
}

// Runs on its own task -- never the I2S read task. Blocks waiting for a
// request, does the real mel+inference work (the slow, variable-latency
// part that must not run inline in audio_capture_task), and asynchronously
// arms a capture via audio_capture_signal_trigger() if the window scores
// as CRY.
static void cry_candidate_infer_task(void *arg) {
    for (;;) {
        xSemaphoreTake(s_infer_request_sem, portMAX_DELAY);

        // Explicit yield point (real-hardware finding, 2026-08-10): during
        // sustained loud sound, a new request is already pending the
        // instant one inference finishes (inference itself, ~2.3s, is
        // longer than the rate-limit interval), so xSemaphoreTake above
        // can return immediately rather than actually blocking -- back-
        // to-back iterations with no yield point occasionally starved
        // IDLE0 long enough to trip the task watchdog. A 1ms delay here
        // measurably reduced (but did not eliminate) the trips; widened to
        // 20ms for a comfortable margin -- still negligible against a
        // ~2.3s inference call, and CONFIG_ESP_TASK_WDT_TIMEOUT_S was also
        // raised (sdkconfig.defaults) as defense in depth.
        vTaskDelay(pdMS_TO_TICKS(20));

        linearize_and_normalize();
        float score = edge_model_score(s_scratch);
        s_last_score = score;
        s_last_latency_ms = edge_model_last_latency_ms();

        float rms = 0.0f, noise_floor = 0.0f;
        trigger_get_energy_info(&rms, &noise_floor);

        if (score < 0.0f) {
            ESP_LOGW(TAG, "edge_model_score failed (ret=%.3f) -- treating as not-cry this window",
                     (double)score);
            continue;
        }

        bool is_cry = edge_model_is_cry(score);
        ESP_LOGI(TAG, "candidate window: score=%.4f (thr=%.2f) latency=%.1fms (mel=%.1fms infer=%.1fms) "
                      "rms=%.4f floor=%.4f -> %s",
                 (double)score, (double)CRY_GATE_THRESHOLD, (double)s_last_latency_ms,
                 (double)edge_model_last_mel_ms(), (double)edge_model_last_infer_ms(),
                 (double)rms, (double)noise_floor, is_cry ? "CRY CANDIDATE" : "not cry");

        if (is_cry) {
            audio_capture_cry_signal_trigger();
        }
    }
}

bool cry_candidate_on_chunk(const float *mono, int n_frames) {
    if (s_ring == NULL || s_scratch == NULL || s_infer_request_sem == NULL) {
        return false;  // init failed -- see cry_candidate_init() log
    }

    ring_write(mono, n_frames);

    bool gate_open = trigger_stage_a_gate(mono, n_frames);
    if (!gate_open) {
        return false;
    }
    if (!edge_model_available()) {
        // Fail OPEN, not closed: Decision 1 has no DSP fallback anymore (see
        // trigger.h's history note), so if the edge model failed to load,
        // the only alternative to "silently detect zero cries, forever,
        // with no fallback" is to trigger on Stage A's raw energy gate
        // alone -- over-triggers on any loud sound, but that is a visible,
        // recoverable failure mode (extra captures/uploads to notice and
        // fix), unlike total silent monitoring failure, which directly
        // violates "do not miss a real cry". Decision 2 (app_main.c) still
        // runs its own edge_model_available() check independently and
        // fails open there too (uploads rather than silently discarding).
        // This is the ONLY case where this function returns true directly
        // (synchronous, cheap) -- the ML path below always goes through
        // the async request/signal mechanism instead.
        static bool warned = false;
        if (!warned) {
            ESP_LOGE(TAG, "Edge model unavailable -- DEGRADED MODE: triggering on raw energy "
                          "(Stage A) alone, no cry-specific discrimination. Fix the edge model.");
            warned = true;
        }
        return gate_open;
    }
    if (s_ring_samples_written < CRY_GATE_N_SAMPLES) {
        return false;  // rolling window not warmed up yet (first ~10s after boot)
    }

    int64_t now_us = esp_timer_get_time();
    if (s_last_infer_request_us != 0 &&
        (now_us - s_last_infer_request_us) < (int64_t)MIN_INFER_INTERVAL_MS * 1000) {
        return false;  // rate-limited
    }
    s_last_infer_request_us = now_us;

    xSemaphoreGive(s_infer_request_sem);  // wake cry_candidate_infer_task; never blocks
    return false;  // the actual trigger, if any, arrives asynchronously later
}

void cry_candidate_get_last_info(float *out_score, float *out_latency_ms,
                                  float *out_rms, float *out_noise_floor) {
    if (out_score) *out_score = s_last_score;
    if (out_latency_ms) *out_latency_ms = s_last_latency_ms;
    if (out_rms || out_noise_floor) {
        trigger_get_energy_info(out_rms, out_noise_floor);
    }
}
