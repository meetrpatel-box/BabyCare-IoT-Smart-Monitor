// trigger.c — Stage A only. See trigger.h for why Stage B/C (the previous
// DSP-only band-ratio cry classifier) was removed rather than re-tuned.
#include "trigger.h"

#include <math.h>
#include <string.h>

#include "esp_log.h"
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "trigger";

// alpha ~0.02/chunk gives roughly a 1.5s adaptation time constant.
// Calibrated defaults from the validated reference project.
#define NOISE_FLOOR_EMA_ALPHA     (20 / 1000.0f)       // 0.020
#define STAGE_A_TRIGGER_MULT      (160 / 100.0f)       // 1.6x noise floor (more responsive)
#define STAGE_A_ABS_MIN_RMS       (120 / 100000.0f)    // 0.0012 absolute min

static float s_noise_floor_ema = 0.0f;
static bool s_noise_floor_initialized = false;
static float s_last_rms = 0.0f;

void trigger_init(int sample_rate_hz) {
    (void)sample_rate_hz;
    s_noise_floor_ema = 0.0f;
    s_noise_floor_initialized = false;
    s_last_rms = 0.0f;
    ESP_LOGI(TAG, "trigger_init: Stage A energy gate only (mult=%.2fx floor, abs_min=%.5f)",
             (double)STAGE_A_TRIGGER_MULT, (double)STAGE_A_ABS_MIN_RMS);
}

static float chunk_rms(const float *x, int n) {
    double sum_sq = 0.0;
    for (int i = 0; i < n; i++) {
        sum_sq += (double)x[i] * (double)x[i];
    }
    return sqrtf((float)(sum_sq / (n > 0 ? n : 1)));
}

bool trigger_stage_a_gate(const float *mono, int n_frames) {
    float rms = chunk_rms(mono, n_frames);
    s_last_rms = rms;

    if (!s_noise_floor_initialized) {
        s_noise_floor_ema = rms;
        s_noise_floor_initialized = true;
    }

    float threshold = fmaxf(s_noise_floor_ema * STAGE_A_TRIGGER_MULT, STAGE_A_ABS_MIN_RMS);
    bool gate_open = (rms > threshold);

    // Freeze the floor estimate while the gate is open -- only let it drift
    // down during genuinely quiet stretches, never up mid-event.
    if (!gate_open) {
        s_noise_floor_ema = (1.0f - NOISE_FLOOR_EMA_ALPHA) * s_noise_floor_ema + NOISE_FLOOR_EMA_ALPHA * rms;
    }

    static TickType_t s_last_log_tick = 0;
    TickType_t now = xTaskGetTickCount();
    if (gate_open || (now - s_last_log_tick >= pdMS_TO_TICKS(5000))) {
        s_last_log_tick = now;
        ESP_LOGI(TAG, "Mic Energy: RMS=%.5f (thr=%.5f floor=%.5f) -> %s",
                 (double)rms, (double)threshold, (double)s_noise_floor_ema,
                 gate_open ? "GATE OPEN (SOUND)" : "quiet");
    }

    return gate_open;
}

void trigger_get_energy_info(float *out_rms, float *out_noise_floor) {
    if (out_rms) *out_rms = s_last_rms;
    if (out_noise_floor) *out_noise_floor = s_noise_floor_ema;
}
