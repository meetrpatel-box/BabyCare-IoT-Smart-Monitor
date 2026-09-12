// sd_upload.c — see sd_upload.h for the pin-verification caveat.
#include "sd_upload.h"

#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>

#include "esp_log.h"
#include "esp_mac.h"
#include "esp_http_client.h"
#include "esp_crt_bundle.h"
#include "esp_vfs_fat.h"
#include "sdmmc_cmd.h"
#include "driver/sdmmc_host.h"
#include "sdkconfig.h"

static const char *TAG = "sd_upload";

#define MOUNT_POINT "/sdcard"
#define WAV_HEADER_BYTES 44

static bool s_sd_mounted = false;
static sdmmc_card_t *s_card = NULL;
static int s_clip_counter = 0;

// ── WAV header (44-byte canonical PCM RIFF header) ──────────────────────
// Buffer-filling core, shared by both the SD-file path (write_wav_to_sd())
// and the RAM-direct HTTP path (cloud_upload_ram_wav()) -- single source
// of truth for the header layout instead of two copies drifting apart.
static void write_wav_header_buf(uint8_t out[WAV_HEADER_BYTES], int n_samples, int sample_rate) {
    uint32_t data_bytes = (uint32_t)n_samples * 2;
    uint32_t riff_bytes = 36 + data_bytes;
    uint16_t num_channels = 1, bits_per_sample = 16;
    uint32_t byte_rate = (uint32_t)sample_rate * num_channels * bits_per_sample / 8;
    uint16_t block_align = num_channels * bits_per_sample / 8;
    uint32_t fmt_chunk_size = 16;
    uint16_t audio_format = 1;  /* PCM */
    uint32_t sr = (uint32_t)sample_rate;

    uint8_t *p = out;
    memcpy(p, "RIFF", 4); p += 4;
    memcpy(p, &riff_bytes, 4); p += 4;
    memcpy(p, "WAVE", 4); p += 4;
    memcpy(p, "fmt ", 4); p += 4;
    memcpy(p, &fmt_chunk_size, 4); p += 4;
    memcpy(p, &audio_format, 2); p += 2;
    memcpy(p, &num_channels, 2); p += 2;
    memcpy(p, &sr, 4); p += 4;
    memcpy(p, &byte_rate, 4); p += 4;
    memcpy(p, &block_align, 2); p += 2;
    memcpy(p, &bits_per_sample, 2); p += 2;
    memcpy(p, "data", 4); p += 4;
    memcpy(p, &data_bytes, 4); p += 4;
    // p - out == WAV_HEADER_BYTES (44), by construction of the fields above.
}

static void write_wav_header(FILE *f, int n_samples, int sample_rate) {
    uint8_t header[WAV_HEADER_BYTES];
    write_wav_header_buf(header, n_samples, sample_rate);
    fwrite(header, 1, WAV_HEADER_BYTES, f);
}

// Cached once, reused for every upload's device_info query param -- the
// chip's own base MAC is a stable, always-available per-device identifier
// with no extra Kconfig/provisioning needed.
static char s_device_id[24] = {0};

static const char *device_id(void) {
    if (s_device_id[0] == '\0') {
        uint8_t mac[6] = {0};
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(s_device_id, sizeof(s_device_id), "esp32-%02x%02x%02x%02x%02x%02x",
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    }
    return s_device_id;
}

int sd_upload_init(void) {
    if (s_sd_mounted) {
        return 0;
    }

    esp_vfs_fat_sdmmc_mount_config_t mount_cfg = {
        .format_if_mount_failed = false,
        .max_files = 5,
        .allocation_unit_size = 16 * 1024,
    };

    sdmmc_host_t host = SDMMC_HOST_DEFAULT();
    sdmmc_slot_config_t slot_cfg = SDMMC_SLOT_CONFIG_DEFAULT();
    slot_cfg.width = 1;
    // Use ESP32-S3 Korvo SDMMC pins (40, 42, 41) -- never use GPIO 39 which is CAM_D3!
    slot_cfg.clk = GPIO_NUM_40;
    slot_cfg.cmd = GPIO_NUM_42;
    slot_cfg.d0  = GPIO_NUM_41;
    slot_cfg.flags |= SDMMC_SLOT_FLAG_INTERNAL_PULLUP;

    esp_err_t ret = esp_vfs_fat_sdmmc_mount(MOUNT_POINT, &host, &slot_cfg, &mount_cfg, &s_card);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SD mount failed: %s (pins unverified -- see sd_upload.h)",
                 esp_err_to_name(ret));
        return -1;
    }

    s_sd_mounted = true;
    ESP_LOGI(TAG, "SD card mounted at %s", MOUNT_POINT);
    return 0;
}

