# 🫀 Vital Signs Monitoring - Low-Level Design

**Date:** February 2, 2026  
**Feature:** Real-time Vital Signs Monitoring (Heart Rate, SpO2, Temperature, Respiratory Rate)  
**Hardware:** ESP32 + 60GHz mmWave Sensor (Heart Rate/Respiratory) + MAX30102 (SpO2) + MLX90614 (Temperature) + DHT22 (Environment)

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Hardware Architecture](#hardware-architecture)
3. [Data Models](#data-models)
4. [ESP32 Firmware](#esp32-firmware)
5. [Cloud Functions](#cloud-functions)
6. [Flutter Implementation](#flutter-implementation)
7. [Real-time Streaming](#real-time-streaming)
8. [Alert System](#alert-system)
9. [Implementation Roadmap](#implementation-roadmap)

---

## 1️⃣ SYSTEM OVERVIEW

### **1.1 Feature Scope**

| Vital Sign | Sensor | Range | Update Frequency | Alert Thresholds |
|------------|--------|-------|------------------|------------------|
| **Heart Rate** | 60GHz mmWave | 60-240 BPM | Every 2 seconds | <80 or >220 BPM |
| **Respiratory Rate** | 60GHz mmWave | 10-60 BPM | Every 2 seconds | <20 or >60 BPM |
| **SpO2** | MAX30102 | 85-100% | Every 5 seconds | <92% |
| **Body Temp** | MLX90614 (IR) | 35-39°C | Every 10 seconds | <36.5°C or >38°C |
| **Env. Temp** | DHT22 | 16-30°C | Every 30 seconds | <18°C or >26°C |
| **Humidity** | DHT22 | 30-70% | Every 30 seconds | <30% or >60% |

### **1.2 Data Flow Architecture**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          VITAL SIGNS FLOW                                │
└─────────────────────────────────────────────────────────────────────────┘

ESP32 Device                    Firebase Cloud              Flutter App
┌────────────────┐            ┌──────────────────┐         ┌─────────────┐
│                │            │                  │         │             │
│  Sensor Loop   │            │  Cloud Function  │         │  Real-time  │
│  ────────────  │   HTTP     │  ──────────────  │  Stream │  Dashboard  │
│                │   POST     │                  │ ──────> │             │
│  Read MAX30102 │ ────────> │  validateVitals  │         │  ❤️ 120 BPM │
│  - Heart Rate  │            │  - Range check   │         │  🫁 95% SpO2│
│  - SpO2        │            │  - Trend check   │         │  🌡️ 37.2°C  │
│                │            │  - Alert rules   │         │  💨 35 BPM  │
│  Read MLX90614 │            │                  │         │             │
│  - Body Temp   │            │  Save to         │         │  Trends     │
│  - Forehead    │            │  Firestore       │         │  Graph 📊   │
│                │            │  ──────────────  │         │             │
│  Read Breath   │            │  /vitalReadings  │         │  Alerts 🚨  │
│  - Motion      │            │  - Latest        │         │  - High HR  │
│  - Pressure    │            │  - Hourly avg    │         │  - Low SpO2 │
│                │            │  - Daily stats   │         │             │
│  Compress      │            │                  │         │             │
│  - JSON        │            │  Trigger Alerts  │         │  Settings   │
│  - Delta       │            │  ──────────────  │         │  ────────   │
│                │            │  - FCM notify    │         │  Thresholds │
│  Every 5s      │            │  - Sound alarm   │         │  Intervals  │
│                │            │  - Log event     │         │             │
└────────────────┘            └──────────────────┘         └─────────────┘
```

### **1.3 Storage Strategy**

```
Firestore Collections:
├─ devices/{deviceId}/vitalReadings/{timestamp}  (Live readings - 24h retention)
├─ babies/{babyId}/vitals/hourly/{date-hour}     (Aggregated hourly)
├─ babies/{babyId}/vitals/daily/{date}           (Daily statistics)
├─ babies/{babyId}/vitalAlerts/{alertId}         (Alert history)
└─ babies/{babyId}/vitalTrends/{date}            (ML-detected trends)

Data Retention:
- Live readings: 24 hours (then deleted)
- Hourly aggregates: 30 days
- Daily statistics: Permanent
- Alert history: Permanent
```

---

## 2️⃣ HARDWARE ARCHITECTURE

### **2.1 Sensor Pinout (ESP32)**

```cpp
// ═══════════════════════════════════════════════════════════
// ESP32 Pin Configuration
// ═══════════════════════════════════════════════════════════

// MAX30102 (Heart Rate + SpO2) - I2C
#define I2C_SDA_PIN 21
#define I2C_SCL_PIN 22

// MLX90614 (Non-contact IR Temperature) - I2C
// Shares I2C bus with MAX30102

// DHT22 (Environment: Temp + Humidity) - Digital
#define DHT22_PIN 4

// Breath Detection (Pressure Sensor) - Analog
#define BREATH_SENSOR_PIN 34  // ADC1_CH6

// Status LED
#define STATUS_LED_PIN 2

// Power Control
#define SENSOR_POWER_PIN 25  // Enable/disable sensors for power saving
```

### **2.2 Sensor Specifications**

#### **MAX30102 (Heart Rate + SpO2)**
```
Operating Range:
├─ Heart Rate: 0-220 BPM
├─ SpO2: 0-100%
├─ Sample Rate: 400 Hz (default)
├─ Resolution: 16-bit ADC
├─ LED Current: 6.4-51 mA (configurable)
└─ Power: 600 µA @ 1 Hz, 1.2 mA @ 50 Hz

Communication: I2C (address 0x57)
Accuracy: ±2 BPM (HR), ±2% (SpO2)
```

#### **MLX90614 (IR Temperature)**
```
Operating Range:
├─ Object Temp: -70°C to +380°C
├─ Ambient Temp: -40°C to +125°C
├─ Resolution: 0.02°C
└─ Accuracy: ±0.5°C (body temp range)

Communication: I2C (address 0x5A)
Field of View: 90° cone
Response Time: <1 second
Non-contact: 1-5cm optimal distance
```

#### **60GHz mmWave Sensor (Heart Rate + Respiratory)**
```
Operating Range:
├─ Heart Rate: 60-240 BPM
├─ Respiratory Rate: 10-60 BPM
├─ Detection Distance: 0.4-3 meters
├─ Detection Angle: ±60° horizontal, ±40° vertical
├─ Accuracy: ±3 BPM (HR), ±2 BPM (RR)
└─ Response Time: <2 seconds

Communication: UART (115200 baud, 8N1)
Protocol: Custom binary protocol
Power: 100-150 mA @ 5V (active)
Non-contact: Penetrates blankets/clothing
Technology: FMCW radar (Frequency Modulated Continuous Wave)
```

#### **DHT22 (Environment)**
```
Operating Range:
├─ Temperature: -40°C to +80°C
├─ Humidity: 0-100% RH
├─ Temp Accuracy: ±0.5°C
├─ Humidity Accuracy: ±2-5% RH
└─ Sampling Rate: 0.5 Hz (max)

Communication: Single-wire digital
Power: 1.5 mA (measuring), 50 µA (standby)
```

### **2.3 Power Consumption**

```
Active Mode (all sensors on):
├─ ESP32: 160-260 mA
├─ 60GHz mmWave: 120 mA
├─ MAX30102: 1.2 mA
├─ MLX90614: 1.0 mA
├─ DHT22: 1.5 mA
├─ WiFi: 120 mA (transmitting)
└─ Total: ~504 mA @ 3.3V ≈ 1.66W

Sleep Mode (sensors off):
├─ ESP32: 10 mA (light sleep)
├─ Sensors: 0.1 mA
└─ Total: ~10 mA @ 3.3V ≈ 33mW

Battery Life (2000mAh):
├─ Active 24/7: ~5 hours
├─ Active with 50% sleep: ~10 hours
└─ Recommended: USB powered for continuous monitoring
```

---

## 3️⃣ DATA MODELS

### **3.1 ESP32 C++ Structures**

```cpp
// ═══════════════════════════════════════════════════════════
// ESP32 In-Memory Data Structures
// ═══════════════════════════════════════════════════════════

struct VitalReading {
  // Timestamp
  uint32_t timestamp;           // Unix epoch milliseconds
  
  // Cardiovascular
  uint16_t heartRate;           // BPM (0-300)
  uint8_t  spO2;                // Percentage (0-100)
  uint8_t  heartRateQuality;    // Signal quality (0-100)
  
  // Temperature
  float    bodyTemp;            // Celsius (IEEE 754)
  float    envTemp;             // Celsius
  uint8_t  humidity;            // Percentage (0-100)
  
  // Respiratory
  uint8_t  breathRate;          // Breaths per minute (0-100)
  uint8_t  breathQuality;       // Signal quality (0-100)
  
  // Motion & Activity
  uint8_t  motionLevel;         // Percentage (0-100)
  bool     isAsleep;            // Sleep state
  
  // Device status
  uint8_t  batteryLevel;        // Percentage (0-100)
  uint8_t  wifiSignal;          // RSSI mapped to 0-100
  
  // Checksum
  uint32_t crc32;               // CRC32 of all fields
};

struct VitalThresholds {
  // Heart Rate
  uint16_t hrMin;               // Default: 80 BPM
  uint16_t hrMax;               // Default: 220 BPM
  
  // SpO2
  uint8_t  spO2Min;             // Default: 92%
  
  // Temperature
  float    bodyTempMin;         // Default: 36.5°C
  float    bodyTempMax;         // Default: 38.0°C
  float    envTempMin;          // Default: 18.0°C
  float    envTempMax;          // Default: 26.0°C
  
  // Breath Rate
  uint8_t  breathRateMin;       // Default: 20 BPM
  uint8_t  breathRateMax;       // Default: 60 BPM
  
  // Humidity
  uint8_t  humidityMin;         // Default: 30%
  uint8_t  humidityMax;         // Default: 60%
};

struct SensorCalibration {
  // MAX30102 calibration
  int16_t  hrOffset;            // Correction offset
  float    spO2Multiplier;      // Calibration multiplier
  
  // MLX90614 calibration
  float    tempOffset;          // Temperature correction
  
  // Breath sensor
  uint16_t breathBaseline;      // Zero-point baseline
  float    breathSensitivity;   // Sensitivity factor
};
```

### **3.2 Cloud Firestore Schema**

```typescript
// ═══════════════════════════════════════════════════════════
// Firestore Document Schemas
// ═══════════════════════════════════════════════════════════

// Collection: devices/{deviceId}/vitalReadings/{autoId}
interface VitalReadingDocument {
  deviceId: string;
  babyId: string;
  timestamp: FirebaseFirestore.Timestamp;
  
  // Cardiovascular
  heartRate: number;            // BPM
  spO2: number;                 // Percentage
  heartRateQuality: number;     // 0-100
  
  // Temperature
  bodyTemp: number;             // Celsius
  envTemp: number;              // Celsius
  humidity: number;             // Percentage
  
  // Respiratory
  breathRate: number;           // BPM
  breathQuality: number;        // 0-100
  
  // Derived metrics
  perfusionIndex?: number;      // Blood flow indicator
  heartRateVariability?: number;// HRV (ms)
  
  // Context
  motionLevel: number;          // 0-100
  isAsleep: boolean;
  
  // Device status
  batteryLevel: number;
  wifiSignal: number;
  
  // Metadata
  createdAt: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp;  // Auto-delete after 24h
}

// Collection: babies/{babyId}/vitals/hourly/{date-hour}
interface HourlyVitalStats {
  babyId: string;
  date: string;                 // YYYY-MM-DD
  hour: number;                 // 0-23
  
  // Heart Rate statistics
  heartRate: {
    min: number;
    max: number;
    avg: number;
    median: number;
    stdDev: number;
    sampleCount: number;
  };
  
  // SpO2 statistics
  spO2: {
    min: number;
    max: number;
    avg: number;
    belowThresholdCount: number;  // Times below 92%
  };
  
  // Temperature
  bodyTemp: {
    min: number;
    max: number;
    avg: number;
  };
  
  // Breath Rate
  breathRate: {
    min: number;
    max: number;
    avg: number;
  };
  
  // Environment
  envTemp: {
    min: number;
    max: number;
    avg: number;
  };
  humidity: {
    min: number;
    max: number;
    avg: number;
  };
  
  // Alerts triggered
  alertCount: number;
  alertTypes: string[];         // ['low_spo2', 'high_temp']
  
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/vitals/daily/{date}
interface DailyVitalSummary {
  babyId: string;
  date: string;                 // YYYY-MM-DD
  
  // Overall statistics (same structure as hourly)
  heartRate: VitalStats;
  spO2: VitalStats;
  bodyTemp: VitalStats;
  breathRate: VitalStats;
  
  // Sleep correlation
  sleepHours: number;
  avgHeartRateSleeping: number;
  avgHeartRateAwake: number;
  
  // Trends
  trends: {
    heartRateTrend: 'stable' | 'increasing' | 'decreasing';
    tempTrend: 'stable' | 'increasing' | 'decreasing';
    oxygenationTrend: 'stable' | 'improving' | 'concerning';
  };
  
  // Alerts
  totalAlerts: number;
  criticalAlerts: number;
  alertSummary: Record<string, number>;  // {low_spo2: 3, high_temp: 1}
  
  createdAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/vitalAlerts/{alertId}
interface VitalAlertDocument {
  id: string;
  babyId: string;
  deviceId: string;
  
  // Alert details
  alertType: 'low_heart_rate' | 'high_heart_rate' | 'low_spo2' | 
             'high_temp' | 'low_temp' | 'abnormal_breathing' |
             'high_env_temp' | 'low_env_temp' | 'low_humidity' | 'high_humidity';
  severity: 'info' | 'warning' | 'critical';
  
  // Vital values at alert time
  value: number;
  threshold: number;
  unit: string;
  
  // Context
  vitalReading: VitalReadingDocument;  // Full snapshot
  
  // Status
  status: 'active' | 'acknowledged' | 'resolved' | 'auto_resolved';
  acknowledgedBy?: string;             // userId
  acknowledgedAt?: FirebaseFirestore.Timestamp;
  resolvedAt?: FirebaseFirestore.Timestamp;
  
  // Notifications
  notificationSent: boolean;
  soundAlarmTriggered: boolean;
  
  // Timestamps
  triggeredAt: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
}
```

### **3.3 Flutter Dart Models**

```dart
// ═══════════════════════════════════════════════════════════
// Flutter Data Models
// ═══════════════════════════════════════════════════════════

// lib/models/vital_reading_model.dart
class VitalReadingModel {
  final String id;
  final String deviceId;
  final String babyId;
  final DateTime timestamp;
  
  // Cardiovascular
  final int heartRate;
  final int spO2;
  final int heartRateQuality;
  
  // Temperature
  final double bodyTemp;
  final double envTemp;
  final int humidity;
  
  // Derived
  final double? perfusionIndex;
  final double? heartRateVariability;
  
  // Context
  final int motionLevel;
  final bool isAsleep;
  
  // Device
  final int batteryLevel;
  final int wifiSignal;
  
  final DateTime createdAt;
  
  VitalReadingModel({
    required this.id,
    required this.deviceId,
    required this.babyId,
    required this.timestamp,
    required this.heartRate,
    required this.spO2,
    required this.heartRateQuality,
    required this.bodyTemp,
    required this.envTemp,
    required this.humidity,
    this.perfusionIndex,
    this.heartRateVariability,
    required this.motionLevel,
    required this.isAsleep,
    required this.batteryLevel,
    required this.wifiSignal,
    required this.createdAt,
  });
  
  // Health status
  bool get isHeartRateNormal => heartRate >= 80 && heartRate <= 220;
  bool get isSpO2Normal => spO2 >= 92;
  bool get isTempNormal => bodyTemp >= 36.5 && bodyTemp <= 38.0;
  
  bool get hasAnyAlert => !isHeartRateNormal || !isSpO2Normal || 
                          !isTempNormal;
  
  VitalAlertType? get primaryAlert {
    if (spO2 < 92) return VitalAlertType.lowSpO2;
    if (bodyTemp >= 38.0) return VitalAlertType.highTemp;
    if (heartRate > 220) return VitalAlertType.highHeartRate;
    if (heartRate < 80) return VitalAlertType.lowHeartRate;
    return null;
  }
  
  factory VitalReadingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitalReadingModel(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      babyId: data['babyId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      heartRate: data['heartRate'] ?? 0,
      spO2: data['spO2'] ?? 0,
      heartRateQuality: data['heartRateQuality'] ?? 0,
      bodyTemp: (data['bodyTemp'] ?? 0).toDouble(),
      envTemp: (data['envTemp'] ?? 0).toDouble(),
      humidity: data['humidity'] ?? 0,
      perfusionIndex: data['perfusionIndex']?.toDouble(),
      heartRateVariability: data['heartRateVariability']?.toDouble(),
      motionLevel: data['motionLevel'] ?? 0,
      isAsleep: data['isAsleep'] ?? false,
      batteryLevel: data['batteryLevel'] ?? 0,
      wifiSignal: data['wifiSignal'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'babyId': babyId,
      'timestamp': Timestamp.fromDate(timestamp),
      'heartRate': heartRate,
      'spO2': spO2,
      'heartRateQuality': heartRateQuality,
      'bodyTemp': bodyTemp,
      'envTemp': envTemp,
      'humidity': humidity,
      'perfusionIndex': perfusionIndex,
      'heartRateVariability': heartRateVariability,
      'motionLevel': motionLevel,
      'isAsleep': isAsleep,
      'batteryLevel': batteryLevel,
      'wifiSignal': wifiSignal,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(createdAt.add(Duration(hours: 24))),
    };
  }
}

enum VitalAlertType {
  lowHeartRate,
  highHeartRate,
  lowSpO2,
  highTemp,
  lowTemp,
  highEnvTemp,
  lowEnvTemp,
  lowHumidity,
  highHumidity,
}

// lib/models/vital_alert_model.dart
class VitalAlertModel {
  final String id;
  final String babyId;
  final String deviceId;
  final VitalAlertType alertType;
  final VitalAlertSeverity severity;
  final double value;
  final double threshold;
  final String unit;
  final VitalReadingModel vitalReading;
  final VitalAlertStatus status;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final bool notificationSent;
  final bool soundAlarmTriggered;
  final DateTime triggeredAt;
  final DateTime createdAt;
  
  // ... (constructor, fromFirestore, toMap methods)
  
  String get title {
    switch (alertType) {
      case VitalAlertType.lowSpO2:
        return 'Low Oxygen Level';
      case VitalAlertType.highTemp:
        return 'High Temperature';
      case VitalAlertType.lowHeartRate:
        return 'Low Heart Rate';
      case VitalAlertType.highHeartRate:
        return 'High Heart Rate';
      default:
        return 'Vital Alert';
    }
  }
  
  String get message {
    return '$title: $value$unit (threshold: $threshold$unit)';
  }
}

enum VitalAlertSeverity { info, warning, critical }
enum VitalAlertStatus { active, acknowledged, resolved, autoResolved }
```

---

## 4️⃣ ESP32 FIRMWARE

### **4.1 Main Sensor Loop**

```cpp
// ═══════════════════════════════════════════════════════════
// firmware/esp32_vitals/src/main.cpp
// ═══════════════════════════════════════════════════════════

#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <Adafruit_MLX90614.h>
#include <DHT.h>

// ═══════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════

const char* CLOUD_FUNCTION_URL = "https://us-central1-babycare-app.cloudfunctions.net/submitVitals";
String DEVICE_ID = "AnvayaPod-A1B2C3";
String BABY_ID = "baby_Emma_123";

// Update intervals
const unsigned long VITAL_UPDATE_INTERVAL = 5000;   // 5 seconds
const unsigned long ENV_UPDATE_INTERVAL = 30000;    // 30 seconds
const unsigned long UPLOAD_INTERVAL = 5000;         // 5 seconds

// Sensor instances
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
DHT dht(DHT22_PIN, DHT22);

// Global state
VitalReading currentReading;
VitalThresholds thresholds;
unsigned long lastVitalUpdate = 0;
unsigned long lastEnvUpdate = 0;
unsigned long lastUpload = 0;

// Heart rate detection
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int beatAvg;

// SpO2 calculation
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t bufferLength = 100;
int32_t spo2;
int8_t validSPO2;
int32_t heartRate;
int8_t validHeartRate;

// ═══════════════════════════════════════════════════════════
// Setup
// ═══════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("AnvayaPod Vital Signs Monitor");
  
  // Initialize I2C
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  
  // Initialize sensors
  if (!setupMAX30102()) {
    Serial.println("MAX30102 initialization failed!");
  }
  
  if (!mlx.begin()) {
    Serial.println("MLX90614 initialization failed!");
  }
  
  dht.begin();
  
  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  
  // Load thresholds from EEPROM/Flash
  loadThresholds();
  
  // Initialize reading struct
  memset(&currentReading, 0, sizeof(VitalReading));
  
  Serial.println("Setup complete. Starting monitoring...");
}

// ═══════════════════════════════════════════════════════════
// Main Loop
// ═══════════════════════════════════════════════════════════

void loop() {
  unsigned long now = millis();
  
  // Update vital signs (5 second interval)
  if (now - lastVitalUpdate >= VITAL_UPDATE_INTERVAL) {
    readHeartRateSpO2();
    readBodyTemperature();
    lastVitalUpdate = now;
  }
  
  // Update environment (30 second interval)
  if (now - lastEnvUpdate >= ENV_UPDATE_INTERVAL) {
    readEnvironment();
    lastEnvUpdate = now;
  }
  
  // Upload to cloud (5 second interval)
  if (now - lastUpload >= UPLOAD_INTERVAL) {
    uploadVitals();
    lastUpload = now;
  }
  
  // Check for device commands
  checkDeviceCommands();
  
  delay(20);  // Small delay to prevent watchdog issues
}

// ═══════════════════════════════════════════════════════════
// MAX30102 Setup
// ═══════════════════════════════════════════════════════════

bool setupMAX30102() {
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    return false;
  }
  
  byte ledBrightness = 60;    // 0-255
  byte sampleAverage = 4;     // 1, 2, 4, 8, 16, 32
  byte ledMode = 2;           // 1=Red only, 2=Red+IR, 3=Red+IR+Green
  byte sampleRate = 100;      // 50, 100, 200, 400, 800, 1000, 1600, 3200
  int pulseWidth = 411;       // 69, 118, 215, 411
  int adcRange = 4096;        // 2048, 4096, 8192, 16384
  
  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeIR(0x0A);
  
  return true;
}

// ═══════════════════════════════════════════════════════════
// Heart Rate & SpO2 Reading
// ═══════════════════════════════════════════════════════════

void readHeartRateSpO2() {
  // Read IR and Red LED values
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  
  // Check if finger is present
  if (irValue < 50000) {
    currentReading.heartRate = 0;
    currentReading.spO2 = 0;
    currentReading.heartRateQuality = 0;
    Serial.println("No finger detected");
    return;
  }
  
  // Heart rate detection using peak detection
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    beatsPerMinute = 60 / (delta / 1000.0);
    
    // Filter unrealistic values
    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      
      // Calculate average
      beatAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        beatAvg += rates[x];
      }
      beatAvg /= RATE_SIZE;
      
      currentReading.heartRate = beatAvg;
      currentReading.heartRateQuality = 90;  // Good signal
    }
  }
  
  // SpO2 calculation (simplified - real algorithm is more complex)
  // Full implementation requires buffering and FFT analysis
  float ratio = (float)redValue / (float)irValue;
  
  // Empirical formula (device-specific calibration needed)
  int spo2Value = (int)(110.0 - 25.0 * ratio);
  
  // Clamp to valid range
  if (spo2Value > 100) spo2Value = 100;
  if (spo2Value < 70) spo2Value = 70;
  
  currentReading.spO2 = spo2Value;
  
  Serial.printf("HR: %d BPM, SpO2: %d%%\n", currentReading.heartRate, currentReading.spO2);
}

// ═══════════════════════════════════════════════════════════
// Temperature Reading
// ═══════════════════════════════════════════════════════════

void readBodyTemperature() {
  // Read object temperature (baby's forehead)
  float objTemp = mlx.readObjectTempC();
  
  // Read ambient temperature
  float ambTemp = mlx.readAmbientTempC();
  
  // Validate reading
  if (objTemp > 30.0 && objTemp < 45.0) {
    currentReading.bodyTemp = objTemp;
  } else {
    Serial.println("Invalid body temp reading");
  }
  
  Serial.printf("Body: %.1f°C, Ambient: %.1f°C\n", objTemp, ambTemp);
}

// ═══════════════════════════════════════════════════════════
// Breath Rate Reading
// ═══════════════════════════════════════════════════════════

void readBreathRate() {
  // Read analog pressure sensor
  int sensorValue = analogRead(BREATH_SENSOR_PIN);
  
  // Convert to breath rate using peak detection algorithm
  // This is a simplified version - production needs filtering
  static int breathCount = 0;
  static unsigned long breathWindow = 0;
  static int lastValue = 0;
  static bool inBreath = false;
  
  // Detect rising edge (inhalation)
  if (sensorValue > lastValue + 50 && !inBreath) {
    breathCount++;
    inBreath = true;
  } else if (sensorValue < lastValue - 50) {
    inBreath = false;
  }
  
  lastValue = sensorValue;
  
  // Calculate BPM over 10 second window
  if (millis() - breathWindow >= 10000) {
    int breathBPM = breathCount * 6;  // (breaths / 10s) * 60
    
    if (breathBPM >= 10 && breathBPM <= 100) {
      currentReading.breathRate = breathBPM;
      currentReading.breathQuality = 80;
    }
    
    breathCount = 0;
    breathWindow = millis();
    
    Serial.printf("Breath Rate: %d BPM\n", breathBPM);
  }
}

// ═══════════════════════════════════════════════════════════
// Environment Reading
// ═══════════════════════════════════════════════════════════

void readEnvironment() {
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  
  if (!isnan(temp) && !isnan(hum)) {
    currentReading.envTemp = temp;
    currentReading.humidity = (uint8_t)hum;
    
    Serial.printf("Env: %.1f°C, %d%% RH\n", temp, (int)hum);
  } else {
    Serial.println("DHT22 read failed");
  }
}

// ═══════════════════════════════════════════════════════════
// Upload Vitals to Cloud
// ═══════════════════════════════════════════════════════════

void uploadVitals() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected");
    return;
  }
  
  // Update metadata
  currentReading.timestamp = millis();
  currentReading.batteryLevel = getBatteryLevel();
  currentReading.wifiSignal = WiFi.RSSI();
  currentReading.crc32 = calculateCRC32(&currentReading);
  
  // Build JSON
  StaticJsonDocument<512> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["babyId"] = BABY_ID;
  doc["timestamp"] = currentReading.timestamp;
  doc["heartRate"] = currentReading.heartRate;
  doc["spO2"] = currentReading.spO2;
  doc["heartRateQuality"] = currentReading.heartRateQuality;
  doc["bodyTemp"] = currentReading.bodyTemp;
  doc["envTemp"] = currentReading.envTemp;
  doc["humidity"] = currentReading.humidity;
  doc["motionLevel"] = currentReading.motionLevel;
  doc["isAsleep"] = currentReading.isAsleep;
  doc["batteryLevel"] = currentReading.batteryLevel;
  doc["wifiSignal"] = currentReading.wifiSignal;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  // HTTP POST
  HTTPClient http;
  http.begin(CLOUD_FUNCTION_URL);
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.POST(jsonString);
  
  if (httpCode == 200) {
    String response = http.getString();
    Serial.println("✓ Upload success");
    
    // Parse response for alerts
    StaticJsonDocument<256> respDoc;
    deserializeJson(respDoc, response);
    
    bool hasAlert = respDoc["hasAlert"] | false;
    if (hasAlert) {
      String alertType = respDoc["alertType"] | "unknown";
      Serial.printf("🚨 ALERT: %s\n", alertType.c_str());
      triggerLocalAlarm();
    }
  } else {
    Serial.printf("✗ Upload failed: %d\n", httpCode);
  }
  
  http.end();
}

// ═══════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════

uint8_t getBatteryLevel() {
  // Read battery voltage from ADC (if battery powered)
  // For USB powered, return 100
  return 100;
}

void triggerLocalAlarm() {
  // Blink LED rapidly
  for (int i = 0; i < 10; i++) {
    digitalWrite(STATUS_LED_PIN, HIGH);
    delay(100);
    digitalWrite(STATUS_LED_PIN, LOW);
    delay(100);
  }
  
  // Could also trigger buzzer/sound here
}

void checkDeviceCommands() {
  // Poll for commands from Firebase
  // e.g., update thresholds, start/stop monitoring
  // Implementation similar to photo/video command polling
}

void loadThresholds() {
  // Load from EEPROM/Flash or use defaults
  thresholds.hrMin = 80;
  thresholds.hrMax = 220;
  thresholds.spO2Min = 92;
  thresholds.bodyTempMin = 36.5;
  thresholds.bodyTempMax = 38.0;
  thresholds.envTempMin = 18.0;
  thresholds.envTempMax = 26.0;
  thresholds.humidityMin = 30;
  thresholds.humidityMax = 60;
}

uint32_t calculateCRC32(void* data) {
  // CRC32 implementation
  // ...
  return 0xDEADBEEF;  // Placeholder
}
```

---

## 5️⃣ CLOUD FUNCTIONS

### **5.1 Submit Vitals Endpoint**

```typescript
// ═══════════════════════════════════════════════════════════
// functions/src/submitVitals.ts
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface VitalData {
  deviceId: string;
  babyId: string;
  timestamp: number;
  heartRate: number;
  spO2: number;
  heartRateQuality: number;
  bodyTemp: number;
  envTemp: number;
  humidity: number;
  breathRate: number;
  breathQuality: number;
  motionLevel: number;
  isAsleep: boolean;
  batteryLevel: number;
  wifiSignal: number;
}

interface VitalThresholds {
  hrMin: number;
  hrMax: number;
  spO2Min: number;
  bodyTempMin: number;
  bodyTempMax: number;
  envTempMin: number;
  envTempMax: number;
  breathRateMin: number;
  breathRateMax: number;
  humidityMin: number;
  humidityMax: number;
}

const DEFAULT_THRESHOLDS: VitalThresholds = {
  hrMin: 80,
  hrMax: 220,
  spO2Min: 92,
  bodyTempMin: 36.5,
  bodyTempMax: 38.0,
  envTempMin: 18.0,
  envTempMax: 26.0,
  breathRateMin: 20,
  breathRateMax: 60,
  humidityMin: 30,
  humidityMax: 60,
};

export const submitVitals = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    
    // CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      return res.status(204).send('');
    }
    
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }
    
    try {
      const vitalData: VitalData = req.body;
      
      // Validate
      if (!vitalData.deviceId || !vitalData.babyId) {
        return res.status(400).json({ error: 'Missing deviceId or babyId' });
      }
      
      console.log(`[submitVitals] Device: ${vitalData.deviceId}, Baby: ${vitalData.babyId}`);
      
      // Get baby-specific thresholds
      const thresholds = await getThresholds(vitalData.babyId);
      
      // Check for alerts
      const alerts = checkAlerts(vitalData, thresholds);
      
      // Save to Firestore
      await saveVitalReading(vitalData);
      
      // Update hourly aggregates
      await updateHourlyStats(vitalData);
      
      // Trigger alerts if needed
      if (alerts.length > 0) {
        await triggerAlerts(vitalData, alerts);
      }
      
      // Return response
      return res.status(200).json({
        success: true,
        hasAlert: alerts.length > 0,
        alertType: alerts.length > 0 ? alerts[0].type : null,
        alerts: alerts,
      });
      
    } catch (error) {
      console.error('[submitVitals] Error:', error);
      return res.status(500).json({ error: error.message });
    }
  });

