#include "audio_manager.h"
#include "bsp_board.h"
#include "esp_codec_dev.h"
#include "esp_log.h"
#include "freertos/task.h"

static const char *TAG = "audio_manager";

QueueHandle_t tx_audio_queue = NULL;
QueueHandle_t rx_audio_queue = NULL;

static esp_codec_dev_handle_t output_dev = NULL;
static esp_codec_dev_handle_t input_dev = NULL;

// Chunk size we will transmit over WebSocket (1024 bytes of 16-bit Mono)
#define AUDIO_CHUNK_SIZE 1024

// Size required to read from Codec (4 channels, 16 bits = 8 bytes per frame)
// If we want 1024 bytes of Mono (512 frames), we must read 512 * 8 = 4096 bytes.
#define CODEC_READ_SIZE (AUDIO_CHUNK_SIZE * 4)

static void mic_read_task(void *pvParameters)
{
    uint8_t *raw_data = (uint8_t *)heap_caps_malloc(CODEC_READ_SIZE, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    uint8_t *mono_data = (uint8_t *)heap_caps_malloc(AUDIO_CHUNK_SIZE, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    
    if (!raw_data || !mono_data) {
        ESP_LOGE(TAG, "Failed to allocate memory for Mic Task!");
        vTaskDelete(NULL);
    }

    while (1) {
        if (input_dev) {
            int err = esp_codec_dev_read(input_dev, raw_data, CODEC_READ_SIZE);
            if (err == ESP_CODEC_DEV_OK) {
                int16_t *raw_pcm = (int16_t *)raw_data;
                int16_t *mono_pcm = (int16_t *)mono_data;
                
                // Extract Mic 1 (index 1 of 4)
                for (int i = 0; i < 512; i++) {
                    mono_pcm[i] = raw_pcm[4 * i + 1]; 
                }
                
                // Push to TX Queue
                if (xQueueSend(tx_audio_queue, mono_data, 0) != pdTRUE) {
                    // Queue full, drop frame
                    uint8_t temp[AUDIO_CHUNK_SIZE];
                    xQueueReceive(tx_audio_queue, temp, 0);
                    xQueueSend(tx_audio_queue, mono_data, 0);
                }
            } else {
                vTaskDelay(pdMS_TO_TICKS(10));
            }
        } else {
            vTaskDelay(pdMS_TO_TICKS(100));
        }
    }
}

static void speaker_write_task(void *pvParameters)
{
    uint8_t *mono_data = (uint8_t *)heap_caps_malloc(AUDIO_CHUNK_SIZE, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    
    // Playback data requires 32-bit stereo (8 bytes per frame).
    // 512 frames = 4096 bytes.
    int32_t *play_data = (int32_t *)heap_caps_malloc(4096, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);

    if (!mono_data || !play_data) {
        ESP_LOGE(TAG, "Failed to allocate memory for Speaker Task!");
        vTaskDelete(NULL);
    }

    while (1) {
        if (xQueueReceive(rx_audio_queue, mono_data, portMAX_DELAY) == pdTRUE) {
            if (output_dev) {
                int16_t *mono_pcm = (int16_t *)mono_data;
                
                // Convert 16-bit Mono to 32-bit Stereo
                for (int i = 0; i < 512; i++) {
                    int32_t sample32 = ((int32_t)mono_pcm[i]) << 16;
                    play_data[2 * i + 0] = sample32; // Left channel
                    play_data[2 * i + 1] = sample32; // Right channel
                }
                
                esp_codec_dev_write(output_dev, play_data, 4096);
            }
        }
    }
}

void audio_manager_init(void)
{
    tx_audio_queue = xQueueCreate(10, AUDIO_CHUNK_SIZE);
    rx_audio_queue = xQueueCreate(10, AUDIO_CHUNK_SIZE);
    
    output_dev = esp_ret_play_dev();
    input_dev = esp_ret_record_dev();
    
    if (input_dev) {
        esp_codec_dev_set_in_channel_gain(input_dev, ESP_CODEC_DEV_MAKE_CHANNEL_MASK(1), 40.0);
    }
    if (output_dev) {
        esp_codec_dev_set_out_vol(output_dev, 80.0);
    }
    
    xTaskCreate(mic_read_task, "mic_read_task", 4096, NULL, 6, NULL);
    xTaskCreate(speaker_write_task, "speaker_write_task", 4096, NULL, 5, NULL);
}