// Writes a clip to SD as a WAV under cry_<counter>.wav -- an upload-spill
// file, scanned/retried later by sd_upload_retry_pending().
static int write_wav_to_sd(const float *audio, int n_samples, int sample_rate,
                            char *out_path, size_t out_path_len) {
    if (!s_sd_mounted) {
        return -1;
    }
    snprintf(out_path, out_path_len, MOUNT_POINT "/cry_%06d.wav", s_clip_counter++);

    FILE *f = fopen(out_path, "wb");
    if (f == NULL) {
        ESP_LOGE(TAG, "fopen(%s) failed", out_path);
        return -1;
    }

    write_wav_header(f, n_samples, sample_rate);

    // Convert float [-1,1] -> int16 PCM in chunks (avoid a second
    // full-size heap buffer alongside the caller's float buffer).
    // `static` deliberately: an 8KB array here as a stack local would
    // consume the ENTIRE main task stack (CONFIG_ESP_MAIN_TASK_STACK_SIZE
    // =8192) on top of whatever this call chain already used, and was the
    // confirmed cause of a real on-device crash (rst:0xc RTC_SW_CPU_RST)
    // during an SD write. Safe as static: this function is only ever
    // called serially from app_main's single main-loop task, never
    // concurrently with itself.
    const int chunk = 4096;
    static int16_t pcm[4096];
    for (int i = 0; i < n_samples; i += chunk) {
        int n = n_samples - i;
        if (n > chunk) n = chunk;
        for (int j = 0; j < n; j++) {
            float s = audio[i + j];
            if (s > 1.0f) s = 1.0f;
            if (s < -1.0f) s = -1.0f;
            pcm[j] = (int16_t)(s * 32767.0f);
        }
        fwrite(pcm, sizeof(int16_t), n, f);
    }
    fclose(f);
    ESP_LOGI(TAG, "Saved %s (%d bytes)", out_path, (int)(WAV_HEADER_BYTES + n_samples * 2));
    return 0;
}

// Builds the request URL with the cloud API's documented optional query
// params (device_info: stable per-device id; source: client type) --
// previously unused, now attached to every upload for server-side
// logging/analytics. out must be at least 256 bytes.
static void build_upload_url(char *out, size_t out_len) {
    snprintf(out, out_len, "%s?source=esp32&device_info=%s", CONFIG_CRY_GATE_API_URL, device_id());
}

