#include "ws_client.h"
#include "esp_websocket_client.h"
#include "esp_log.h"
#include "network_manager.h"
#include "audio_manager.h"
#include "freertos/task.h"
#include <string.h>
#include <stdio.h>

static const char *TAG = "ws_client";

static esp_websocket_client_handle_t client = NULL;
static bool is_connected = false;

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_websocket_event_data_t *data = (esp_websocket_event_data_t *)event_data;
    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            ESP_LOGI(TAG, "WEBSOCKET_EVENT_CONNECTED");
            is_connected = true;
            // Clear the TX queue so we don't send stale data
            xQueueReset(tx_audio_queue);
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "WEBSOCKET_EVENT_DISCONNECTED");
            is_connected = false;
            break;
        default:
            break;
    }
}

static void ws_client_task(void *pvParameters)
{
    char peer_ip[16] = {0};
    char ws_uri[64] = {0};
    uint8_t tx_buf[1024];

    while (1) {
        // 1. Wait for WiFi connection
        if (!network_manager_is_connected()) {
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        // 2. Discover peer IP via mDNS if not already connected
        if (!is_connected) {
            ESP_LOGI(TAG, "Searching for peer via mDNS...");
            if (network_manager_get_peer_ip(peer_ip, sizeof(peer_ip))) {
                ESP_LOGI(TAG, "Found peer at %s", peer_ip);
                
                // Construct URI
                snprintf(ws_uri, sizeof(ws_uri), "ws://%s/audio", peer_ip);
                
                // Initialize WebSocket Client
                esp_websocket_client_config_t websocket_cfg = {};
                websocket_cfg.uri = ws_uri;
                // Important: Need a larger buffer size for audio
                websocket_cfg.buffer_size = 4096;
                
                if (client != NULL) {
                    esp_websocket_client_destroy(client);
                    client = NULL;
                }

                client = esp_websocket_client_init(&websocket_cfg);
                esp_websocket_register_events(client, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void *)client);
                esp_websocket_client_start(client);
                
                // Wait for connection to establish
                int timeout = 0;
                while (!is_connected && timeout < 50) { // 5 seconds
                    vTaskDelay(pdMS_TO_TICKS(100));
                    timeout++;
                }
                
                if (!is_connected) {
                    ESP_LOGW(TAG, "Failed to connect to %s, retrying discovery...", ws_uri);
                    esp_websocket_client_stop(client);
                    esp_websocket_client_destroy(client);
                    client = NULL;
                    vTaskDelay(pdMS_TO_TICKS(2000));
                    continue;
                }
            } else {
                // Peer not found, retry after a delay
                vTaskDelay(pdMS_TO_TICKS(2000));
                continue;
            }
        }

        // 3. Send audio data while connected
        while (is_connected) {
            if (xQueueReceive(tx_audio_queue, tx_buf, pdMS_TO_TICKS(100)) == pdTRUE) {
                esp_err_t err = esp_websocket_client_send_bin(client, (const char *)tx_buf, sizeof(tx_buf), pdMS_TO_TICKS(100));
                if (err < 0) {
                    ESP_LOGE(TAG, "Error sending binary data: %d", err);
                    is_connected = false;
                    break;
                }
            }
        }
        
        // Disconnected, clean up
        if (client) {
            esp_websocket_client_stop(client);
            esp_websocket_client_destroy(client);
            client = NULL;
        }
    }
}

void ws_client_start(void)
{
    xTaskCreate(ws_client_task, "ws_client_task", 4096, NULL, 5, NULL);
}
