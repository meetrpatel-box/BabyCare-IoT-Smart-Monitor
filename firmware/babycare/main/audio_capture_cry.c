// audio_capture_cry.c -- Continuous cry-gate audio capture adapted for
// babycare's existing bsp_board codec stack.
//
// Uses esp_codec_dev_read() on g_record_dev (the handle bsp_board created)
// instead of raw i2s_channel_read(), so we do NOT reinitialise I2C or I2S.
// The codec is already running at 16kHz (SAMPLE_RATE 16000 in app_main.c),
// which matches CRY_GATE_SR exactly -- no rate switch needed.
//
// State machine: IDLE -> CAPTURING -> READY -> LOCKOUT -> IDLE
// Transitions driven by the chunk callback (cry_candidate_on_chunk) and/or
// an async trigger from cry_candidate_infer_task.
#include "audio_capture_cry.h"

#include <string.h>
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/idf_additions.h"

#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_codec_dev.h"

#include "bsp_board.h"
#include "camera_stream.h"

static const char *TAG = "audio_capture_cry";

// Chunk size: ~32ms at 16kHz = 512 frames.
#define CAPTURE_CHUNK_FRAMES  512
// bsp_board reads 4-channel 16-bit: 512 frames x 4 ch x 2 bytes = 4096 bytes
#define CAPTURE_READ_BYTES    (CAPTURE_CHUNK_FRAMES * 4 * sizeof(int16_t))

// Pre-roll ring length in samples
#define PREROLL_N_SAMPLES  ((CRY_CAPTURE_PREROLL_MS * CRY_CAPTURE_SR) / 1000)

typedef enum {
    CAP_STATE_IDLE = 0,
    CAP_STATE_CAPTURING,
    CAP_STATE_READY,
    CAP_STATE_LOCKOUT,
} cap_state_t;

static float *s_preroll_ring   = NULL;  // PSRAM, PREROLL_N_SAMPLES floats
static float *s_active_clip    = NULL;  // PSRAM, CRY_CLIP_N_SAMPLES floats
static int    s_preroll_write_idx = 0;
static int    s_preroll_written   = 0;

static volatile cap_state_t  s_state = CAP_STATE_IDLE;
static volatile bool         s_async_trigger_pending = false;
static int                   s_clip_samples_written = 0;
static SemaphoreHandle_t     s_state_mutex   = NULL;
static SemaphoreHandle_t     s_clip_ready_sem = NULL;

static audio_capture_cry_chunk_cb_t s_chunk_cb = NULL;

static TickType_t s_lockout_start_tick   = 0;
static uint32_t   s_lockout_duration_ms  = CRY_LOCKOUT_MS;

// ----- Pre-roll ring -----
static void preroll_ring_write(const float *mono, int n_frames) {
    for (int i = 0; i < n_frames; i++) {
        s_preroll_ring[s_preroll_write_idx] = mono[i];
        s_preroll_write_idx = (s_preroll_write_idx + 1) % PREROLL_N_SAMPLES;
    }
    if (s_preroll_written < PREROLL_N_SAMPLES) {
        s_preroll_written += n_frames;
        if (s_preroll_written > PREROLL_N_SAMPLES) s_preroll_written = PREROLL_N_SAMPLES;
    }
}

static void preroll_snapshot_into_clip(void) {
    // Copy oldest-first from ring into front of active clip
    int actual = s_preroll_written < PREROLL_N_SAMPLES ? s_preroll_written : PREROLL_N_SAMPLES;
    int start  = (s_preroll_write_idx - actual + PREROLL_N_SAMPLES) % PREROLL_N_SAMPLES;
    for (int i = 0; i < actual; i++) {
        s_active_clip[i] = s_preroll_ring[(start + i) % PREROLL_N_SAMPLES];
    }
    s_clip_samples_written = actual;
}

// ----- State machine step (called under s_state_mutex) -----
static void capture_state_step(const float *mono, int n_frames,
                                bool trigger_fired) {
    bool async_trigger = s_async_trigger_pending;
    if (async_trigger) s_async_trigger_pending = false;

    switch (s_state) {
        case CAP_STATE_IDLE:
            if (trigger_fired || async_trigger) {
                preroll_snapshot_into_clip();
                s_state = CAP_STATE_CAPTURING;
                ESP_LOGI(TAG, "Trigger! Pre-roll=%d samples, starting %ds capture",
                         s_clip_samples_written, CRY_CAPTURE_POST_TRIGGER_MS / 1000);
            }
            break;

        case CAP_STATE_CAPTURING: {
            int space = CRY_CLIP_N_SAMPLES - s_clip_samples_written;
            int copy  = n_frames < space ? n_frames : space;
            memcpy(&s_active_clip[s_clip_samples_written], mono, copy * sizeof(float));
            s_clip_samples_written += copy;
            if (s_clip_samples_written >= CRY_CLIP_N_SAMPLES) {
                // Peak-normalize the full clip
                float peak = 0.0f;
                for (int i = 0; i < CRY_CLIP_N_SAMPLES; i++) {
                    float a = fabsf(s_active_clip[i]);
                    if (a > peak) peak = a;
                }
                if (peak > 0.0f) {
                    for (int i = 0; i < CRY_CLIP_N_SAMPLES; i++) s_active_clip[i] /= peak;
                }
                s_state = CAP_STATE_READY;
                ESP_LOGI(TAG, "Clip complete: %d samples (%.1fs)",
                         CRY_CLIP_N_SAMPLES,
                         (double)CRY_CLIP_N_SAMPLES / (double)CRY_CAPTURE_SR);
                xSemaphoreGive(s_clip_ready_sem);
            }
            break;
        }

        case CAP_STATE_READY:
            if (trigger_fired || async_trigger) {
                ESP_LOGW(TAG, "Trigger while previous clip awaiting consumption -- dropped");
            }
            break;

        case CAP_STATE_LOCKOUT:
            if ((xTaskGetTickCount() - s_lockout_start_tick) >=
                    pdMS_TO_TICKS(s_lockout_duration_ms)) {
                s_state = CAP_STATE_IDLE;
                ESP_LOGI(TAG, "Lockout ended -- re-armed");
            }
            break;
    }
}

