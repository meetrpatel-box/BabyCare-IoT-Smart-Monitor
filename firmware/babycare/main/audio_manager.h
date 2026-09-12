#pragma once

#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the codecs, create queues, and start audio tasks
void audio_manager_init(void);

// Queue to receive 1024-byte chunks of PCM from the microphone (16-bit Mono, 16kHz)
// Read from this queue to send to the WebSocket Client
extern QueueHandle_t tx_audio_queue;

// Queue to send 1024-byte chunks of PCM to the speaker (16-bit Mono, 16kHz)
// Write to this queue when receiving from the WebSocket Server
extern QueueHandle_t rx_audio_queue;

#ifdef __cplusplus
}
#endif
