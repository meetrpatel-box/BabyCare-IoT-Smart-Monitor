#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_err.h"
#include "nvs_flash.h"

#include "bsp_board.h"
#include "tca9555_driver.h"

#include "network_manager.h"
#include "audio_manager.h"
#include "ws_server.h"
#include "ws_client.h"

static const char *TAG = "app_main";

extern "C" void app_main()
{
    ESP_LOGI(TAG, "Initializing NVS...");
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      ret = nvs_flash_init();
    }

    ESP_LOGI(TAG, "Initializing Board Configuration...");
    // Initialize board with 16kHz sample rate, 2 channels, 16 bits
    ESP_ERROR_CHECK(esp_board_init(16000, 2, 16));
    
    // Initialize I2C IO expander for board peripherals
    tca9555_driver_init();
    
    ESP_LOGI(TAG, "Initializing Network...");
    network_manager_init();

    ESP_LOGI(TAG, "Initializing Audio...");
    audio_manager_init();

    ESP_LOGI(TAG, "Starting WebSocket Server...");
    ws_server_start();

    ESP_LOGI(TAG, "Starting WebSocket Client...");
    ws_client_start();

    ESP_LOGI(TAG, "Babycare P2P Intercom Started Successfully.");
}
