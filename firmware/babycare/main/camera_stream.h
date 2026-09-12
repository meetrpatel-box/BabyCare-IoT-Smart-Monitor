#pragma once
#include <stddef.h>
#include <stdbool.h>
#include "esp_camera.h"
#include "esp_websocket_client.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

/* Binary WebSocket frame type tags (first byte of every message).
 * Defined here so audio_comm.c can reuse without duplication. */
#define FRAME_TYPE_VIDEO  0x56u   /* 'V' — JPEG camera frame */
#define FRAME_TYPE_AUDIO  0x41u   /* 'A' — PCM mic chunk */
#define FRAME_TYPE_SPEAK  0x53u   /* 'S' — PTT audio from parent */

/**
 * camera_stream — WebSocket relay push for BabyTrack camera.
 *
 * Runs a background task that captures JPEG frames from the already-initialised
 * esp32-camera driver and pushes them as binary WebSocket messages to the
 * BabyTrack relay VPS (wss://relay.nxmplis.com).
 *
 * The device ID is derived from the last 3 bytes of the WiFi STA MAC address,
 * producing a stable 9-char string like "CAMA4B2C1".  This ID is the stream
 * name on the relay and is what the Flutter app uses to connect via WebRTC.
 *
 * Call camera_stream_start() once, after esp_camera_init() and WiFi connect.
 * Call camera_stream_get_device_id() any time after that to read the ID.
 */

void camera_stream_start(void);
void camera_stream_get_device_id(char *buf, size_t len);
void camera_stream_set_enabled(bool enabled);
bool camera_stream_is_enabled(void);
bool camera_stream_is_ws_connected(void);
void camera_stream_send_audio(const uint8_t *pcm, size_t len);

/* Largest framesize on the adaptive ladder.  esp32-camera fixes the
 * framebuffer size at esp_camera_init() and rejects any frame larger than it,
 * so the camera must be initialised at this size and the ladder may only ever
 * step down from it.  app_main reads this instead of hard-coding a framesize,
 * so the two cannot drift apart. */
framesize_t camera_stream_max_framesize(void);

/* True while the low-light profile is active: higher gain ceiling, longer
 * exposure, denoise, and a halved frame rate to buy that exposure time. */
bool camera_stream_is_night_mode(void);

/* Returns the active WebSocket client handle, or NULL before the first
 * connection attempt completes.  audio_comm uses this to piggyback 0x41
 * mic-audio frames on the same relay connection as the video stream. */
esp_websocket_client_handle_t camera_stream_get_ws_client(void);

/* Mutex that serialises all esp_websocket_client_send_bin() calls.
 * Both camera_stream_task (0x56 video) and audio_comm_tx (0x41 audio)
 * must take this mutex before sending and give it immediately after.
 * Returns NULL until camera_stream_start() has been called. */
SemaphoreHandle_t camera_stream_get_ws_mutex(void);

/* PTT: called by camera_stream when a 0x53 WebSocket frame arrives from the
 * relay.  app_main provides this symbol — it enqueues raw PCM to g_speak_queue
 * so speaker_task plays it without going through MQTT or base64.
 * Declared here so camera_stream.c can call it without a circular include. */
void speak_enqueue_raw(const uint8_t *pcm, size_t len);
