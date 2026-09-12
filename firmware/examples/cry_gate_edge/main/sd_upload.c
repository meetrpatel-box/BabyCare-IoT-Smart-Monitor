// sd_upload.c — see sd_upload.h for the pin-verification caveat.
#include "sd_upload.h"

#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>

#include "esp_log.h"
#include "esp_http_client.h"
#include "esp_vfs_fat.h"
#include "sdmmc_cmd.h"
#include "driver/sdmmc_host.h"
#include "sdkconfig.h"

static const char *TAG = "sd_upload";

#define MOUNT_POINT "/sdcard"
#define WAV_HEADER_BYTES 44
#define PCM_BYTES (CRY_GATE_N_SAMPLES * 2)  /* 16-bit mono */
#define WAV_FILE_BYTES (WAV_HEADER_BYTES + PCM_BYTES)

static bool s_sd_mounted = false;
static sdmmc_card_t *s_card = NULL;
static int s_clip_counter = 0;

// ── WAV header (44-byte canonical PCM RIFF header) ──────────────────────
static void write_wav_header(FILE *f, int n_samples, int sample_rate) {
    uint32_t data_bytes = (uint32_t)n_samples * 2;
    uint32_t riff_bytes = 36 + data_bytes;
    uint16_t num_channels = 1, bits_per_sample = 16;
    uint32_t byte_rate = sample_rate * num_channels * bits_per_sample / 8;
    uint16_t block_align = num_channels * bits_per_sample / 8;

    fwrite("RIFF", 1, 4, f);
    fwrite(&riff_bytes, 4, 1, f);
    fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f);
    uint32_t fmt_chunk_size = 16;
    fwrite(&fmt_chunk_size, 4, 1, f);
    uint16_t audio_format = 1;  /* PCM */
    fwrite(&audio_format, 2, 1, f);
    fwrite(&num_channels, 2, 1, f);
    uint32_t sr = (uint32_t)sample_rate;
    fwrite(&sr, 4, 1, f);
    fwrite(&byte_rate, 4, 1, f);
    fwrite(&block_align, 2, 1, f);
    fwrite(&bits_per_sample, 2, 1, f);
    fwrite("data", 1, 4, f);
    fwrite(&data_bytes, 4, 1, f);
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
    slot_cfg.clk = CONFIG_CRY_GATE_SD_PIN_CLK;
    slot_cfg.cmd = CONFIG_CRY_GATE_SD_PIN_CMD;
    slot_cfg.d0 = CONFIG_CRY_GATE_SD_PIN_D0;
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

static int write_wav_to_sd(const float *audio, char *out_path, size_t out_path_len) {
    if (!s_sd_mounted) {
        return -1;
    }
    snprintf(out_path, out_path_len, MOUNT_POINT "/cry_%06d.wav", s_clip_counter++);

    FILE *f = fopen(out_path, "wb");
    if (f == NULL) {
        ESP_LOGE(TAG, "fopen(%s) failed", out_path);
        return -1;
    }

    write_wav_header(f, CRY_GATE_N_SAMPLES, CRY_GATE_SR);

    // Convert float [-1,1] -> int16 PCM in chunks (avoid a second
    // full-size heap buffer alongside the caller's float buffer).
    const int chunk = 4096;
    int16_t pcm[4096];
    for (int i = 0; i < CRY_GATE_N_SAMPLES; i += chunk) {
        int n = CRY_GATE_N_SAMPLES - i;
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
    ESP_LOGI(TAG, "Saved %s (%d bytes)", out_path, (int)WAV_FILE_BYTES);
    return 0;
}

// ── HTTP multipart/form-data upload, streamed from the SD file ─────────
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

    esp_http_client_config_t config = {
        .url = CONFIG_CRY_GATE_API_URL,
        .method = HTTP_METHOD_POST,
        // 120s, not the more typical ~20s: the production API is deployed on
        // Google Cloud Run (see docs/ENGINEERING_DECISIONS.md #7), which
        // scales to zero when idle -- a cold-start request was observed to
        // take 90s+ before the container was warm, vs. ~2s once warm. A
        // short timeout here would spuriously fail the very first upload
        // after any idle period. sd_upload_retry_pending() still covers the
        // case where even this isn't enough.
        .timeout_ms = 120000,
    };
    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        fclose(f);
        return -1;
    }

    char content_type[64];
    snprintf(content_type, sizeof(content_type), "multipart/form-data; boundary=%s", boundary);
    esp_http_client_set_header(client, "Content-Type", content_type);

    esp_err_t err = esp_http_client_open(client, (int)content_length);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_http_client_open failed: %s", esp_err_to_name(err));
        esp_http_client_cleanup(client);
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

    int status = -1;
    if (ok) {
        int64_t body_len = esp_http_client_fetch_headers(client);
        (void)body_len;
        status = esp_http_client_get_status_code(client);
        // Drain response body so the connection can be reused/closed cleanly.
        char resp_buf[256];
        int r;
        while ((r = esp_http_client_read(client, resp_buf, sizeof(resp_buf) - 1)) > 0) {
            resp_buf[r] = '\0';
        }
    }

    esp_http_client_close(client);
    esp_http_client_cleanup(client);

    if (status == 200) {
        ESP_LOGI(TAG, "Upload OK: %s", path);
        return 0;
    }
    ESP_LOGW(TAG, "Upload failed for %s (http status=%d) -- will retry later", path, status);
    return -1;
}

int sd_upload_save_and_queue(const float *audio) {
    char path[64];
    if (write_wav_to_sd(audio, path, sizeof(path)) != 0) {
        return -1;
    }

    if (upload_wav_file(path) == 0) {
        remove(path);
    }
    return 0;
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
        char full_path[64];
        snprintf(full_path, sizeof(full_path), MOUNT_POINT "/%s", entry->d_name);
        if (upload_wav_file(full_path) == 0) {
            remove(full_path);
        }
    }
    closedir(dir);
}
