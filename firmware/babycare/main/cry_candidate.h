// cry_candidate.h — Decision 1: is the audio arriving right now worth a
// full 20-30s capture?
//
// Composes two layers:
//   Stage A (trigger.h): cheap adaptive-RMS energy gate. Says nothing about
//     WHAT the sound is -- only whether it's loud enough above the ambient
//     floor to be worth spending an ML inference on.
//   ML cry classifier (edge_model.h): the validated native-16kHz binary
//     cry/not-cry model, run on a continuously-maintained rolling ~10s
//     window of recent audio whenever Stage A's gate is open (rate-limited
//     -- see CRY_CANDIDATE_MIN_INFER_INTERVAL_MS -- so sustained loud sound
//     doesn't run inference every single chunk).
//
// This is a genuine acoustic classification, not activity/voice detection
// -- see trigger.h's history note for why the previous DSP-only band-ratio
// approach was replaced rather than re-tuned. A single positive window is
// enough to trigger a full capture (no additional debounce): recall is the
// absolute priority (see app_main.c's file header), and a real trained
// classifier scoring an actual 10-second window is a far more specific
// signal than the old DSP heuristics ever were, so it does not need the
// same noise-tolerance crutch. Decision 2 (full-clip re-validation,
// app_main.c) is the second, independent check before anything reaches
// Cloud.
#ifndef CRY_CANDIDATE_H_
#define CRY_CANDIDATE_H_

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// One-time setup. Allocates the rolling-window ring buffer in PSRAM.
// edge_model_init() must be called first (or have already failed --
// cry_candidate degrades to "Stage A gate never confirms" if the edge
// model is unavailable, rather than taking down the capture pipeline; see
// cry_candidate_on_chunk()).
void cry_candidate_init(void);

// Registered as the audio_capture chunk callback (matches
// audio_capture_chunk_cb_t exactly). Always updates the rolling window;
// runs the ML classifier only when Stage A's gate is open AND the
// rate-limit interval has elapsed. Returns true on the chunk where the
// classifier's score crosses CRY_GATE_THRESHOLD -- this return value drives
// audio_capture.c's IDLE->CAPTURING transition directly.
bool cry_candidate_on_chunk(const float *mono, int n_frames);

// Diagnostic accessor: the score/latency/energy values from the most
// recent inference run (whether or not it crossed threshold). For log
// lines only; safe to call any time after cry_candidate_init().
void cry_candidate_get_last_info(float *out_score, float *out_latency_ms,
                                  float *out_rms, float *out_noise_floor);

#ifdef __cplusplus
}
#endif

#endif  // CRY_CANDIDATE_H_