// Shared HTTP client setup: opens a POST to the cloud API with the
// standard multipart boundary/content-type headers and the given
// total content length. Returns NULL on failure (already logged).
static esp_http_client_handle_t open_upload_request(int64_t content_length, const char *boundary) {
    char url[256];
    build_upload_url(url, sizeof(url));

    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_POST,
        // 120s, not the more typical ~20s: the production API is deployed on
        // Google Cloud Run (see docs/ENGINEERING_DECISIONS.md #7), which
        // scales to zero when idle -- a cold-start request was observed to
        // take 90s+ before the container was warm, vs. ~2s once warm. A
        // short timeout here would spuriously fail the very first upload
        // after any idle period. sd_upload_retry_pending() still covers the
        // case where even this isn't enough.
        .timeout_ms = 120000,
        // The API URL is https:// -- without a server-verification option
        // mbedTLS refuses the handshake (ESP_ERR_MBEDTLS_SSL_SETUP_FAILED).
        // Attach ESP-IDF's built-in CA certificate bundle
        // (CONFIG_MBEDTLS_CERTIFICATE_BUNDLE=y); Google Cloud Run's cert
        // chains to a public root that's in the bundle, so this validates
        // the server properly rather than skipping verification.
        .crt_bundle_attach = esp_crt_bundle_attach,
    };
    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        return NULL;
    }

    char content_type[64];
    snprintf(content_type, sizeof(content_type), "multipart/form-data; boundary=%s", boundary);
    esp_http_client_set_header(client, "Content-Type", content_type);

    esp_err_t err = esp_http_client_open(client, (int)content_length);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_http_client_open failed: %s", esp_err_to_name(err));
        esp_http_client_cleanup(client);
        return NULL;
    }
    return client;
}

// Reads the response status, accumulates and logs the full body (the
// cloud API's JSON classification result -- cry/not-cry, 5-class reason,
// confidence -- needed to report the actual verdict, not just "upload
// succeeded"), then drains/closes the connection. Always closes+cleans up
// client.
static int finish_upload_request(esp_http_client_handle_t client, bool body_ok) {
    int status = -1;
    if (body_ok) {
        int64_t body_len = esp_http_client_fetch_headers(client);
        (void)body_len;
        status = esp_http_client_get_status_code(client);

        // Stack-local, not static: finish_upload_request() can be called
        // from two different tasks (cloud_upload_ram_wav() on the main
        // task, upload_wav_file() via sd_upload_retry_pending() on
        // retry_upload_task) -- a static buffer would let a rare
        // concurrent retry race with a fresh upload and corrupt the
        // logged response text. 1KB is generous for a JSON classification
        // response; retry_upload_task's stack was sized up to
        // accommodate this (see its xTaskCreate call).
        char resp_body[1024];
        size_t used = 0;
        char chunk[256];
        int r;
        while ((r = esp_http_client_read(client, chunk, sizeof(chunk) - 1)) > 0) {
            if (used + (size_t)r < sizeof(resp_body) - 1) {
                memcpy(resp_body + used, chunk, (size_t)r);
                used += (size_t)r;
            }
        }
        resp_body[used] = '\0';
        ESP_LOGI(TAG, "Cloud response (status=%d): %s", status, resp_body);
    }
    esp_http_client_close(client);
    esp_http_client_cleanup(client);
    return status;
}

// ── HTTP multipart/form-data upload, streamed from an SD file -- used
// only by sd_upload_retry_pending() to retry clips that failed to upload
// and were spilled to SD (see cloud_upload_ram_wav()). ──────────────────
static int upload_wav_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        ESP_LOGE(TAG, "upload: cannot reopen %s", path);
        return -1;
    }
    struct stat st;
    if (stat(path, &st) != 0) {
        fclose(f);
        return -1;
    }

    const char *boundary = "----cryGateBoundary7f3a";
    char pre_part[256];
    const char *filename = strrchr(path, '/');
    filename = filename ? filename + 1 : path;
    int pre_len = snprintf(pre_part, sizeof(pre_part),
        "--%s\r\n"
        "Content-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
        "Content-Type: audio/wav\r\n\r\n",
        boundary, filename);

    char post_part[64];
    int post_len = snprintf(post_part, sizeof(post_part), "\r\n--%s--\r\n", boundary);

    int64_t content_length = pre_len + (int64_t)st.st_size + post_len;

    esp_http_client_handle_t client = open_upload_request(content_length, boundary);
    if (client == NULL) {
        fclose(f);
        return -1;
    }

    int ok = 1;
    if (esp_http_client_write(client, pre_part, pre_len) < 0) ok = 0;

    uint8_t buf[2048];
    while (ok) {
        size_t n = fread(buf, 1, sizeof(buf), f);
        if (n == 0) break;
        if (esp_http_client_write(client, (const char *)buf, (int)n) < 0) {
            ok = 0;
            break;
        }
    }
    fclose(f);

    if (ok && esp_http_client_write(client, post_part, post_len) < 0) ok = 0;

    int status = finish_upload_request(client, ok);
    if (status == 200) {
        ESP_LOGI(TAG, "Upload OK: %s", path);
        return 0;
    }
    ESP_LOGW(TAG, "Upload failed for %s (http status=%d) -- will retry later", path, status);
    return -1;
}

