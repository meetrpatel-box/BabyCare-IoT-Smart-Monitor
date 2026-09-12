# 🍼 BabyCare IoT Smart Monitor & Cradle System

[![ESP32-S3](https://img.shields.io/badge/Hardware-ESP32--S3-blue.svg)](https://www.espressif.com/)
[![Flutter](https://img.shields.io/badge/App-Flutter%203.x-02569B.svg)](https://flutter.dev/)
[![WebRTC](https://img.shields.io/badge/Streaming-WebRTC%2030fps-success.svg)](https://webrtc.org/)
[![Go](https://img.shields.io/badge/Cloud%20Relay-Go%201.22-00ADD8.svg)](https://golang.org/)
[![TensorFlow Lite Micro](https://img.shields.io/badge/Edge%20AI-TFLite%20Micro-orange.svg)](https://www.tensorflow.org/lite/microcontrollers)
[![Full-Duplex Audio](https://img.shields.io/badge/Voice-Full--Duplex%20Bidirectional-green.svg)](#bidirectional-audio)

An end-to-end, enterprise-grade smart baby monitoring and motorized cradle automation system powered by the **ESP32-S3**, **Go Cloud Relay infrastructure**, and a **Flutter cross-platform mobile application**.

---

## 🌟 Key Features

- **🏠 Intelligent Network Path Switching**:
  - **Local LAN Direct Mode**: When phone and monitor share the same Wi-Fi, the app streams **MJPEG video (< 40ms latency)** over port 81 and **peer-to-peer UDP audio** over port 8282—completely bypassing cloud bandwidth!
  - **Cloud WebRTC Relay Mode**: When outside home (4G/5G/remote WAN), streams ultra-smooth **WebRTC video (30fps @ 720p)** and talkback audio via AWS cloud relay.
  - **Auto-Detection**: Probes local network reachability in < 1.2s and auto-transitions smoothly.
- **🎙️ True Full-Duplex Bidirectional Audio**:
  - Continuous baby monitor audio stream (no walkie-talkie cutoffs!).
  - Simultaneous parent voice playback out of the ESP32 speaker.
  - Digital software amplification (4x gain) for loud, crystal-clear sound.
- **👶 Onboard Infant Cry Detection (Edge AI)**:
  - Embedded TensorFlow Lite Micro neural network running directly on ESP32-S3.
  - Real-time mel-spectrogram feature extraction from ES7210 microphone array.
- **❤️ Contactless Radar Vitals & Sleep Analysis**:
  - **HLK-LD6002 mmWave radar**: Real-time heart rate, respiratory rate, and micro-movements.
  - **MLX90614 Infrared sensor**: Contactless baby skin temperature & ambient room temperature.
  - Multi-state sleep classification: `DEEP_SLEEP`, `LIGHT_SLEEP`, `AWAKE`, `OUT_OF_BED`.
- **🔄 Stepper Motor Cradle Pan/Tilt**:
  - Dual 28BYJ-48 stepper motors driven via a 74HC595 shift register.
  - Smooth pan/tilt pan camera control via Flutter app or MQTT commands.

---

## 📐 Architecture Diagram

```mermaid
graph TD
    subgraph "Nursery / Hardware (ESP32-S3)"
        CAM[OV2640 / OV3660 Camera]
        MIC[ES7210 4-Channel ADC Mic]
        SPK[ES8311 DAC + Speaker]
        RADAR[LD6002 mmWave Radar]
        TEMP[MLX90614 Bit-Bang I2C]
        MOTOR[74HC595 + Dual Steppers]
        TFLITE[TFLite Micro Infant Cry Model]
    end

    subgraph "Network Routing"
        LOCAL_ROUTE{Same Wi-Fi Network?}
    end

    subgraph "Cloud Relay Infrastructure (AWS VPS)"
        RELAY[BabyTrack Go Relay :8765/:8766]
        RTC[go2rtc WebRTC Server :1984]
        MQTT_BROKER[HiveMQ MQTT Broker]
    end

    subgraph "Parent Mobile App (Flutter)"
        APP_VID[Video Player MJPEG / WebRTC]
        APP_AUDIO[AudioTrack + Record VoIP]
        APP_VITALS[Real-Time Vitals & Sleep Charts]
        APP_CTRL[Motor Pan/Tilt Controller]
    end

    CAM --> LOCAL_ROUTE
    MIC --> LOCAL_ROUTE
    SPK <-- LOCAL_ROUTE

    LOCAL_ROUTE -- "YES (Local LAN Direct)" -->|MJPEG port 81| APP_VID
    LOCAL_ROUTE -- "YES (Local LAN Direct)" -->|UDP port 8282 Full-Duplex| APP_AUDIO
    
    LOCAL_ROUTE -- "NO (Remote WAN)" -->|WebSocket Ingest 0x56/0x57| RELAY
    RELAY -->|AV Stream| RTC
    RTC -->|WebRTC 30fps Opus/H264| APP_VID
    APP_AUDIO -->|WebSocket Talkback 0x53| RELAY
    RELAY -->|Talkback Forward| SPK

    RADAR --> MQTT_BROKER
    TEMP --> MQTT_BROKER
    TFLITE --> MQTT_BROKER
    MQTT_BROKER -->|cradle/device001/vitals| APP_VITALS
    APP_CTRL -->|cradle/device001/cmd| MOTOR
```

---

## 📂 Repository Structure

```
BabyCare-IoT-Smart-Monitor/
├── firmware/                  # ESP32-S3 ESP-IDF C/C++ Firmware
│   ├── babycare/              # Main IDF project
│   │   ├── main/
│   │   │   ├── app_main.c     # Core tasks, network routing, FreeRTOS scheduler
│   │   │   ├── camera_stream.c# Cloud WS ingest & talkback reassembly
│   │   │   ├── hardeware_driver/ # ES7210 / ES8311 audio codecs & I2S
│   │   │   ├── cry_gate_inference.cc # TensorFlow Lite infant cry model
│   │   │   └── tca9555_driver/# I2C IO expander driver
│   │   ├── sdkconfig          # Memory, FreeRTOS, PSRAM, lwIP IP reassembly
│   │   └── partitions.csv     # Custom flash partition scheme
│   └── components/            # Extra IDF components
│
├── mobile-app/                # Flutter Cross-Platform Mobile Application
│   ├── lib/
│   │   ├── screens/           # Dashboard, live camera bottom sheet, charts
│   │   ├── services/
│   │   │   ├── cloud_webrtc_service.dart # go2rtc WebRTC stream client
│   │   │   ├── live_speak_service.dart   # VoIP microphone talkback engine
│   │   │   ├── audio_udp_service.dart    # Low-latency local LAN UDP engine
│   │   │   └── device_mqtt_service.dart  # MQTT vitals, cry alarms, pan/tilt
│   │   └── models/            # Device & telemetry data models
│   └── pubspec.yaml           # Flutter dependencies
│
├── cloud-relay/               # High-Performance Go Cloud Relay
│   ├── main.go                # WebSocket ingest, talkback proxy & HTTP media
│   ├── go.mod                 # Go dependencies
│   ├── babytrack-relay.service# Systemd service descriptor
│   └── nginx_relay.conf       # SSL termination, WebRTC & talkback reverse proxy
│
├── apk/                       # Pre-compiled Android application packages
│   └── README.md              # Installation instructions
│
└── README.md                  # Complete documentation
```

---

## 🛠️ Hardware Bill of Materials (BOM)

| Component | Function | Interface / Pins |
| :--- | :--- | :--- |
| **ESP32-S3-WROOM-1** | Dual-core 240MHz MCU with 8MB PSRAM & 16MB Flash | Core processor |
| **OV2640 / OV3660** | Night-vision camera sensor | DVP 8-bit parallel bus |
| **ES7210** | 4-channel microphone ADC | I2S1 Rx + I2C |
| **ES8311** | Low-power mono audio DAC | I2S1 Tx + I2C |
| **HLK-LD6002** | 60GHz mmWave human presence radar | UART1 (`GPIO 3 Tx`, `GPIO 4 Rx`) |
| **MLX90614** | Contactless infrared temperature sensor | Soft Bit-bang I2C (`GPIO 8 SDA`, `GPIO 9 SCL`) |
| **74HC595** | 8-bit serial shift register | `GPIO 5 CLK`, `GPIO 6 LATCH`, `GPIO 7 DATA` |
| **28BYJ-48 (x2)** | Pan & Tilt stepper motors | Driven via ULN2003 / 74HC595 |

---

## 🚀 Getting Started

### 1. Flashing ESP32-S3 Firmware

1. Install [ESP-IDF v5.3](https://docs.espressif.com/projects/esp-idf/en/v5.3/esp32s3/get-started/):
   ```bash
   cd firmware/babycare
   idf.py set-target esp32s3
   idf.py build
   ```
2. Connect the ESP32-S3 via USB-C to `/dev/ttyACM0` (or `COMx` on Windows):
   ```bash
   idf.py -p /dev/ttyACM0 flash monitor
   ```

### 2. Deploying Cloud Relay (AWS EC2 / VPS)

1. Build the Go binary:
   ```bash
   cd cloud-relay
   go build -o babytrack-relay main.go
   ```
2. Copy `babytrack-relay.service` to `/etc/systemd/system/` and enable:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now babytrack-relay
   ```
3. Configure Nginx with SSL (`certbot`) using `cloud-relay/nginx_relay.conf`.

### 3. Running the Mobile App (Flutter)

1. Ensure Flutter 3.x is installed:
   ```bash
   cd mobile-app
   flutter pub get
   ```
2. Run on a connected Android phone or emulator:
   ```bash
   flutter run --debug
   ```
3. Or build a standalone APK:
   ```bash
   flutter build apk --split-per-abi
   ```

---

## 📱 Mobile App APK Download

The latest pre-compiled Android APK is available under the **[Releases](https://github.com/meetrpatel-box/BabyCare-IoT-Smart-Monitor/releases)** tab:
- **`babycare-update.apk`**: Compatible with Android 8.0 through Android 15 (ARM64-v8a).

---

## 🔒 Security & Privacy

- **Token Authentication**: All WebSocket ingest routes, WebRTC signalling endpoints, and talkback channels require secure 256-bit authentication tokens.
- **Local Network Isolation**: When on home Wi-Fi, audio and video stream directly between the phone and device over the local LAN without routing through external servers.
- **Edge AI Processing**: Infant cry detection runs entirely on-chip on the ESP32-S3—no audio leaves the nursery unless actively viewed.

---

## 📄 License
This project is licensed under the MIT License.