// ═══════════════════════════════════════════════════════════
// Save Vital Reading
// ═══════════════════════════════════════════════════════════

async function saveVitalReading(data: VitalData): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 24 * 60 * 60 * 1000  // 24 hours
  );
  
  await db
    .collection('devices')
    .doc(data.deviceId)
    .collection('vitalReadings')
    .add({
      ...data,
      timestamp: admin.firestore.Timestamp.fromMillis(data.timestamp),
      createdAt: now,
      expiresAt: expiresAt,
    });
  
  console.log(`[saveVitalReading] Saved for device ${data.deviceId}`);
}

// ═══════════════════════════════════════════════════════════
// Check Alerts
// ═══════════════════════════════════════════════════════════

interface Alert {
  type: string;
  severity: 'info' | 'warning' | 'critical';
  value: number;
  threshold: number;
  unit: string;
  message: string;
}

function checkAlerts(data: VitalData, thresholds: VitalThresholds): Alert[] {
  const alerts: Alert[] = [];
  
  // SpO2 (CRITICAL)
  if (data.spO2 > 0 && data.spO2 < thresholds.spO2Min) {
    alerts.push({
      type: 'low_spo2',
      severity: 'critical',
      value: data.spO2,
      threshold: thresholds.spO2Min,
      unit: '%',
      message: `Low oxygen level: ${data.spO2}% (threshold: ${thresholds.spO2Min}%)`,
    });
  }
  
  // Body Temperature (CRITICAL if high)
  if (data.bodyTemp >= thresholds.bodyTempMax) {
    alerts.push({
      type: 'high_temp',
      severity: data.bodyTemp >= 38.5 ? 'critical' : 'warning',
      value: data.bodyTemp,
      threshold: thresholds.bodyTempMax,
      unit: '°C',
      message: `High temperature: ${data.bodyTemp}°C`,
    });
  } else if (data.bodyTemp > 0 && data.bodyTemp < thresholds.bodyTempMin) {
    alerts.push({
      type: 'low_temp',
      severity: 'warning',
      value: data.bodyTemp,
      threshold: thresholds.bodyTempMin,
      unit: '°C',
      message: `Low temperature: ${data.bodyTemp}°C`,
    });
  }
  
  // Heart Rate
  if (data.heartRate > 0) {
    if (data.heartRate > thresholds.hrMax) {
      alerts.push({
        type: 'high_heart_rate',
        severity: 'warning',
        value: data.heartRate,
        threshold: thresholds.hrMax,
        unit: ' BPM',
        message: `High heart rate: ${data.heartRate} BPM`,
      });
    } else if (data.heartRate < thresholds.hrMin) {
      alerts.push({
        type: 'low_heart_rate',
        severity: 'warning',
        value: data.heartRate,
        threshold: thresholds.hrMin,
        unit: ' BPM',
        message: `Low heart rate: ${data.heartRate} BPM`,
      });
    }
  }
  
  // Breath Rate
  if (data.breathRate > 0) {
    if (data.breathRate > thresholds.breathRateMax || data.breathRate < thresholds.breathRateMin) {
      alerts.push({
        type: 'abnormal_breathing',
        severity: 'warning',
        value: data.breathRate,
        threshold: data.breathRate > thresholds.breathRateMax ? thresholds.breathRateMax : thresholds.breathRateMin,
        unit: ' BPM',
        message: `Abnormal breathing: ${data.breathRate} BPM`,
      });
    }
  }
  
  // Environment Temperature
  if (data.envTemp > thresholds.envTempMax) {
    alerts.push({
      type: 'high_env_temp',
      severity: 'info',
      value: data.envTemp,
      threshold: thresholds.envTempMax,
      unit: '°C',
      message: `Room too warm: ${data.envTemp}°C`,
    });
  } else if (data.envTemp < thresholds.envTempMin) {
    alerts.push({
      type: 'low_env_temp',
      severity: 'info',
      value: data.envTemp,
      threshold: thresholds.envTempMin,
      unit: '°C',
      message: `Room too cold: ${data.envTemp}°C`,
    });
  }
  
  // Humidity
  if (data.humidity > thresholds.humidityMax) {
    alerts.push({
      type: 'high_humidity',
      severity: 'info',
      value: data.humidity,
      threshold: thresholds.humidityMax,
      unit: '%',
      message: `Humidity too high: ${data.humidity}%`,
    });
  } else if (data.humidity < thresholds.humidityMin) {
    alerts.push({
      type: 'low_humidity',
      severity: 'info',
      value: data.humidity,
      threshold: thresholds.humidityMin,
      unit: '%',
      message: `Humidity too low: ${data.humidity}%`,
    });
  }
  
  return alerts;
}

