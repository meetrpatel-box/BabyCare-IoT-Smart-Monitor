// sd_upload.h — RAM-direct cloud upload for the cry-gate pipeline. SD is
// used only as a last-resort spill target when an upload fails (so it
// can be retried later) -- NOT as part of the normal capture/upload path.
// See docs/ENGINEERING_DECISIONS.md #1 for why uploads target
// D:\nxm\ML_pipeline\api\app.py's untouched Stage 2 (OOD) + Stage 3
// (5-class) pipeline.
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
#include "audio_capture_cry.h"

#ifdef __cplusplus
extern "C" {
#endif

// Mounts the SD card (FAT, 1-line SDMMC). Returns 0 on success. Safe to
// call once at startup; if it fails, uploads still work (just without a
// spill-on-failure fallback -- a failed clip with no SD present is
// simply dropped, logged clearly when it happens).
int sd_upload_init(void);

// Uploads `audio` (n_samples float32 samples, [-1,1]) as a 16-bit PCM
// mono WAV at sample_rate directly from RAM -- no SD write in the normal
// (successful) path. POSTs multipart/form-data to the cloud API (field
// name "file", plus the documented device_info/source=esp32 query
// params) with a 120s timeout (Cloud Run cold-start headroom, see
// docs/ENGINEERING_DECISIONS.md #7). On failure, spills the clip to SD
// (if mounted) as a "cry_"-prefixed file for sd_upload_retry_pending() to
// pick up later; if SD is unavailable, the clip is dropped (logged, not
// silent). Returns 0 only on a confirmed successful upload (HTTP 200),
// negative otherwise (spilled-for-retry and dropped both count as
// "negative" here -- check the log for which one happened).
int cloud_upload_ram_wav(const float *audio, int n_samples, int sample_rate);

// Scans /sdcard for previously-saved WAVs that failed to upload and retries
// them. Intended to be called periodically (e.g. from a low-priority
// background task) once WiFi is confirmed connected. Deletes each file
// from SD only after a confirmed successful upload.
void sd_upload_retry_pending(void);

#ifdef __cplusplus
}
#endif

#endif  // SD_UPLOAD_H_
