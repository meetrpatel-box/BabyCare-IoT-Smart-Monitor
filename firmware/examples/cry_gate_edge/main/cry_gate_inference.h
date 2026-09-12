// cry_gate_inference.h — TFLite Micro wrapper around the int8 BinaryCryCNN.
//
// The exported model has no final sigmoid op (see
// ML_pipeline_edge/edge_models/export_manifest.json — TFLite op list ends
// at FULLY_CONNECTED, producing a raw quantized logit). Sigmoid is applied
// here after dequantizing, matching export/validate_parity.py exactly.
#ifndef CRY_GATE_INFERENCE_H_
#define CRY_GATE_INFERENCE_H_

#include "mel_spectrogram.h"

#ifdef __cplusplus
extern "C" {
#endif

// One-time setup: loads the embedded model, builds the op resolver +
// interpreter, allocates the tensor arena from PSRAM. Call once at startup,
// after mel_spectrogram_init(). Returns 0 on success.
int cry_gate_inference_init(void);

// Runs inference on already-computed, normalized mel features.
// Returns the sigmoid probability (0..1) that the clip is a cry, or a
// negative value on error. Compare against CRY_GATE_THRESHOLD.
float cry_gate_inference_run(const mel_features_t *features);

#ifdef __cplusplus
}
#endif

#endif  // CRY_GATE_INFERENCE_H_
