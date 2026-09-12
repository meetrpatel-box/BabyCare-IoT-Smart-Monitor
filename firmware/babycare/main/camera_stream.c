#include "camera_stream.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_camera.h"
#include "esp_heap_caps.h"
#include "esp_tls.h"
#include "esp_timer.h"
#include "esp_websocket_client.h"

/* ISRG Root X1 (self-signed RSA-4096, valid 2015-2035) — trust anchor for relay.nxmplis.com.
 * Server chain: leaf → YE1 → Root YE → cross-signed Root X2 (signed by Root X1 RSA).
 * Root X1 here verifies that cross-signing, completing the chain.
 * Using cert_pem (not crt_bundle_attach) bypasses the ESP-IDF 5.5 bundle bug:
 * the bundle has a stale pre-2025 YE1 entry with the wrong public key. */
static const char s_relay_ca_pem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "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\n"
    "-----END CERTIFICATE-----\n";

static const char *TAG = "cam_relay";

/* Token must match RELAY_TOKEN on the VPS relay. */
#ifndef CONFIG_BABYTRACK_RELAY_TOKEN
#define CONFIG_BABYTRACK_RELAY_TOKEN "2af0a9e90c97421aa37972c3c5e28151157dc5360000a1f9fe7efd9875dd96c8"
#endif
#define RELAY_TOKEN CONFIG_BABYTRACK_RELAY_TOKEN

/* Controlled via MQTT camera_on / camera_off commands. */
static volatile bool s_camera_enabled = true;
extern volatile bool g_video_stream_active;

/* Shared with audio_comm.c via camera_stream_get_ws_client().
 * Written only by camera_stream_task; pointer-sized reads are atomic on
 * ESP32, so audio_comm_tx may read without a mutex. */
static esp_websocket_client_handle_t s_ws_client = NULL;

/* Pre-allocated PSRAM TX buffer — eliminates per-frame DRAM malloc that
 * fragments internal heap and causes TLS reconnect failures after ~7 min.
 * VGA JPEG at q=10 reaches ~25-40 kB; 128 kB covers the whole ladder. */
#define TX_BUF_SIZE (128 * 1024)
static uint8_t *s_tx_buf = NULL;

/* Serialises all WebSocket sends between camera_stream_task (video) and
 * audio_comm_tx (audio).  Without this, concurrent sends corrupt the WS
 * framing layer and drop the connection within ~30 seconds. */
static SemaphoreHandle_t s_ws_mutex = NULL;
static volatile uint32_t s_audio_sent_count = 0;

SemaphoreHandle_t camera_stream_get_ws_mutex(void) { return s_ws_mutex; }

esp_websocket_client_handle_t camera_stream_get_ws_client(void)
{
    return s_ws_client;
}

void camera_stream_set_enabled(bool enabled) { s_camera_enabled = enabled; }
bool camera_stream_is_enabled(void)          { return s_camera_enabled; }

/* ── Send timing ─────────────────────────────────────────────────────────────
 *
 * A failed send is expensive: esp_websocket_client_send_bin() aborts the
 * connection on any transport write error, and a reconnect costs ~4 s (2 s
 * abort + 2 s reconnect delay + TLS handshake).  Stalling for a second is
 * strictly cheaper than that, so the timeout is generous and the ladder below
 * does the real work of keeping frames small enough that it is never reached.
 *
 * The camera holds the WS mutex only for the duration of one send, and takes
 * it with a short wait so a mic chunk in flight simply costs one video frame
 * rather than blocking the pipeline. */
/* Measured on a 4G hotspot: the link occasionally stalls for 2-3 s with the
 * server's receive window wide open and no packet loss — the phone's radio
 * scheduling, not congestion.  A 3000 ms timeout turned those stalls into
 * disconnects; 6000 ms rides them out instead.  Holding the WS mutex that long
 * costs audio nothing, because the same stall blocks audio regardless. */
#define SEND_TIMEOUT_MS      6000

/* Now that audio coalesces three chunks per send it claims the socket about ten
 * times a second rather than thirty, so waiting briefly for it costs less than
 * skipping a frame does.  At 30 ms the camera was discarding 40-70 frames per
 * 10 s window once the microphone came alive; 80 ms is still well inside the
 * frame interval budget and turns nearly all of those skips into sends. */
#define CAM_MUTEX_WAIT_MS      80

