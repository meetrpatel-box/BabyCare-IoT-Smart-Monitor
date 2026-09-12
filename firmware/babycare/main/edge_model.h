// edge_model.h — shared wrapper around mel_spectrogram + cry_gate_inference:
// the ONE validated native-16kHz binary cry/not-cry model, used by BOTH:
//
//   Decision 1 (cry_candidate.c): scored on a rolling ~10s window while
//     listening, to decide whether a candidate cry is worth a full capture.
//   Decision 2 (app_main.c): scored on (multiple windows of) the completed
//     20-30s RAM capture, to decide whether to discard locally or upload to
//     Cloud.
//
// Both decisions reuse the exact same model/weights/preprocessing -- there
// is deliberately only one edge model in this firmware, not a separate
// "trigger model" and "gate model". See
// ML_pipeline_edge/training/scripts/stage_binary_cry_gate_edge16k.py for
// the training/export history (fixes the 16kHz-vs-22050Hz mismatch, the
// GATHER_ND/int64 TFLite Micro incompatibility that made the first
// checkpoint unusable on real hardware, and a downsampling stem added
// after real-hardware latency measurement -- see that file's class
// docstring).
#ifndef EDGE_MODEL_H_
#define EDGE_MODEL_H_

#include <stdbool.h>
#include "mel_spectrogram.h"  // CRY_GATE_N_SAMPLES, CRY_GATE_THRESHOLD

#ifdef __cplusplus
extern "C" {
#endif

// One-time setup: mel_spectrogram_init() + cry_gate_inference_init() +
// PSRAM feature buffer allocation. Returns 0 on success. Safe to call even
// if the model turns out to be unusable on this build (caller checks
// edge_model_available() afterward rather than treating failure as fatal --
// this model gates cloud upload, and a broken model must not be able to
// take down the rest of the pipeline; see app_main.c's file header).
int edge_model_init(void);

// True if edge_model_init() succeeded and edge_model_score() is safe to call.
bool edge_model_available(void);

// Runs mel + inference on exactly CRY_GATE_N_SAMPLES float32 samples
// (peak-normalized to [-1,1], native 16kHz -- the caller is responsible for
// both; audio_capture.c's captured clips are already peak-normalized,
// cry_candidate.c's rolling window is not and must be normalized by the
// caller before this call). Returns the sigmoid cry probability (0..1), or
// a negative value on error. Compare against CRY_GATE_THRESHOLD, or use
// edge_model_is_cry() below. NOT thread-safe -- this firmware only ever
// calls it from the single-threaded main loop and the (also single-task)
// cry_candidate consumer, never concurrently with itself.
float edge_model_score(const float *audio_n_samples);

static inline bool edge_model_is_cry(float score) {
    return score >= CRY_GATE_THRESHOLD;
}

// Wall-clock latency (milliseconds) of the most recent edge_model_score()
// call (mel + inference combined). For diagnostic logging only.
float edge_model_last_latency_ms(void);

// Split of the above into mel-extraction time and TFLite Micro inference
// time separately -- added 2026-08-10 after real hardware showed a 4x
// tensor-arena shrink only cut total latency ~1.4x, meaning the two phases
// needed to be measured independently to find out which one actually
// dominates. For diagnostic logging only.
float edge_model_last_mel_ms(void);
float edge_model_last_infer_ms(void);

#ifdef __cplusplus
}
#endif

#endif  // EDGE_MODEL_H_