// ═══════════════════════════════════════════════════════════
// Trigger Alerts
// ═══════════════════════════════════════════════════════════

async function triggerAlerts(data: VitalData, alerts: Alert[]): Promise<void> {
  
  for (const alert of alerts) {
    // Save alert document
    await db
      .collection('babies')
      .doc(data.babyId)
      .collection('vitalAlerts')
      .add({
        babyId: data.babyId,
        deviceId: data.deviceId,
        alertType: alert.type,
        severity: alert.severity,
        value: alert.value,
        threshold: alert.threshold,
        unit: alert.unit,
        vitalReading: data,
        status: 'active',
        notificationSent: false,
        soundAlarmTriggered: false,
        triggeredAt: admin.firestore.Timestamp.now(),
        createdAt: admin.firestore.Timestamp.now(),
      });
    
    // Send push notification for critical alerts
    if (alert.severity === 'critical') {
      await sendAlertNotification(data.babyId, alert);
    }
    
    console.log(`[triggerAlerts] ${alert.type}: ${alert.message}`);
  }
}

// ═══════════════════════════════════════════════════════════
// Send Alert Notification
// ═══════════════════════════════════════════════════════════

async function sendAlertNotification(babyId: string, alert: Alert): Promise<void> {
  // Get baby document to find parent FCM tokens
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const familyMembers = babyDoc.data()?.familyMembers || [];
  
  const tokens: string[] = [];
  for (const userId of familyMembers) {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) tokens.push(fcmToken);
  }
  
  if (tokens.length === 0) return;
  
  // Send notification
  await admin.messaging().sendMulticast({
    tokens,
    notification: {
      title: `🚨 ${alert.type.replace(/_/g, ' ').toUpperCase()}`,
      body: alert.message,
    },
    data: {
      type: 'vital_alert',
      babyId,
      alertType: alert.type,
      severity: alert.severity,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'vital_alerts',
        priority: 'max',
        sound: 'alert_sound',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'alert_sound.caf',
          badge: 1,
        },
      },
    },
  });
}