/* ── Adaptive ladder ─────────────────────────────────────────────────────────
 *
 * Step 0 is the best picture, the last step is the most conservative.  The
 * camera is initialised at the ladder's largest framesize so every step fits
 * the framebuffers allocated at init: esp32-camera fixes fb_size at
 * esp_camera_init() and errors on any frame that exceeds it, so the ladder may
 * only ever step framesize *down* from the init size, never up.
 *
 * Bitrates are for a typical nursery scene; real frames vary with motion and,
 * at night, with sensor noise.
 *
 *   VGA  640x480 q10  ~25 kB  -> ~6.0 Mbps   needs strong WiFi
 *   VGA  640x480 q16  ~15 kB  -> ~3.6 Mbps
 *   HVGA 480x320 q12  ~11 kB  -> ~2.6 Mbps
 *   QVGA 320x240 q10   ~8 kB  -> ~1.9 Mbps   comfortable on a 4G hotspot
 *   QVGA 320x240 q16   ~5 kB  -> ~1.2 Mbps
 *   QVGA 320x240 q22   ~3 kB  -> ~0.8 Mbps   weak link floor
 */
typedef struct {
    framesize_t size;
    int         quality;
    const char *label;
} abr_step_t;

static const abr_step_t s_ladder[] = {
    { FRAMESIZE_VGA,  10, "VGA q10"  },
    { FRAMESIZE_VGA,  16, "VGA q16"  },
    { FRAMESIZE_HVGA, 12, "HVGA q12" },
    { FRAMESIZE_QVGA, 10, "QVGA q10" },
    { FRAMESIZE_QVGA, 16, "QVGA q16" },
    { FRAMESIZE_QVGA, 22, "QVGA q22" },
};
#define N_ABR ((int)(sizeof(s_ladder) / sizeof(s_ladder[0])))

/* The framesize the camera is initialised at.  camera_stream_max_framesize()
 * lets app_main stay in sync with the ladder instead of hard-coding it. */
framesize_t camera_stream_max_framesize(void) { return s_ladder[0].size; }

/* Start conservatively and climb: a first impression of smooth video matters
 * more than a sharp first frame, and climbing is cheap once the link proves
 * itself. */
static int s_abr_level = N_ABR - 2;   /* QVGA q16 */

/* ── Frame cadence ───────────────────────────────────────────────────────────
 *
 * Low light needs a longer sensor integration time than a 33 ms frame allows,
 * so night mode halves the frame rate to buy exposure.  A sleeping baby barely
 * moves, so 15 fps reads as perfectly smooth at night, while the extra
 * exposure removes most of the noise that high gain would otherwise add. */
#define DAY_FRAME_INTERVAL_MS    33   /* 30 fps */
#define NIGHT_FRAME_INTERVAL_MS  66   /* 15 fps */

/* ── Proactive rate control ──────────────────────────────────────────────────
 *
 * The previous design only downgraded after a send had already failed, by
 * which point the connection was gone.  Latency is the leading indicator:
 * when a send starts taking longer than the frame interval the link is already
 * saturated, and the next frame will queue behind this one.  Downgrading at
 * that point keeps the pipeline out of the failure region entirely.
 *
 * Upgrading is deliberately much slower than downgrading — a brief clear patch
 * should not trigger a resolution change that immediately has to be undone. */
/* Decisions run on a smoothed latency rather than the last frame: a single
 * 120 ms spike is normal on WiFi and must not cost a quality step, while a
 * genuine slowdown shows up in the average within a handful of frames.
 * Weight 3:1 gives a time constant of roughly four frames (~130 ms). */
#define LAT_EWMA_WEIGHT         3

/* Percentages of the frame interval. Stepping down at 150% leaves headroom
 * before a send could approach the timeout; requiring 75% to step up keeps a
 * gap between the two so the ladder cannot oscillate across one threshold. */
#define ABR_DOWN_PCT          150
#define ABR_UP_PCT             75
#define ABR_UP_CLEAN_FRAMES   150     /* ~5 s of clean sends -> step up */

static int      s_clean_run = 0;
static uint32_t s_lat_ewma  = 0;

