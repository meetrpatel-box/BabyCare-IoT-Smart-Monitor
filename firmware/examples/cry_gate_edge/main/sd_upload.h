// sd_upload.h — Save an accepted cry clip to SD as a WAV, queue it for
// upload to the production cloud API (D:\nxm\ML_pipeline\api\app.py,
// untouched/read-only), which performs Stage 2 (OOD) + Stage 3 (5-class)
// server-side. See docs/ENGINEERING_DECISIONS.md #1.
//
// SD card pins are NOT hardcoded with confidence -- no verified GPIO
// mapping for the ESP32-S3-Korvo-2 V3's SD slot was available (unlike the
// I2S/codec pins, which are already used and confirmed working in
// babycare/main/app_main.c). Set them via `idf.py menuconfig` ->
// "Cry Gate Edge Configuration" -> SD Card pins, cross-checked against the
// board schematic (SCH_ESP32-S3-Korvo-2_V3.1.2, dl.espressif.com) before
// first use.
#ifndef SD_UPLOAD_H_
#define SD_UPLOAD_H_

#include <stdint.h>
#include "cry_gate_params.h"

#ifdef __cplusplus
extern "C" {
#endif

// Mounts the SD card (FAT, 1-line SDMMC). Returns 0 on success. Safe to
// call once at startup; if it fails, save_and_queue() below simply skips
// the SD step and returns an error each time (I2S/inference still work).
int sd_upload_init(void);

// Writes `audio` (CRY_GATE_N_SAMPLES float32 samples, [-1,1]) as a 16-bit
// PCM mono WAV at CRY_GATE_SR to /sdcard/cry_<timestamp>.wav, then attempts
// an immediate HTTP multipart upload to the cloud API's POST /predict
// (field name "file", per D:\nxm\ML_pipeline\api\app.py). If the upload
// fails (no WiFi, server unreachable), the WAV stays on SD for the retry
// task to pick up later -- see sd_upload_retry_pending().
// Returns 0 if the WAV was at least saved to SD (upload success/failure is
// logged but does not affect the return value), negative on SD write failure.
int sd_upload_save_and_queue(const float *audio);

// Scans /sdcard for previously-saved WAVs that failed to upload and retries
// them. Intended to be called periodically (e.g. from a low-priority
// background task) once WiFi is confirmed connected. Deletes each file
// from SD only after a confirmed successful upload.
void sd_upload_retry_pending(void);

#ifdef __cplusplus
}
#endif

#endif  // SD_UPLOAD_H_
