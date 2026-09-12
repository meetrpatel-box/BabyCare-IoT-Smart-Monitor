# ESP32 Board Monorepo

Firmware for the BabyCare smart-cradle hardware (ESP32-S3-Korvo-2 V3):
production device firmware plus standalone feature examples developed
and tested in isolation before being folded into the production build.

## Branches — what lives where

| Branch | What it is | Use it if... |
|---|---|---|
| **`main`** (this branch) | The baseline BabyCare firmware (WiFi/BLE provisioning, MQTT control, camera stream, speaker/mic, sensors) plus the standalone `bluetooth`, `play_mp3_control`, `pipeline_recording_to_sdcard` examples. **No infant-cry ML detection.** | You want the production firmware as it's always worked, unchanged. |
| **`edgedeployment`** | Everything here, **plus** on-device infant-cry-detection: a standalone `examples/cry_gate_edge` device, and an additive, opt-in integration of the same feature into `babycare/` (new MQTT commands, nothing runs unless explicitly started). | You want the cry-detection feature. Not yet flashed/tested on real hardware — see that branch's README for details. |

## Repository layout

```
esp32board/
├── babycare/                    # Production firmware (ESP32-S3-Korvo-2 V3)
│   └── main/app_main.c           #   WiFi/BLE prov, MQTT, camera, speaker/mic, sensors
├── examples/
│   ├── bluetooth/                # BLE peripheral example
│   ├── play_mp3_control/         # MP3 playback + touch controls example
│   └── pipeline_recording_to_sdcard/  # ESP-ADF audio-to-SD example
├── components/                   # Reusable drivers/components (placeholders)
├── boards/                       # Board definitions, pin mappings (placeholders)
└── tools/, scripts/, ci/         # Helpers and CI workflows
```

## Hardware

**ESP32-S3-Korvo-2 V3** (official Espressif dev board): ESP32-S3-WROOM-1,
8MB octal PSRAM, 16MB flash, ES8311 (speaker DAC) + ES7210 (4-mic array
ADC) codecs on a shared I2S bus, OV-series camera module, microSD slot.

## BabyCare firmware (`babycare/`)

The production device. Single ESP-IDF app (`app_main.c`) covering:

- **WiFi provisioning** over BLE (GATT service, SSID/password scan+connect), falls back to BLE provisioning mode if no saved credentials.
- **MQTT control** (`cradle/<deviceId>/...` topics): status heartbeat, JSON commands (`ping`/`status`/`start_recording`/`play_audio`/`reboot`/`reconnect`/etc.), sensor vitals published every 5s, base64 audio chunks.
- **Camera** (QVGA JPEG, DRAM framebuffer) streamed over HTTP MJPEG on port 81.
- **Speaker/mic** via a shared I2S0 duplex bus (ES8311 TX + ES7210 RX, 16kHz) — on-demand recording streamed over MQTT, soothing-sound playback (lullabies/white noise/heartbeat, synthesized tones).

Build/flash (standard ESP-IDF workflow):
```bash
cd babycare
idf.py set-target esp32s3
idf.py build
idf.py -p <PORT> flash monitor
```

## Other examples

- **`bluetooth`** — BLE peripheral (`bleprph`) for testing/integration.
- **`play_mp3_control`** — MP3 playback + touch-button Play/Set/Vol controls.
- **`pipeline_recording_to_sdcard`** — ESP-ADF audio pipeline: codec → I2S → WAV/Opus encoder → SD card (uses the ESP-ADF framework, unlike `babycare` which uses raw ESP-IDF drivers directly).

## Workflow notes

- New features are added under `examples/` and later integrated into `components/`/`boards/`/`babycare/` when requested.
- Infant-cry ML detection development happens on the `edgedeployment` branch, kept separate until it's verified on real hardware — see that branch for the full architecture and current status.