/* ── Night mode ──────────────────────────────────────────────────────────────
 *
 * There is no IR illuminator on this hardware, so "night mode" is low-light
 * tuning of a colour sensor: raise the gain ceiling, allow a longer exposure,
 * lift the gamma curve, and lean on denoise to clean up what high gain costs.
 * It meaningfully improves a dimly lit room; it cannot see in total darkness.
 *
 * Scene brightness is inferred from the sensor's own AGC gain register — when
 * the room darkens the auto-gain loop drives gain up, so gain is a direct
 * proxy for how little light is reaching the sensor.  OV2640 splits the value:
 * GAIN[7:0] in bank-1 register 0x00, GAIN[9:8] in the top bits of REG45.
 * esp32-camera's get_reg() takes the bank in bit 8 of the address. */
#define OV2640_REG_GAIN   0x100   /* bank 1 (sensor), reg 0x00 */
#define OV2640_REG_REG45  0x145   /* bank 1 (sensor), reg 0x45 */

/* Hysteresis band: entering night takes a clearly dark reading, leaving it
 * takes a clearly bright one, so dusk does not cause the profile to oscillate.
 * Thresholds are on the 10-bit gain value and were chosen to sit either side
 * of a typical indoor evening reading; the periodic log line below reports the
 * live value so they can be retuned against a real nursery. */
#define NIGHT_ENTER_GAIN   520
#define NIGHT_EXIT_GAIN    300
#define LIGHT_POLL_MS     2000
#define NIGHT_CONFIRM        3    /* consecutive readings before switching */

static bool s_night_active = false;
static int  s_night_votes  = 0;
static int  s_last_gain    = -1;   /* surfaced in the periodic log for tuning */

static int read_agc_gain(sensor_t *s)
{
    if (!s || !s->get_reg) return -1;
    int lo = s->get_reg(s, OV2640_REG_GAIN,  0xFF);
    int hi = s->get_reg(s, OV2640_REG_REG45, 0xFF);
    if (lo < 0 || hi < 0) return -1;
    return ((hi & 0xC0) << 2) | (lo & 0xFF);   /* GAIN[9:0] */
}

/* Every one of these controls is optional in the sensor driver, so each is
 * NULL-checked rather than assumed present. */
static void apply_light_profile(sensor_t *s, bool night)
{
    if (!s) return;

    if (night) {
        if (s->set_gainceiling) s->set_gainceiling(s, GAINCEILING_128X);
        if (s->set_aec2)        s->set_aec2(s, 1);   /* extended integration */
        if (s->set_ae_level)    s->set_ae_level(s, 1);
        if (s->set_denoise)     s->set_denoise(s, 8);
        if (s->set_raw_gma)     s->set_raw_gma(s, 1);
        if (s->set_lenc)        s->set_lenc(s, 1);
        if (s->set_bpc)         s->set_bpc(s, 1);
        if (s->set_wpc)         s->set_wpc(s, 1);
        /* Colour noise is the ugliest artefact of high gain, and a nursery at
         * night has almost no real colour information to lose. */
        if (s->set_saturation)  s->set_saturation(s, -2);
        if (s->set_brightness)  s->set_brightness(s, 1);
        if (s->set_contrast)    s->set_contrast(s, 1);
    } else {
        if (s->set_gainceiling) s->set_gainceiling(s, GAINCEILING_16X);
        if (s->set_aec2)        s->set_aec2(s, 0);
        if (s->set_ae_level)    s->set_ae_level(s, 0);
        if (s->set_denoise)     s->set_denoise(s, 0);
        if (s->set_raw_gma)     s->set_raw_gma(s, 1);
        if (s->set_lenc)        s->set_lenc(s, 1);
        if (s->set_bpc)         s->set_bpc(s, 0);
        if (s->set_wpc)         s->set_wpc(s, 0);
        if (s->set_saturation)  s->set_saturation(s, 0);
        if (s->set_brightness)  s->set_brightness(s, 0);
        if (s->set_contrast)    s->set_contrast(s, 0);
    }
}

bool camera_stream_is_night_mode(void) { return s_night_active; }

static uint32_t frame_interval_ms(void)
{
    return s_night_active ? NIGHT_FRAME_INTERVAL_MS : DAY_FRAME_INTERVAL_MS;
}

/* ── Ladder application ──────────────────────────────────────────────────── */