int cloud_upload_ram_wav(const float *audio, int n_samples, int sample_rate) {
    uint8_t header[WAV_HEADER_BYTES];
    write_wav_header_buf(header, n_samples, sample_rate);

    char filename[24];
    snprintf(filename, sizeof(filename), "cry_%06d.wav", s_clip_counter);

    const char *boundary = "----cryGateBoundary7f3a";
    char pre_part[256];
    int pre_len = snprintf(pre_part, sizeof(pre_part),
        "--%s\r\n"
        "Content-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
        "Content-Type: audio/wav\r\n\r\n",
        boundary, filename);

    char post_part[64];
    int post_len = snprintf(post_part, sizeof(post_part), "\r\n--%s--\r\n", boundary);

    int64_t content_length = pre_len + WAV_HEADER_BYTES + (int64_t)n_samples * 2 + post_len;

    esp_http_client_handle_t client = open_upload_request(content_length, boundary);
    int ok = (client != NULL);

    if (ok && esp_http_client_write(client, pre_part, pre_len) < 0) ok = 0;
    if (ok && esp_http_client_write(client, (const char *)header, WAV_HEADER_BYTES) < 0) ok = 0;

    // Convert float [-1,1] -> int16 PCM in chunks straight from the
    // caller's RAM buffer -- no SD, no second full-size buffer. `static`
    // for the same stack-budget reason as write_wav_to_sd()'s buffer --
    // this function's frame can still be live when it calls
    // write_wav_to_sd() below on the failure path, and the two buffers
    // would otherwise stack on top of each other on the same 8KB task stack.
    const int chunk = 2048;
    static int16_t pcm[2048];
    for (int i = 0; ok && i < n_samples; i += chunk) {
        int n = n_samples - i;
        if (n > chunk) n = chunk;
        for (int j = 0; j < n; j++) {
            float s = audio[i + j];
            if (s > 1.0f) s = 1.0f;
            if (s < -1.0f) s = -1.0f;
            pcm[j] = (int16_t)(s * 32767.0f);
        }
        if (esp_http_client_write(client, (const char *)pcm, n * (int)sizeof(int16_t)) < 0) {
            ok = 0;
        }
    }

    if (ok && esp_http_client_write(client, post_part, post_len) < 0) ok = 0;

    int status = ok ? finish_upload_request(client, true) : -1;
    if (client != NULL && !ok) {
        // finish_upload_request() wasn't reached -- clean up here instead.
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
    }

    if (status == 200) {
        ESP_LOGI(TAG, "Upload OK: %s", filename);
        s_clip_counter++;
        return 0;
    }

    ESP_LOGW(TAG, "Upload failed (http status=%d) -- spilling to SD for later retry", status);
    char path[64];
    if (write_wav_to_sd(audio, n_samples, sample_rate, path, sizeof(path)) == 0) {
        ESP_LOGI(TAG, "Spilled to %s", path);
        return -1;
    }
    ESP_LOGW(TAG, "SD unavailable or write failed -- clip dropped (no fallback storage)");
    return -1;
}

void sd_upload_retry_pending(void) {
    if (!s_sd_mounted) {
        return;
    }
    DIR *dir = opendir(MOUNT_POINT);
    if (dir == NULL) {
        return;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "cry_", 4) != 0) {
            continue;
        }
        char full_path[300];
        snprintf(full_path, sizeof(full_path), MOUNT_POINT "/%s", entry->d_name);
        if (upload_wav_file(full_path) == 0) {
            remove(full_path);
        }
    }
    closedir(dir);
}
