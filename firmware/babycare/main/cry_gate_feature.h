// cry_gate_feature.h — Cry-gate ML feature for BabyCare, added as a new,
// opt-in capability. Does nothing unless explicitly started via the
// "start_cry_monitor" MQTT command -- no code here runs at boot, so it
// cannot affect WiFi/BLE/MQTT/camera/existing audio features unless a user
// explicitly requests it.
//
// Reuses D:\nxm\esp32board\examples\cry_gate_edge\main's mel_spectrogram.c/
// cry_gate_inference.cc/sd_upload.c unmodified (via relative CMake paths,
// see main/CMakeLists.txt) rather than duplicating the ~2.8MB of generated
// model/filterbank data headers -- single source of truth.
//
// *** Sample-rate switch design: unlike the standalone cry_gate_edge
// example (which owns its own ES7210 I2C init from scratch), this
// integration deliberately does NOT touch babycare's existing, working
// es7210_init_codec()/es8311_init_codec() I2C register sequence AT ALL.
// ES7210 runs in I2S slave mode (clock derived entirely from the ESP32-S3
// I2S master -- see app_main.c's es7210_init_codec comment), so switching
// the mic's effective sample rate only requires reconfiguring the ESP32-S3
// I2S peripheral's own clock (i2s_channel_reconfig_std_clock) -- the
// codec's OSR register stays exactly as babycare already has it, and MCLK
// scales proportionally with the peripheral's requested sample_rate_hz.
// This is lower-risk than the standalone example's full codec reinit and
// still not hardware-verified, but changes nothing about the codec I2C
// state babycare already relies on for its existing 16kHz recording and
// lullaby-playback features. cry-monitoring and those two existing
// features are mutually exclusive in time -- see cry_gate_start_monitor().
#ifndef CRY_GATE_FEATURE_H_
#define CRY_GATE_FEATURE_H_

#include "driver/i2s_std.h"

#ifdef __cplusplus
extern "C" {
#endif

// Called once from app_main(), after i2s_init_duplex() succeeds, so this
// module can reconfigure the same shared I2S channels babycare already
// created. Purely a handle hand-off -- does not touch hardware.
void cry_gate_feature_set_i2s_channels(i2s_chan_handle_t rx_chan, i2s_chan_handle_t tx_chan);

// Starts a background task that: reconfigures the shared I2S to 22050Hz,
// captures+classifies 10s clips in a loop, saves+uploads accepted clips to
// SD, and restores 16kHz when stopped. Fails (returns false) if a capture
// is already running, or if playback/on-demand recording is currently
// active (recording_active / g_audio_playing in app_main.c) -- cry
// monitoring, lullaby playback, and on-demand MQTT recording are mutually
// exclusive since they share one physical I2S clock (see file header).
bool cry_gate_start_monitor(void);

// Signals the monitor task to stop after its current clip finishes, then
// restores the I2S clock to 16kHz. Safe to call even if not running.
void cry_gate_stop_monitor(void);

bool cry_gate_is_monitoring(void);

#ifdef __cplusplus
}
#endif

#endif  // CRY_GATE_FEATURE_H_