static void abr_apply(int level)
{
    sensor_t *s = esp_camera_sensor_get();
    if (!s) return;

    const abr_step_t *step = &s_ladder[level];

    /* Framesize first, then quality: the sensor recomputes its JPEG tables on
     * a framesize change, so setting quality afterwards makes the new value
     * stick. */
    if (s->set_framesize) s->set_framesize(s, step->size);
    if (s->set_quality)   s->set_quality(s, step->quality);

    ESP_LOGI(TAG, "ladder step %d/%d: %s", level, N_ABR - 1, step->label);
}

/* ── Shared device ID ────────────────────────────────────────────────────── */

static char s_device_id[20] = {0};

void camera_stream_get_device_id(char *buf, size_t len)
{
    if (s_device_id[0] == '\0') {
        uint8_t mac[6] = {0};
        esp_wifi_get_mac(WIFI_IF_STA, mac);
        snprintf(s_device_id, sizeof(s_device_id),
                 "CAM%02X%02X%02X", mac[3], mac[4], mac[5]);
    }
    strlcpy(buf, s_device_id, len);
}

/* ── PTT reassembly buffer (0x53 frames relay → ESP32 → speaker) ──────────── */

#define SPEAK_RX_MAX 4096
static uint8_t  s_speak_rx[SPEAK_RX_MAX];
static int      s_speak_rx_len;
static bool     s_speak_rx_active;

/* ── WebSocket event handler ─────────────────────────────────────────────── */

static void ws_event_handler(void *arg, esp_event_base_t base,
                             int32_t event_id, void *event_data)
{
    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            ESP_LOGI(TAG, "Connected to relay (stream: %s)", s_device_id);
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
            ESP_LOGW(TAG, "Disconnected from relay — will reconnect");
            s_speak_rx_active = false;
            s_speak_rx_len    = 0;
            break;
        case WEBSOCKET_EVENT_ERROR:
            ESP_LOGE(TAG, "WebSocket error");
            break;
        case WEBSOCKET_EVENT_DATA: {
            esp_websocket_event_data_t *d = (esp_websocket_event_data_t *)event_data;

            if (d->payload_offset == 0) {
                /* Start of a new WS message — identify type from first byte */
                s_speak_rx_active = false;
                s_speak_rx_len    = 0;
                if (d->op_code == 2 && d->data_len > 0 &&
                    (uint8_t)d->data_ptr[0] == FRAME_TYPE_SPEAK) {
                    s_speak_rx_active = true;
                    int pcm_bytes = d->data_len - 1;  /* skip 0x53 type byte */
                    if (pcm_bytes > 0) {
                        int copy = (pcm_bytes < SPEAK_RX_MAX) ? pcm_bytes : SPEAK_RX_MAX;
                        memcpy(s_speak_rx, d->data_ptr + 1, copy);
                        s_speak_rx_len = copy;
                    }
                }
            } else if (s_speak_rx_active) {
                /* Continuation fragment — append to buffer */
                int avail = SPEAK_RX_MAX - s_speak_rx_len;
                int copy  = (d->data_len < avail) ? d->data_len : avail;
                if (copy > 0) {
                    memcpy(s_speak_rx + s_speak_rx_len, d->data_ptr, copy);
                    s_speak_rx_len += copy;
                }
            }

            /* Complete WS frame: deliver PCM to speaker queue */
            if (s_speak_rx_active &&
                d->payload_offset + d->data_len >= d->payload_len) {
                if (s_speak_rx_len > 0) {
                    static uint32_t s_cloud_speak_rx_cnt = 0;
                    s_cloud_speak_rx_cnt++;
                    if (s_cloud_speak_rx_cnt % 30 == 1) {
                        ESP_LOGI(TAG, "Cloud Relay -> Speaker: received %d bytes PCM (pkt=%u)",
                                 s_speak_rx_len, (unsigned)s_cloud_speak_rx_cnt);
                    }
                    speak_enqueue_raw(s_speak_rx, (size_t)s_speak_rx_len);
                }
                s_speak_rx_active = false;
                s_speak_rx_len    = 0;
            }
            break;
        }
        default:
            break;
    }
}

/* ── Relay push task ─────────────────────────────────────────────────────── */

