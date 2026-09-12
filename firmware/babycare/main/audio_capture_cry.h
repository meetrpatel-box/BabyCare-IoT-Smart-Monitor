// audio_capture_cry.h -- Continuous cry-gate audio capture adapted for
// babycare's existing bsp_board codec stack.
//
// Unlike examples/cry_gate_edge/main/audio_capture.c (which owns its own
// ES7210 I2C init from scratch), this module reuses the codec handle that
// bsp_board already created (esp_ret_record_dev()) and the I2S channel that
// bsp_board already opened (esp_ret_rx_handle()). It does NOT create a new
// I2S channel -- it uses the existing one shared with babycare's on-demand
// recording feature.
//
// Mutual-exclusion contract: the same I2S channel is used by both
// audio_recording_task (on-demand MQTT recording) and this continuous
// monitor. cry_gate_feature.c enforces that only one of them can be active
// at a time (same contract as before -- the audio_play check is already
// there).
//
// This module implements the same state machine as the reference:
//   IDLE -> CAPTURING -> READY -> LOCKOUT -> IDLE
// driven by a chunk callback (cry_candidate_on_chunk) and/or an async
// trigger signal from cry_candidate_infer_task.
#ifndef AUDIO_CAPTURE_CRY_H_
#define AUDIO_CAPTURE_CRY_H_

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CRY_CAPTURE_SR               16000
#define CRY_CAPTURE_PREROLL_MS       1500
#define CRY_CAPTURE_POST_TRIGGER_MS  20000
#define CRY_CLIP_N_SAMPLES \
    (((CRY_CAPTURE_PREROLL_MS + CRY_CAPTURE_POST_TRIGGER_MS) * CRY_CAPTURE_SR) / 1000)

#define CRY_LOCKOUT_MS               3000
#define CRY_POST_CRY_LOCKOUT_MS     180000

// One-time setup. Allocates PSRAM buffers, creates sync primitives, and
// starts the continuous capture task pinned to core 1. Must be called after
// bsp_board init (esp_ret_rx_handle() must be valid). Returns 0 on success.
int audio_capture_cry_init(void);

// Chunk callback: return true to synchronously trigger a capture.
typedef bool (*audio_capture_cry_chunk_cb_t)(const float *mono, int n_frames);
void audio_capture_cry_set_chunk_callback(audio_capture_cry_chunk_cb_t cb);

// Asynchronous trigger from cry_candidate_infer_task. Thread-safe.
void audio_capture_cry_signal_trigger(void);

typedef struct {
    const float *audio;
    int n_samples;
    int sample_rate;
} audio_cry_clip_t;

// Blocks until a triggered clip is ready. Returns 0 on success.
int audio_capture_cry_wait_for_clip(audio_cry_clip_t *out_clip);

// Releases the clip and enters lockout. was_confirmed_cry=true -> long lockout.
void audio_capture_cry_release_clip(bool was_confirmed_cry);

#ifdef __cplusplus
}
#endif

#endif  // AUDIO_CAPTURE_CRY_H_
