#include "ws_server.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "audio_manager.h"
#include <string.h>

static const char *TAG = "ws_server";

static esp_err_t audio_handler(httpd_req_t *req)
{
    if (req->method == HTTP_GET) {
        ESP_LOGI(TAG, "Handshake done, new connection opened");
        return ESP_OK;
    }

    httpd_ws_frame_t ws_pkt;
    uint8_t *buf = NULL;
    memset(&ws_pkt, 0, sizeof(httpd_ws_frame_t));
    ws_pkt.type = HTTPD_WS_TYPE_BINARY;

    esp_err_t ret = httpd_ws_recv_frame(req, &ws_pkt, 0);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "httpd_ws_recv_frame failed to get frame len with %d", ret);
        return ret;
    }
    
    if (ws_pkt.len) {
        buf = (uint8_t *)calloc(1, ws_pkt.len + 1);
        if (buf == NULL) {
            ESP_LOGE(TAG, "Failed to calloc memory for buf");
            return ESP_ERR_NO_MEM;
        }
        ws_pkt.payload = buf;
        ret = httpd_ws_recv_frame(req, &ws_pkt, ws_pkt.len);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "httpd_ws_recv_frame failed with %d", ret);
            free(buf);
            return ret;
        }
        
        // Push received PCM data to the speaker queue
        if (ws_pkt.type == HTTPD_WS_TYPE_BINARY) {
            // Break down payload into 1024-byte chunks if larger
            size_t remaining = ws_pkt.len;
            uint8_t *ptr = buf;
            while (remaining > 0) {
                size_t chunk = (remaining > 1024) ? 1024 : remaining;
                if (xQueueSend(rx_audio_queue, ptr, 0) != pdTRUE) {
                    // Queue full, drop a frame to keep it real-time
                    uint8_t temp[1024];
                    xQueueReceive(rx_audio_queue, temp, 0);
                    xQueueSend(rx_audio_queue, ptr, 0);
                }
                ptr += chunk;
                remaining -= chunk;
            }
        }
        free(buf);
    }
    return ESP_OK;
}

static const httpd_uri_t audio_ws = {
        .uri        = "/audio",
        .method     = HTTP_GET,
        .handler    = audio_handler,
        .user_ctx   = NULL,
        .is_websocket = true
};

void ws_server_start(void)
{
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();

    httpd_handle_t server = NULL;
    ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
    if (httpd_start(&server, &config) == ESP_OK) {
        ESP_LOGI(TAG, "Registering URI handlers");
        httpd_register_uri_handler(server, &audio_ws);
    } else {
        ESP_LOGI(TAG, "Error starting server!");
    }
}