static void camera_stream_task(void *pv)
{
    char device_id[20];
    camera_stream_get_device_id(device_id, sizeof(device_id));

    char ws_uri[320];
    snprintf(ws_uri, sizeof(ws_uri),
             "wss://relay.nxmplis.com/ingest/%s?token=%s",
             device_id, RELAY_TOKEN);

    ESP_LOGI(TAG, "Relay push starting — device ID: %s", device_id);

    esp_websocket_client_config_t cfg = {
        .uri                     = ws_uri,
        .cert_pem                = s_relay_ca_pem,
        .reconnect_timeout_ms    = 2000,
        .network_timeout_ms      = 60000,
        .disable_pingpong_discon = true,
        .task_stack              = 4096,
        /* Large enough to receive a complete PTT PCM chunk (≤3500 bytes)
         * in a single WEBSOCKET_EVENT_DATA event without fragmentation. */
        .buffer_size             = 4096,
    };

    esp_websocket_client_handle_t client = esp_websocket_client_init(&cfg);
    esp_websocket_register_events(client, WEBSOCKET_EVENT_ANY,
                                  ws_event_handler, NULL);
    esp_websocket_client_start(client);
    s_ws_client = client;  /* expose to audio_comm_tx via getter */

    /* Diagnostic counters — reset every LOG_INTERVAL_MS. */
    uint32_t cnt_null    = 0;   /* esp_camera_fb_get() returned NULL      */
    uint32_t cnt_invalid = 0;   /* non-JPEG or zero-length frame          */
    uint32_t cnt_valid   = 0;   /* valid JPEG frames captured             */
    uint32_t cnt_sent    = 0;   /* frames successfully transmitted        */
    uint32_t cnt_fail    = 0;   /* send failures                          */
    uint32_t cnt_drop    = 0;   /* frames dropped (disabled / mutex busy) */
    uint64_t bytes_sent  = 0;
    uint32_t lat_sum_ms  = 0;
    uint32_t lat_max_ms  = 0;
    uint32_t cap_sum_ms  = 0;   /* time spent inside esp_camera_fb_get()  */
    uint32_t cap_max_ms  = 0;
#define LOG_INTERVAL_MS 10000

    TickType_t last_log   = xTaskGetTickCount();
    TickType_t last_wake  = xTaskGetTickCount();
    int64_t    last_light = 0;

    abr_apply(s_abr_level);
    apply_light_profile(esp_camera_sensor_get(), false);

    for (;;) {
        /* ── Light metering ──────────────────────────────────────────────
         * Runs on its own slow cadence regardless of connection state, so
         * the profile is already correct when a viewer connects. */
        int64_t now_us = esp_timer_get_time();
        if (now_us - last_light >= (int64_t)LIGHT_POLL_MS * 1000) {
            last_light = now_us;
            sensor_t *s = esp_camera_sensor_get();
            int gain = read_agc_gain(s);
            s_last_gain = gain;
            if (gain >= 0) {
                bool want_night = s_night_active;
                if (!s_night_active && gain >= NIGHT_ENTER_GAIN)      want_night = true;
                else if (s_night_active && gain <= NIGHT_EXIT_GAIN)   want_night = false;

                if (want_night != s_night_active) {
                    if (++s_night_votes >= NIGHT_CONFIRM) {
                        s_night_active = want_night;
                        s_night_votes  = 0;
                        apply_light_profile(s, s_night_active);
                        ESP_LOGI(TAG, "%s mode (gain=%d) — %u fps",
                                 s_night_active ? "NIGHT" : "DAY", gain,
                                 (unsigned)(1000 / frame_interval_ms()));
                        last_wake = xTaskGetTickCount();
                    }
                } else {
                    s_night_votes = 0;
                }
            }
        }

        if (!esp_websocket_client_is_connected(client)) {
            vTaskDelay(pdMS_TO_TICKS(100));
            last_wake = xTaskGetTickCount();
            continue;
        }

        if (g_video_stream_active) {
            // Local LAN stream is active on port 81. Pause cloud relay video captures
            // so local stream gets 100% of camera frames, DMA bandwidth, and CPU.
            vTaskDelay(pdMS_TO_TICKS(100));
            last_wake = xTaskGetTickCount();
            continue;
        }

        TickType_t cap_t0 = xTaskGetTickCount();
        camera_fb_t *fb = esp_camera_fb_get();
        uint32_t cap_ms = (xTaskGetTickCount() - cap_t0) * portTICK_PERIOD_MS;
        cap_sum_ms += cap_ms;
        if (cap_ms > cap_max_ms) cap_max_ms = cap_ms;

        if (!fb) {
            cnt_null++;
            xTaskDelayUntil(&last_wake, pdMS_TO_TICKS(frame_interval_ms()));
            goto log_check;
        }

        if (fb->format != PIXFORMAT_JPEG || fb->len == 0) {
            cnt_invalid++;
            esp_camera_fb_return(fb);
            xTaskDelayUntil(&last_wake, pdMS_TO_TICKS(frame_interval_ms()));
            goto log_check;
        }

        cnt_valid++;

        if (s_camera_enabled && s_tx_buf) {
            size_t msg_len = fb->len + 1;
            if (msg_len <= TX_BUF_SIZE) {
                s_tx_buf[0] = FRAME_TYPE_VIDEO;
                memcpy(s_tx_buf + 1, fb->buf, fb->len);

                /* Return the framebuffer BEFORE sending — critical.
                 * The send can block for hundreds of milliseconds; holding fb
                 * across it starves the camera DMA of buffers, which makes
                 * fb_get stall and eventually return NULL on every call. */
                esp_camera_fb_return(fb);
                fb = NULL;

                if (xSemaphoreTake(s_ws_mutex, pdMS_TO_TICKS(CAM_MUTEX_WAIT_MS)) == pdTRUE) {
                    TickType_t t0 = xTaskGetTickCount();
                    int sent = esp_websocket_client_send_bin(
                        client, (const char *)s_tx_buf,
                        (int)msg_len, pdMS_TO_TICKS(SEND_TIMEOUT_MS));
                    uint32_t elapsed = (xTaskGetTickCount() - t0) * portTICK_PERIOD_MS;
                    xSemaphoreGive(s_ws_mutex);

                    uint32_t interval = frame_interval_ms();

                    if (sent < 0) {
                        cnt_fail++;
                        s_clean_run = 0;
                        s_lat_ewma  = 0;   /* stale once the socket is gone */
                        /* The connection is already being torn down; drop to
                         * the floor so the reconnect starts somewhere the link
                         * can definitely sustain. */
                        if (s_abr_level < N_ABR - 1) {
                            s_abr_level = N_ABR - 1;
                            abr_apply(s_abr_level);
                        }
                        last_wake = xTaskGetTickCount();
                    } else {
                        cnt_sent++;
                        bytes_sent += msg_len;
                        lat_sum_ms += elapsed;
                        if (elapsed > lat_max_ms) lat_max_ms = elapsed;

                        s_lat_ewma = (s_lat_ewma * LAT_EWMA_WEIGHT + elapsed)
                                   / (LAT_EWMA_WEIGHT + 1);

                        if (s_lat_ewma * 100 > interval * ABR_DOWN_PCT) {
                            /* Link is saturating — act before a send fails. */
                            s_clean_run = 0;
                            if (s_abr_level < N_ABR - 1) {
                                s_abr_level++;
                                abr_apply(s_abr_level);
                                last_wake = xTaskGetTickCount();
                            }
                        } else if (s_lat_ewma * 100 < interval * ABR_UP_PCT) {
                            if (++s_clean_run >= ABR_UP_CLEAN_FRAMES && s_abr_level > 0) {
                                s_abr_level--;
                                s_clean_run = 0;
                                abr_apply(s_abr_level);
                                last_wake = xTaskGetTickCount();
                            }
                        } else {
                            s_clean_run = 0;
                        }
                    }
                } else {
                    /* Mic chunk holds the socket — skip this frame rather
                     * than delay audio, which is far more noticeable. */
                    cnt_drop++;
                }
            } else {
                cnt_drop++;
                ESP_LOGW(TAG, "frame too large (%u B) — skipped", (unsigned)msg_len);
            }
        } else {
            cnt_drop++;
        }

        if (fb) {
            esp_camera_fb_return(fb);
            fb = NULL;
        }

        xTaskDelayUntil(&last_wake, pdMS_TO_TICKS(frame_interval_ms()));

log_check:;
        TickType_t now = xTaskGetTickCount();
        if ((now - last_log) >= pdMS_TO_TICKS(LOG_INTERVAL_MS)) {
            uint32_t win_s   = LOG_INTERVAL_MS / 1000;
            uint32_t avg_lat = cnt_sent  ? lat_sum_ms / cnt_sent  : 0;
            uint32_t avg_cap = cnt_valid ? cap_sum_ms / cnt_valid : 0;
            uint32_t avg_kb  = cnt_sent  ? (uint32_t)(bytes_sent / cnt_sent / 1024) : 0;

            ESP_LOGI(TAG,
                "CAM %u s | cap: ok=%u null=%u bad=%u %ums/%ums"
                " | net: sent=%u fail=%u drop=%u %ukB %ukbps"
                " | fps=%.1f lat=%u/%u/%ums | aud=%u chunks | %s %s gain=%d",
                (unsigned)win_s,
                (unsigned)cnt_valid, (unsigned)cnt_null, (unsigned)cnt_invalid, (unsigned)avg_cap, (unsigned)cap_max_ms,
                (unsigned)cnt_sent, (unsigned)cnt_fail, (unsigned)cnt_drop, (unsigned)avg_kb,
                (unsigned)(bytes_sent * 8 / win_s / 1000),
                cnt_sent / (float)win_s, (unsigned)avg_lat, (unsigned)s_lat_ewma, (unsigned)lat_max_ms,
                (unsigned)s_audio_sent_count,
                s_ladder[s_abr_level].label,
                s_night_active ? "NIGHT" : "DAY", (int)s_last_gain);

            cnt_null = cnt_invalid = cnt_valid = 0;
            cnt_sent = cnt_fail = cnt_drop = 0;
            s_audio_sent_count = 0;
            lat_sum_ms = lat_max_ms = 0;
            cap_sum_ms = cap_max_ms = 0;
            bytes_sent = 0;
            last_log = now;
        }
    }
}

