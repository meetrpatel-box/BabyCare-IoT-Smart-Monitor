// trigger.h — cheap, always-on energy pre-filter ("Stage A" only).
//
// HISTORY: this module previously also carried a DSP-only "Stage B/C"
// cry/voice-band (~300-3000Hz) energy-ratio + zero-crossing-rate classifier,
// meant to distinguish a cry from other loud sounds using pure signal
// processing. Real-hardware testing (2026-08-07, Instagram/Reels played as
// background noise) proved that approach fundamentally incapable of the
// actual requirement: Stage C confirmed those clips with duty=0.997-1.000,
// i.e. it called continuous speech/music "cry-like" essentially the entire
// time. This is not a tuning problem -- a fixed acoustic frequency band
// cannot distinguish WHO is producing energy in that band (an infant cry
// vs. an adult voice vs. music vs. TV occupy overlapping bands), only
// THAT something is. That entire classification approach has been removed;
// actual cry/not-cry discrimination is now done by the validated
// native-16kHz edge ML model (edge_model.h), run on a rolling window by
// cry_candidate.c (Decision 1: is this worth capturing) and again on the
// full captured clip by app_main.c (Decision 2: is this worth uploading).
//
// What's left here is ONLY the cheap gatekeeper: is there enough acoustic
// energy above the ambient noise floor to be worth spending an ML inference
// on at all. This makes NO claim about cry-vs-not-cry -- it exists purely
// so the system doesn't run mel+CNN inference continuously during genuine
// silence. Deliberately biased loose (low threshold): the cost of a false
// positive here is one extra ML inference (cheap); the cost of a false
// negative is a real cry never even being considered by the classifier
// (unacceptable -- recall over precision is the absolute priority, see
// app_main.c's file header).
#ifndef TRIGGER_H_
#define TRIGGER_H_

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// One-time setup. sample_rate_hz is accepted for API symmetry / future use
// but Stage A itself (adaptive RMS vs. noise floor) is sample-rate agnostic.
void trigger_init(int sample_rate_hz);

// Feeds one mono chunk into the energy gate. Returns true if this chunk's
// RMS clears the adaptive noise floor by enough margin to be worth running
// the ML cry-candidate classifier on the current rolling window (see
// cry_candidate.c). Does NOT itself mean "cry detected" -- it means "worth
// checking". Safe to call from the continuous capture task only (holds
// mutable delay-line-free state, single-writer).
bool trigger_stage_a_gate(const float *mono, int n_frames);

// Diagnostic accessor: current smoothed noise-floor estimate and the RMS of
// the most recently fed chunk (whether or not the gate opened). For log
// lines only.
void trigger_get_energy_info(float *out_rms, float *out_noise_floor);

#ifdef __cplusplus
}
#endif

#endif  // TRIGGER_H_
