// app_main.c — standalone cry-gate device: capture -> mel -> infer ->
// threshold -> save+upload accepted clips. See README.md for scope and
// docs/ENGINEERING_DECISIONS.md for the reasoning behind every non-obvious
// choice (mic sample rate, model format, padding fix, etc).
//
// *** Before trusting this on real hardware: audio_capture.c's ES7210
// register sequence and sd_upload.c's SD card pins are both flagged as
// unverified in their own file headers. Flash this, check logs for I2S/SD
// init success, and listen to a captured WAV before relying on the
// classifier output. ***
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_heap_caps.h"
#include "nvs_flash.h"
#include "sdkconfig.h"

#include "cry_gate_params.h"
#include "audio_capture.h"
#include "mel_spectrogram.h"
#include "cry_gate_inference.h"
#include "sd_upload.h"

static const char *TAG = "cry_gate_edge";

static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t event_id, void *data) {
    if (base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGW(TAG, "WiFi disconnected, retrying");
        esp_wifi_connect();
    } else if (base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ESP_LOGI(TAG, "WiFi connected");
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static void wifi_init_and_connect(void) {
    s_wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t wcfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&wcfg));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL));

    wifi_config_t wifi_cfg = {0};
    strlcpy((char *)wifi_cfg.sta.ssid, CONFIG_CRY_GATE_WIFI_SSID, sizeof(wifi_cfg.sta.ssid));
    strlcpy((char *)wifi_cfg.sta.password, CONFIG_CRY_GATE_WIFI_PASSWORD, sizeof(wifi_cfg.sta.password));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_cfg));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "Connecting to WiFi SSID '%s'...", CONFIG_CRY_GATE_WIFI_SSID);
    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT, pdFALSE, pdTRUE, portMAX_DELAY);
}

static void retry_upload_task(void *pv) {
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(60000));
        sd_upload_retry_pending();
    }
}

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    wifi_init_and_connect();

    if (sd_upload_init() != 0) {
        ESP_LOGW(TAG, "SD unavailable -- accepted clips will not be saved/uploaded "
                      "(inference still runs and logs results)");
    }

    if (audio_capture_init() != 0) {
        ESP_LOGE(TAG, "audio_capture_init failed -- halting");
        while (1) vTaskDelay(pdMS_TO_TICKS(1000));
    }
    if (mel_spectrogram_init() != 0) {
        ESP_LOGE(TAG, "mel_spectrogram_init failed -- halting");
        while (1) vTaskDelay(pdMS_TO_TICKS(1000));
    }
    if (cry_gate_inference_init() != 0) {
        ESP_LOGE(TAG, "cry_gate_inference_init failed -- halting");
        while (1) vTaskDelay(pdMS_TO_TICKS(1000));
    }

    xTaskCreate(retry_upload_task, "retry_upload", 4096, NULL, 3, NULL);

    ESP_LOGI(TAG, "cry_gate_edge ready. Capturing %d-second clips at %dHz, threshold=%.2f",
             (int)CRY_GATE_DURATION_S, CRY_GATE_SR, CRY_GATE_THRESHOLD);

    // ~882KB + ~220KB — too large for internal SRAM (~512KB total, shared
    // with WiFi/BT/stacks), so both live in PSRAM. Requires CONFIG_SPIRAM=y
    // (see sdkconfig.defaults).
    float *s_audio = (float *)heap_caps_malloc(CRY_GATE_N_SAMPLES * sizeof(float), MALLOC_CAP_SPIRAM);
    mel_features_t *s_features = (mel_features_t *)heap_caps_malloc(sizeof(mel_features_t), MALLOC_CAP_SPIRAM);
    if (s_audio == NULL || s_features == NULL) {
        ESP_LOGE(TAG, "Failed to allocate audio/feature buffers in PSRAM -- halting");
        while (1) vTaskDelay(pdMS_TO_TICKS(1000));
    }

    while (1) {
        ESP_LOGI(TAG, "Listening...");
        if (audio_capture_record_10s(s_audio) != 0) {
            ESP_LOGW(TAG, "Capture failed, retrying");
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        if (mel_spectrogram_compute(s_audio, s_features) != 0) {
            ESP_LOGW(TAG, "Mel computation failed, skipping clip");
            continue;
        }

        float prob = cry_gate_inference_run(s_features);
        if (prob < 0.0f) {
            ESP_LOGW(TAG, "Inference failed, skipping clip");
            continue;
        }

        ESP_LOGI(TAG, "Clip score=%.4f (threshold=%.2f) -> %s",
                 prob, CRY_GATE_THRESHOLD, prob >= CRY_GATE_THRESHOLD ? "CRY" : "not cry");

        if (prob >= CRY_GATE_THRESHOLD) {
            sd_upload_save_and_queue(s_audio);
        }
    }
}