/* ── Public start ────────────────────────────────────────────────────────── */

void camera_stream_start(void)
{
    time_t now;
    time(&now);
    if (now < 1787961600L) { // Aug 29 2026
        struct timeval tv = { .tv_sec = 1787961600L };
        settimeofday(&tv, NULL);
        ESP_LOGI(TAG, "Clock set to 2026-08-29 for TLS certificate validity");
    }

    char id[20];
    camera_stream_get_device_id(id, sizeof(id));
    ESP_LOGI(TAG, "Camera relay device ID: %s", id);

    if (!s_ws_mutex) {
        s_ws_mutex = xSemaphoreCreateMutex();
        if (!s_ws_mutex) ESP_LOGE(TAG, "WS mutex create failed");
    }

    if (!s_tx_buf) {
        s_tx_buf = heap_caps_malloc(TX_BUF_SIZE, MALLOC_CAP_SPIRAM);
        if (!s_tx_buf) {
            ESP_LOGE(TAG, "PSRAM TX buf alloc failed — frames will be dropped");
        } else {
            ESP_LOGI(TAG, "PSRAM TX buf allocated: %d bytes", TX_BUF_SIZE);
        }
    }

    /* Pinned to core 0 alongside the camera driver (CONFIG_CAMERA_CORE0) and
     * the WiFi/TCP stack, so a frame never crosses cores between capture and
     * transmit. Priority 6 puts video above the cry gate (3) but below audio path (9). */
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
    if (xTaskCreatePinnedToCoreWithCaps(camera_stream_task, "cam_relay", 8192, NULL, 6, NULL, 0,
                                        MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT) != pdPASS)
#endif
    {
        xTaskCreatePinnedToCore(camera_stream_task, "cam_relay", 4096, NULL, 6, NULL, 0);
    }
}

bool camera_stream_is_ws_connected(void)
{
    return s_ws_client && esp_websocket_client_is_connected(s_ws_client);
}

void camera_stream_send_audio(const uint8_t *pcm, size_t len)
{
    if (!s_ws_client || !esp_websocket_client_is_connected(s_ws_client) || !s_ws_mutex || !pcm || len == 0) {
        return;
    }
    static uint8_t s_audio_send_buf[4096 + 4];
    if (len + 1 > sizeof(s_audio_send_buf)) return;

    if (xSemaphoreTake(s_ws_mutex, pdMS_TO_TICKS(300)) == pdTRUE) {
        s_audio_send_buf[0] = FRAME_TYPE_AUDIO; // 0x41
        memcpy(s_audio_send_buf + 1, pcm, len);
        int sent = esp_websocket_client_send_bin(s_ws_client, (const char *)s_audio_send_buf, len + 1, pdMS_TO_TICKS(4000));
        if (sent > 0) s_audio_sent_count++;
        xSemaphoreGive(s_ws_mutex);
    }
}

