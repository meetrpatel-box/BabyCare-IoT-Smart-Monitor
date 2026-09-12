// audio_capture.h — ES7210 mic capture at 22050Hz for the cry-gate feature.
//
// Board: ESP32-S3-Korvo-2 V3 (same physical wiring as babycare/main/app_main.c
// -- I2S0 duplex, shared BCK=GPIO9 WS=GPIO45 MCK=GPIO16, DATA_IN=GPIO10 from
// ES7210, codec I2C on GPIO17/18). This module only drives the RX (mic) side
// -- ES8311 (speaker/DAC) is left uninitialized since this standalone example
// has no playback feature and both codecs share the same I2S clock anyway.
//
// IMPORTANT: the 22050Hz ES7210 register sequence (MCLK=11,289,600Hz = 512xfs,
// NOT the 256xfs ratio babycare's own 16kHz config uses) was sourced from
// Espressif's official esp-bsp es7210.c driver, not derived by this project
// and NOT verified on real hardware (no ESP-IDF toolchain available in the
// environment this was written in). Run this example and confirm captured
// audio sounds correct (right pitch, no garbling) before trusting it.
#ifndef AUDIO_CAPTURE_H_
#define AUDIO_CAPTURE_H_

#include "cry_gate_params.h"

#ifdef __cplusplus
extern "C" {
#endif

// One-time setup: I2C codec init (ES7210 only, at CRY_GATE_SR) + I2S RX init.
// Returns ESP_OK on success.
int audio_capture_init(void);

// Blocks until exactly CRY_GATE_N_SAMPLES samples have been captured.
// out_buf must hold at least CRY_GATE_N_SAMPLES floats. Output is
// peak-normalized to [-1, 1], matching export/preprocess.py's
// preprocess_audio() exactly (mono int16 PCM -> float32 -> peak-normalize).
// Returns 0 on success, negative on I2S read error/timeout.
int audio_capture_record_10s(float *out_buf);

#ifdef __cplusplus
}
#endif

#endif  // AUDIO_CAPTURE_H_