// ═══════════════════════════════════════════════════════════
// Update Hourly Stats
// ═══════════════════════════════════════════════════════════

async function updateHourlyStats(data: VitalData): Promise<void> {
  const now = new Date();
  const date = now.toISOString().split('T')[0];  // YYYY-MM-DD
  const hour = now.getHours();
  
  const docId = `${date}_${hour.toString().padStart(2, '0')}`;
  const docRef = db
    .collection('babies')
    .doc(data.babyId)
    .collection('vitals')
    .doc('hourly')
    .collection('data')
    .doc(docId);
  
  // Use transaction to safely update stats
  await db.runTransaction(async (t) => {
    const doc = await t.get(docRef);
    
    if (!doc.exists) {
      // Initialize new hourly doc
      t.set(docRef, {
        babyId: data.babyId,
        date,
        hour,
        heartRate: {
          min: data.heartRate,
          max: data.heartRate,
          sum: data.heartRate,
          count: 1,
          avg: data.heartRate,
        },
        spO2: {
          min: data.spO2,
          max: data.spO2,
          sum: data.spO2,
          count: 1,
          avg: data.spO2,
          belowThresholdCount: data.spO2 < 92 ? 1 : 0,
        },
        bodyTemp: {
          min: data.bodyTemp,
          max: data.bodyTemp,
          sum: data.bodyTemp,
          count: 1,
          avg: data.bodyTemp,
        },
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
    } else {
      // Update existing stats
      const existing = doc.data()!;
      
      t.update(docRef, {
        'heartRate.min': Math.min(existing.heartRate.min, data.heartRate),
        'heartRate.max': Math.max(existing.heartRate.max, data.heartRate),
        'heartRate.sum': existing.heartRate.sum + data.heartRate,
        'heartRate.count': existing.heartRate.count + 1,
        'heartRate.avg': (existing.heartRate.sum + data.heartRate) / (existing.heartRate.count + 1),
        
        'spO2.min': Math.min(existing.spO2.min, data.spO2),
        'spO2.max': Math.max(existing.spO2.max, data.spO2),
        'spO2.sum': existing.spO2.sum + data.spO2,
        'spO2.count': existing.spO2.count + 1,
        'spO2.avg': (existing.spO2.sum + data.spO2) / (existing.spO2.count + 1),
        'spO2.belowThresholdCount': existing.spO2.belowThresholdCount + (data.spO2 < 92 ? 1 : 0),
        
        updatedAt: admin.firestore.Timestamp.now(),
      });
    }
  });
}

// ═══════════════════════════════════════════════════════════
// Get Thresholds
// ═══════════════════════════════════════════════════════════

async function getThresholds(babyId: string): Promise<VitalThresholds> {
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const customThresholds = babyDoc.data()?.vitalThresholds;
  
  return {
    ...DEFAULT_THRESHOLDS,
    ...customThresholds,
  };
}
```

---

## 6️⃣ FLUTTER IMPLEMENTATION

### **6.1 Vital Signs Service**

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/vital_signs_service.dart
// ═══════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vital_reading_model.dart';
import '../models/vital_alert_model.dart';

class VitalSignsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════
  // Real-time Streaming
  // ═══════════════════════════════════════════════════════════
  
  /// Stream latest vital reading for a device
  Stream<VitalReadingModel?> streamLatestVitals(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('vitalReadings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return VitalReadingModel.fromFirestore(snapshot.docs.first);
    });
  }
  
  /// Stream active vital alerts for a baby
  Stream<List<VitalAlertModel>> streamActiveAlerts(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitalAlerts')
        .where('status', isEqualTo: 'active')
        .orderBy('triggeredAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VitalAlertModel.fromFirestore(doc))
          .toList();
    });
  }
  
  // ═══════════════════════════════════════════════════════════
  // Historical Data
  // ═══════════════════════════════════════════════════════════
  
  /// Get vitals for a specific time range
  Future<List<VitalReadingModel>> getVitalsInRange(
    String deviceId,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('vitalReadings')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: false)
        .get();
    
    return snapshot.docs
        .map((doc) => VitalReadingModel.fromFirestore(doc))
        .toList();
  }
  
  /// Get hourly statistics for a specific hour
  Future<HourlyVitalStats?> getHourlyStats(
    String babyId,
    String date,
    int hour,
  ) async {
    final docId = '${date}_${hour.toString().padStart(2, '0')}';
    
    final doc = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitals')
        .doc('hourly')
        .collection('data')
        .doc(docId)
        .get();
    
    if (!doc.exists) return null;
    
    return HourlyVitalStats.fromFirestore(doc);
  }
  
  /// Get daily summary
  Future<DailyVitalSummary?> getDailySummary(
    String babyId,
    String date,
  ) async {
    final doc = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitals')
        .doc('daily')
        .collection('data')
        .doc(date)
        .get();
    
    if (!doc.exists) return null;
    
    return DailyVitalSummary.fromFirestore(doc);
  }
  
  // ═══════════════════════════════════════════════════════════
  // Alert Management
  // ═══════════════════════════════════════════════════════════
  
  /// Acknowledge an alert
  Future<void> acknowledgeAlert(String babyId, String alertId, String userId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitalAlerts')
        .doc(alertId)
        .update({
      'status': 'acknowledged',
      'acknowledgedBy': userId,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Resolve an alert
  Future<void> resolveAlert(String babyId, String alertId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitalAlerts')
        .doc(alertId)
        .update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Get alert history
  Future<List<VitalAlertModel>> getAlertHistory(
    String babyId, {
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitalAlerts')
        .orderBy('triggeredAt', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs
        .map((doc) => VitalAlertModel.fromFirestore(doc))
        .toList();
  }
  
  // ═══════════════════════════════════════════════════════════
  // Threshold Management
  // ═══════════════════════════════════════════════════════════
  
  /// Update vital thresholds for a baby
  Future<void> updateThresholds(
    String babyId,
    Map<String, dynamic> thresholds,
  ) async {
    await _firestore.collection('babies').doc(babyId).update({
      'vitalThresholds': thresholds,
    });
  }
  
  /// Get current thresholds
  Future<Map<String, dynamic>> getThresholds(String babyId) async {
    final doc = await _firestore.collection('babies').doc(babyId).get();
    return doc.data()?['vitalThresholds'] ?? {};
  }
}
```

---

## 7️⃣ REAL-TIME STREAMING

### **7.1 Vital Signs Dashboard Widget**

```dart
// ═══════════════════════════════════════════════════════════
// lib/widgets/vitals/vital_signs_dashboard.dart
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vital_reading_model.dart';
import '../../providers/device_provider.dart';
import '../../services/vital_signs_service.dart';

class VitalSignsDashboard extends StatelessWidget {
  final VitalSignsService _vitalService = VitalSignsService();
  
  @override
  Widget build(BuildContext context) {
    final deviceId = context.watch<DeviceProvider>().currentDevice?.id;
    
    if (deviceId == null) {
      return Center(child: Text('No device connected'));
    }
    
    return StreamBuilder<VitalReadingModel?>(
      stream: _vitalService.streamLatestVitals(deviceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final vital = snapshot.data;
        
        if (vital == null) {
          return Center(child: Text('No vital data available'));
        }
        
        return Column(
          children: [
            // Header
            _buildHeader(vital),
            
            SizedBox(height: 16),
            
            // Vital cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildVitalCard(
                    icon: Icons.favorite,
                    label: 'Heart Rate',
                    value: '${vital.heartRate}',
                    unit: 'BPM',
                    isNormal: vital.isHeartRateNormal,
                    color: Colors.red,
                  ),
                  _buildVitalCard(
                    icon: Icons.water_drop,
                    label: 'Oxygen',
                    value: '${vital.spO2}',
                    unit: '%',
                    isNormal: vital.isSpO2Normal,
                    color: Colors.blue,
                  ),
                  _buildVitalCard(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: '${vital.bodyTemp.toStringAsFixed(1)}',
                    unit: '°C',
                    isNormal: vital.isTempNormal,
                    color: Colors.orange,
                  ),
                  _buildVitalCard(
                    icon: Icons.air,
                    label: 'Breathing',
                    value: '${vital.breathRate}',
                    unit: 'BPM',
                    isNormal: vital.isBreathRateNormal,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
            
            // Environment
            _buildEnvironmentSection(vital),
          ],
        );
      },
    );
  }
  
  Widget _buildHeader(VitalReadingModel vital) {
    return Container(
      padding: EdgeInsets.all(16),
      color: vital.hasAnyAlert ? Colors.red.shade50 : Colors.green.shade50,
      child: Row(
        children: [
          Icon(
            vital.hasAnyAlert ? Icons.warning_amber : Icons.check_circle,
            color: vital.hasAnyAlert ? Colors.red : Colors.green,
            size: 32,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vital.hasAnyAlert ? 'Alert Detected' : 'All Normal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: vital.hasAnyAlert ? Colors.red : Colors.green,
                  ),
                ),
                if (vital.primaryAlert != null)
                  Text(
                    vital.primaryAlert!.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Text(
            '${DateTime.now().difference(vital.timestamp).inSeconds}s ago',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVitalCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required bool isNormal,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isNormal ? Colors.green : Colors.red,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? Colors.black : Colors.red,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnvironmentSection(VitalReadingModel vital) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildEnvStat('Room', '${vital.envTemp.toStringAsFixed(1)}°C'),
          _buildEnvStat('Humidity', '${vital.humidity}%'),
          _buildEnvStat('Battery', '${vital.batteryLevel}%'),
        ],
      ),
    );
  }
  
  Widget _buildEnvStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
```

---

## 8️⃣ ALERT SYSTEM

### **8.1 Alert Notification Handler**

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/vital_alert_handler.dart
// ═══════════════════════════════════════════════════════════

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/vital_alert_model.dart';

class VitalAlertHandler {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    
    // Create notification channels
    await _createNotificationChannels();
  }
  
  static Future<void> _createNotificationChannels() async {
    // Critical alerts channel
    const criticalChannel = AndroidNotificationChannel(
      'vital_alerts_critical',
      'Critical Vital Alerts',
      description: 'Critical health alerts requiring immediate attention',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert_critical'),
    );
    
    // Warning alerts channel
    const warningChannel = AndroidNotificationChannel(
      'vital_alerts_warning',
      'Warning Vital Alerts',
      description: 'Health warnings requiring attention',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert_warning'),
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(criticalChannel);
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(warningChannel);
  }
  
  static Future<void> handleRemoteNotification(RemoteMessage message) async {
    if (message.data['type'] == 'vital_alert') {
      final severity = message.data['severity'] as String;
      final alertType = message.data['alertType'] as String;
      
      await showLocalNotification(
        title: message.notification?.title ?? 'Vital Alert',
        body: message.notification?.body ?? '',
        severity: severity == 'critical' 
            ? VitalAlertSeverity.critical 
            : VitalAlertSeverity.warning,
        payload: alertType,
      );
    }
  }
  
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required VitalAlertSeverity severity,
    String? payload,
  }) async {
    final channelId = severity == VitalAlertSeverity.critical
        ? 'vital_alerts_critical'
        : 'vital_alerts_warning';
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          severity == VitalAlertSeverity.critical 
              ? 'Critical Vital Alerts' 
              : 'Warning Vital Alerts',
          importance: severity == VitalAlertSeverity.critical 
              ? Importance.max 
              : Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: severity == VitalAlertSeverity.critical 
              ? 'alert_critical.caf' 
              : 'alert_warning.caf',
        ),
      ),
      payload: payload,
    );
  }
}
```

---

## 9️⃣ IMPLEMENTATION ROADMAP

### **Phase 1: ESP32 Firmware (Week 1)**

- [ ] Setup MAX30102 library and test heart rate reading
- [ ] Setup MLX90614 for temperature reading
- [ ] Implement breath rate algorithm (pressure sensor)
- [ ] Test DHT22 environment readings
- [ ] Implement data upload to Cloud Function
- [ ] Add local LED alerts
- [ ] Test end-to-end flow

### **Phase 2: Cloud Functions (Week 1)**

- [ ] Create `submitVitals` endpoint
- [ ] Implement alert detection rules
- [ ] Add Firestore document creation
- [ ] Implement hourly aggregation
- [ ] Add FCM push notifications
- [ ] Test with sample data

### **Phase 3: Flutter UI (Week 2)**

- [ ] Create VitalReadingModel and VitalAlertModel
- [ ] Implement VitalSignsService
- [ ] Build real-time dashboard widget
- [ ] Create vital trend charts
- [ ] Implement alert management screen
- [ ] Add threshold configuration
- [ ] Test real-time streaming

### **Phase 4: Testing & Calibration (Week 2-3)**

- [ ] Calibrate sensors with medical-grade devices
- [ ] Test alert accuracy
- [ ] Validate data retention policies
- [ ] Load testing (100+ devices)
- [ ] Battery optimization
- [ ] User acceptance testing

---

## ✅ SUCCESS METRICS

- [ ] Heart Rate accuracy within ±5 BPM
- [ ] SpO2 accuracy within ±2%
- [ ] Temperature accuracy within ±0.5°C
- [ ] Alert latency <10 seconds
- [ ] Data upload success rate >99%
- [ ] 24-hour battery life (if battery powered)
- [ ] Real-time dashboard updates within 5 seconds

---

**Ready to implement!** Start with Phase 1 (ESP32 Firmware) to get sensor readings working. 🚀