// ----- Feed mono PCM16 from unified mic stream -----
extern volatile bool g_audio_playing;
static bool s_initialized = false;

void audio_capture_cry_feed_pcm16(const int16_t *pcm16, int n_samples) {
    if (!s_initialized || !s_preroll_ring || !s_active_clip || !s_state_mutex || !pcm16 || n_samples <= 0) {
        return;
    }
    // Don't detect cries while speaker is playing lullaby to prevent acoustic self-trigger
    if (g_audio_playing) {
        return;
    }

    float chunk[CAPTURE_CHUNK_FRAMES];
    int offset = 0;
    while (offset < n_samples) {
        int frames = (n_samples - offset < CAPTURE_CHUNK_FRAMES) ? (n_samples - offset) : CAPTURE_CHUNK_FRAMES;
        for (int i = 0; i < frames; i++) {
            chunk[i] = (float)pcm16[offset + i] / 32768.0f;
        }

        preroll_ring_write(chunk, frames);

        bool trigger_fired = (s_chunk_cb != NULL)
                             ? s_chunk_cb(chunk, frames)
                             : false;

        if (xSemaphoreTake(s_state_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            capture_state_step(chunk, frames, trigger_fired);
            xSemaphoreGive(s_state_mutex);
        }

        offset += frames;
    }
}

// ----- Public API -----
int audio_capture_cry_init(void) {
    s_preroll_ring = (float *)heap_caps_malloc(PREROLL_N_SAMPLES * sizeof(float),
                                               MALLOC_CAP_SPIRAM);
    s_active_clip  = (float *)heap_caps_malloc(CRY_CLIP_N_SAMPLES * sizeof(float),
                                               MALLOC_CAP_SPIRAM);
    s_state_mutex    = xSemaphoreCreateMutex();
    s_clip_ready_sem = xSemaphoreCreateBinary();

    if (!s_preroll_ring || !s_active_clip || !s_state_mutex || !s_clip_ready_sem) {
        ESP_LOGE(TAG, "Failed to allocate buffers/sync objects -- is PSRAM enabled?");
        return -1;
    }

    memset(s_preroll_ring, 0, PREROLL_N_SAMPLES * sizeof(float));
    s_preroll_write_idx = 0;
    s_preroll_written   = 0;
    s_state             = CAP_STATE_IDLE;
    s_initialized       = true;

    ESP_LOGI(TAG, "audio_capture_cry_init: preroll=%dms post=%dms clip=%d samples (unified mic feed)",
             CRY_CAPTURE_PREROLL_MS, CRY_CAPTURE_POST_TRIGGER_MS, CRY_CLIP_N_SAMPLES);
    return 0;
}

void audio_capture_cry_set_chunk_callback(audio_capture_cry_chunk_cb_t cb) {
    s_chunk_cb = cb;
}

void audio_capture_cry_signal_trigger(void) {
    if (s_state_mutex == NULL) return;
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    s_async_trigger_pending = true;
    xSemaphoreGive(s_state_mutex);
}

int audio_capture_cry_wait_for_clip(audio_cry_clip_t *out_clip) {
    if (!s_initialized) {
        ESP_LOGE(TAG, "audio_capture_cry_init() not called");
        return -1;
    }
    xSemaphoreTake(s_clip_ready_sem, portMAX_DELAY);
    out_clip->audio       = s_active_clip;
    out_clip->n_samples   = CRY_CLIP_N_SAMPLES;
    out_clip->sample_rate = CRY_CAPTURE_SR;
    return 0;
}

void audio_capture_cry_release_clip(bool was_confirmed_cry) {
    xSemaphoreTake(s_state_mutex, portMAX_DELAY);
    s_lockout_start_tick  = xTaskGetTickCount();
    s_lockout_duration_ms = was_confirmed_cry ? CRY_POST_CRY_LOCKOUT_MS : CRY_LOCKOUT_MS;
    s_state = CAP_STATE_LOCKOUT;
    xSemaphoreGive(s_state_mutex);
    ESP_LOGI(TAG, "Clip released -- lockout=%lums (%s)",
             (unsigned long)s_lockout_duration_ms,
             was_confirmed_cry ? "confirmed cry, long lockout" : "not cry, short lockout");
}
