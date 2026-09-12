# 📡 60GHz mmWave Sensor Integration for Vital Signs

**Date:** February 2, 2026  
**Hardware:** Seeed Studio 60GHz mmWave Sensor (MR60BHA1 or similar)  
**Purpose:** Non-contact Heart Rate & Respiratory Rate Monitoring

---

## 🎯 SENSOR OVERVIEW

### **Key Features**
- **Non-contact monitoring**: Works through blankets, clothing, bedding
- **Dual vital signs**: Simultaneous heart rate + respiratory rate detection
- **High accuracy**: ±3 BPM (HR), ±2 BPM (RR)
- **Fast response**: <2 second detection time
- **Presence detection**: Automatically detects baby presence
- **Sleep monitoring**: Optimized for sleeping infants

### **Technical Specifications**

```
60GHz mmWave Sensor (Seeed Studio MR60BHA1)
├─ Frequency: 60-64 GHz FMCW radar
├─ Detection Range: 0.4-3 meters
├─ Detection Angle: ±60° horizontal, ±40° vertical
├─ Heart Rate Range: 60-240 BPM (±3 BPM accuracy)
├─ Respiratory Rate Range: 10-60 BPM (±2 BPM accuracy)
├─ Response Time: <2 seconds
├─ Update Rate: 0.5 Hz (every 2 seconds)
├─ Power: 100-150 mA @ 5V
├─ Communication: UART (115200 baud, 8N1)
└─ Protocol: Custom binary protocol with CRC
```

---

## 🔌 HARDWARE INTEGRATION

### **ESP32 Pin Connection**

```cpp
// 60GHz mmWave Sensor - UART
#define MMWAVE_RX_PIN 16  // ESP32 RX ← mmWave TX
#define MMWAVE_TX_PIN 17  // ESP32 TX → mmWave RX
#define MMWAVE_BAUD 115200

// Power & Reset
#define MMWAVE_POWER_PIN 25  // Optional power control
#define MMWAVE_RESET_PIN 26  // Optional reset control
```

### **Wiring Diagram**

```
ESP32-DevKit-C                    60GHz mmWave Sensor
┌────────────────┐                ┌─────────────────┐
│                │                │                 │
│  GPIO 16 (RX2) │ ────────────> │ TX (Yellow)     │
│  GPIO 17 (TX2) │ <──────────── │ RX (Green)      │
│  GND           │ ────────────> │ GND (Black)     │
│  5V            │ ────────────> │ VCC (Red)       │
│                │                │                 │
└────────────────┘                └─────────────────┘
```

### **Sensor Placement**

```
Optimal Installation:
├─ Mount above crib/bassinet (ceiling mount or stand)
├─ Height: 1-2 meters above baby
├─ Angle: Pointing downward at 30-45° toward chest
├─ Distance: 0.5-1.5 meters for best accuracy
└─ Avoid: Metal objects, fans, other radar sources

Detection Zone:
    Sensor
      ↓
     ╱ ╲
    ╱   ╲     ← 60° cone
   ╱     ╲
  ╱  Baby ╲
 ╱_________╲
  0.5-1.5m
```

---

## 📊 DATA PROTOCOL

### **UART Protocol Structure**

```cpp
// Frame Structure (Binary)
typedef struct {
  uint8_t  header[4];        // 0x53 0x59 0x83 0x09
  uint16_t length;           // Data length
  uint8_t  commandType;      // 0x80 = heartbeat data
  uint8_t  data[];           // Payload
  uint8_t  crc8;             // CRC checksum
  uint8_t  footer[4];        // 0x54 0x43 0x04 0x0A
} MMWaveFrame;

// Heartbeat Data Payload
typedef struct {
  uint8_t  presenceState;    // 0=None, 1=Stationary, 2=Active
  uint16_t heartRate;        // BPM (big-endian)
  uint16_t respiratoryRate;  // BPM (big-endian)
  uint8_t  heartRateQuality; // 0-100%
  uint8_t  respiratoryQuality; // 0-100%
  uint16_t distance;         // cm (big-endian)
} HeartbeatData;
```

### **Example Frame (Hex)**

```
Heart Rate: 120 BPM, Respiratory Rate: 35 BPM, Presence: Yes

53 59 83 09  // Header
00 0A        // Length: 10 bytes
80           // Command: Heartbeat
01           // Presence: Stationary
00 78        // HR: 120 BPM (0x0078)
00 23        // RR: 35 BPM (0x0023)
5A           // HR Quality: 90%
50           // RR Quality: 80%
00 64        // Distance: 100 cm
A3           // CRC8
54 43 04 0A  // Footer
```

---

## 💻 ESP32 FIRMWARE IMPLEMENTATION

### **Complete mmWave Sensor Driver**

```cpp
// ═══════════════════════════════════════════════════════════
// mmwave_sensor.h
// ═══════════════════════════════════════════════════════════

#ifndef MMWAVE_SENSOR_H
#define MMWAVE_SENSOR_H

#include <Arduino.h>

#define MMWAVE_RX_PIN 16
#define MMWAVE_TX_PIN 17
#define MMWAVE_BAUD 115200

#define MMWAVE_HEADER_0 0x53
#define MMWAVE_HEADER_1 0x59
#define MMWAVE_HEADER_2 0x83
#define MMWAVE_HEADER_3 0x09

#define MMWAVE_FOOTER_0 0x54
#define MMWAVE_FOOTER_1 0x43
#define MMWAVE_FOOTER_2 0x04
#define MMWAVE_FOOTER_3 0x0A

struct MMWaveVitals {
  bool     presenceDetected;
  uint16_t heartRate;          // BPM
  uint16_t respiratoryRate;    // BPM
  uint8_t  heartRateQuality;   // 0-100%
  uint8_t  respiratoryQuality; // 0-100%
  uint16_t distanceCm;         // Distance to subject
  uint32_t timestamp;
  bool     valid;
};

class MMWaveSensor {
private:
  HardwareSerial* serial;
  uint8_t rxBuffer[256];
  uint8_t rxIndex;
  MMWaveVitals currentVitals;
  
  bool parseFrame(uint8_t* data, uint16_t length);
  uint8_t calculateCRC(uint8_t* data, uint16_t length);
  bool validateFrame(uint8_t* frame, uint16_t length);
  
public:
  MMWaveSensor();
  void begin();
  bool update();  // Call frequently to process UART data
  MMWaveVitals getVitals();
  bool isPresent();
  void reset();
  void sendCommand(uint8_t* cmd, uint16_t length);
};

#endif

// ═══════════════════════════════════════════════════════════
// mmwave_sensor.cpp
// ═══════════════════════════════════════════════════════════

#include "mmwave_sensor.h"

MMWaveSensor::MMWaveSensor() {
  serial = &Serial2;  // Use UART2
  rxIndex = 0;
  memset(&currentVitals, 0, sizeof(MMWaveVitals));
}

void MMWaveSensor::begin() {
  serial->begin(MMWAVE_BAUD, SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);
  serial->setTimeout(10);
  
  delay(1000);  // Wait for sensor init
  
  Serial.println("mmWave sensor initialized");
}

bool MMWaveSensor::update() {
  // Read available UART data
  while (serial->available()) {
    uint8_t byte = serial->read();
    
    // Look for header sequence
    if (rxIndex == 0 && byte == MMWAVE_HEADER_0) {
      rxBuffer[rxIndex++] = byte;
    } else if (rxIndex == 1 && byte == MMWAVE_HEADER_1) {
      rxBuffer[rxIndex++] = byte;
    } else if (rxIndex == 2 && byte == MMWAVE_HEADER_2) {
      rxBuffer[rxIndex++] = byte;
    } else if (rxIndex == 3 && byte == MMWAVE_HEADER_3) {
      rxBuffer[rxIndex++] = byte;
    } else if (rxIndex >= 4 && rxIndex < 255) {
      rxBuffer[rxIndex++] = byte;
      
      // Check if we have complete frame
      if (rxIndex >= 6) {
        uint16_t length = (rxBuffer[4] << 8) | rxBuffer[5];
        uint16_t totalLength = 4 + 2 + 1 + length + 1 + 4;  // Header + Len + Cmd + Data + CRC + Footer
        
        if (rxIndex >= totalLength) {
          // Parse complete frame
          if (parseFrame(rxBuffer, rxIndex)) {
            rxIndex = 0;  // Reset for next frame
            return true;
          }
          rxIndex = 0;
        }
      }
    } else {
      rxIndex = 0;  // Invalid sequence, reset
    }
    
    // Prevent buffer overflow
    if (rxIndex >= 255) {
      rxIndex = 0;
    }
  }
  
  return false;
}

bool MMWaveSensor::parseFrame(uint8_t* data, uint16_t length) {
  // Validate frame
  if (!validateFrame(data, length)) {
    Serial.println("mmWave: Invalid frame CRC");
    return false;
  }
  
  uint8_t commandType = data[6];
  
  if (commandType == 0x80) {  // Heartbeat data
    uint8_t* payload = &data[7];
    
    currentVitals.presenceDetected = payload[0] > 0;
    currentVitals.heartRate = (payload[1] << 8) | payload[2];
    currentVitals.respiratoryRate = (payload[3] << 8) | payload[4];
    currentVitals.heartRateQuality = payload[5];
    currentVitals.respiratoryQuality = payload[6];
    currentVitals.distanceCm = (payload[7] << 8) | payload[8];
    currentVitals.timestamp = millis();
    currentVitals.valid = true;
    
    Serial.printf("mmWave: HR=%d BPM, RR=%d BPM, Presence=%d, Dist=%dcm\n",
                  currentVitals.heartRate,
                  currentVitals.respiratoryRate,
                  currentVitals.presenceDetected,
                  currentVitals.distanceCm);
    
    return true;
  }
  
  return false;
}

bool MMWaveSensor::validateFrame(uint8_t* frame, uint16_t length) {
  // Check header
  if (frame[0] != MMWAVE_HEADER_0 || frame[1] != MMWAVE_HEADER_1 ||
      frame[2] != MMWAVE_HEADER_2 || frame[3] != MMWAVE_HEADER_3) {
    return false;
  }
  
  // Check footer
  if (frame[length-4] != MMWAVE_FOOTER_0 || frame[length-3] != MMWAVE_FOOTER_1 ||
      frame[length-2] != MMWAVE_FOOTER_2 || frame[length-1] != MMWAVE_FOOTER_3) {
    return false;
  }
  
  // Calculate CRC
  uint8_t crc = calculateCRC(frame + 4, length - 4 - 1 - 4);
  uint8_t frameCRC = frame[length - 5];
  
  return crc == frameCRC;
}

uint8_t MMWaveSensor::calculateCRC(uint8_t* data, uint16_t length) {
  uint8_t crc = 0x00;
  for (uint16_t i = 0; i < length; i++) {
    crc ^= data[i];
  }
  return crc;
}

MMWaveVitals MMWaveSensor::getVitals() {
  // Mark as invalid if data is too old (>5 seconds)
  if (currentVitals.valid && (millis() - currentVitals.timestamp) > 5000) {
    currentVitals.valid = false;
  }
  return currentVitals;
}

bool MMWaveSensor::isPresent() {
  MMWaveVitals vitals = getVitals();
  return vitals.valid && vitals.presenceDetected;
}

void MMWaveSensor::reset() {
  // Send reset command (if supported by sensor)
  uint8_t resetCmd[] = {0x53, 0x59, 0x01, 0x02, 0x00, 0x01, 0x0F, 0xBF, 0x54, 0x43};
  sendCommand(resetCmd, sizeof(resetCmd));
}

void MMWaveSensor::sendCommand(uint8_t* cmd, uint16_t length) {
  serial->write(cmd, length);
}
```

### **Integration with Main Firmware**

```cpp
// ═══════════════════════════════════════════════════════════
// main.cpp - Integration
// ═══════════════════════════════════════════════════════════

#include "mmwave_sensor.h"

MMWaveSensor mmWave;
VitalReading currentReading;

void setup() {
  Serial.begin(115200);
  
  // Initialize mmWave sensor
  mmWave.begin();
  
  // ... other sensor initialization
}

void loop() {
  unsigned long now = millis();
  
  // Update mmWave sensor (call frequently)
  if (mmWave.update()) {
    // New data available
    MMWaveVitals vitals = mmWave.getVitals();
    
    if (vitals.valid) {
      currentReading.heartRate = vitals.heartRate;
      currentReading.respiratoryRate = vitals.respiratoryRate;
      currentReading.heartRateQuality = vitals.heartRateQuality;
      currentReading.respiratoryQuality = vitals.respiratoryQuality;
      currentReading.presenceDetected = vitals.presenceDetected;
      currentReading.distanceCm = vitals.distanceCm;
    }
  }
  
  // Read other sensors at their intervals
  if (now - lastVitalUpdate >= VITAL_UPDATE_INTERVAL) {
    readSpO2();  // MAX30102
    readBodyTemperature();  // MLX90614
    lastVitalUpdate = now;
  }
  
  if (now - lastEnvUpdate >= ENV_UPDATE_INTERVAL) {
    readEnvironment();  // DHT22
    lastEnvUpdate = now;
  }
  
  // Upload to cloud
  if (now - lastUpload >= UPLOAD_INTERVAL) {
    uploadVitals();
    lastUpload = now;
  }
}
```

---

## 🔄 UPDATED DATA MODELS

### **ESP32 Struct**

```cpp
struct VitalReading {
  uint32_t timestamp;
  
  // Cardiovascular (mmWave primary, MAX30102 backup)
  uint16_t heartRate;           // BPM (from mmWave)
  uint8_t  heartRateQuality;    // Signal quality (0-100)
  
  // Respiratory (mmWave)
  uint16_t respiratoryRate;     // BPM
  uint8_t  respiratoryQuality;  // Signal quality (0-100)
  
  // Oxygen saturation (MAX30102)
  uint8_t  spO2;                // Percentage (0-100)
  uint8_t  spO2Quality;         // Signal quality
  
  // Temperature (MLX90614 + DHT22)
  float    bodyTemp;            // Celsius
  float    envTemp;             // Celsius
  uint8_t  humidity;            // Percentage
  
  // Presence & Distance (mmWave)
  bool     presenceDetected;    // Baby detected
  uint16_t distanceCm;          // Distance to baby
  
  // Device status
  uint8_t  batteryLevel;
  uint8_t  wifiSignal;
  uint32_t crc32;
};
```

### **Firestore Document**

```typescript
interface VitalReadingDocument {
  deviceId: string;
  babyId: string;
  timestamp: FirebaseFirestore.Timestamp;
  
  // Cardiovascular (mmWave)
  heartRate: number;            // BPM
  heartRateQuality: number;     // 0-100
  heartRateSource: 'mmwave';    // Always mmWave
  
  // Respiratory (mmWave)
  respiratoryRate: number;      // BPM
  respiratoryQuality: number;   // 0-100
  
  // Oxygen (MAX30102)
  spO2: number;                 // Percentage
  spO2Quality: number;          // 0-100
  
  // Temperature
  bodyTemp: number;             // Celsius
  envTemp: number;              // Celsius
  humidity: number;             // Percentage
  
  // Presence detection
  presenceDetected: boolean;    // mmWave presence
  distanceCm: number;           // Distance to baby
  
  // Metadata
  batteryLevel: number;
  wifiSignal: number;
  createdAt: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp;
}
```

### **Flutter Model**

```dart
class VitalReadingModel {
  final String id;
  final String deviceId;
  final String babyId;
  final DateTime timestamp;
  
  // Cardiovascular
  final int heartRate;
  final int heartRateQuality;
  
  // Respiratory
  final int respiratoryRate;
  final int respiratoryQuality;
  
  // Oxygen
  final int spO2;
  final int spO2Quality;
  
  // Temperature
  final double bodyTemp;
  final double envTemp;
  final int humidity;
  
  // Presence
  final bool presenceDetected;
  final int distanceCm;
  
  // Health status
  bool get isHeartRateNormal => heartRate >= 80 && heartRate <= 220;
  bool get isRespiratoryNormal => respiratoryRate >= 20 && respiratoryRate <= 60;
  bool get isSpO2Normal => spO2 >= 92;
  bool get isTempNormal => bodyTemp >= 36.5 && bodyTemp <= 38.0;
  
  bool get hasAnyAlert => !isHeartRateNormal || !isRespiratoryNormal || 
                          !isSpO2Normal || !isTempNormal;
}
```

---

## 🚨 ENHANCED ALERT RULES

### **Respiratory Alerts (New)**

```typescript
// Apnea Detection (No breathing detected)
if (data.respiratoryRate < 5 && data.respiratoryQuality > 50) {
  await createCriticalAlert('apnea', 
    'No breathing detected', 
    'Immediate medical attention required');
}

// Bradypnea (Slow breathing)
if (data.respiratoryRate < 20 && data.respiratoryRate >= 5) {
  await createWarningAlert('bradypnea',
    `Slow breathing: ${data.respiratoryRate} BPM`,
    'Monitor closely');
}

// Tachypnea (Fast breathing)
if (data.respiratoryRate > 60) {
  await createWarningAlert('tachypnea',
    `Fast breathing: ${data.respiratoryRate} BPM`,
    'May indicate distress');
}

// Irregular breathing pattern
if (data.respiratoryQuality < 30) {
  await createInfoAlert('irregular_breathing',
    'Irregular breathing pattern detected',
    'May be normal during active sleep');
}
```

---

## 📈 ADVANTAGES OF mmWave SENSOR

### **vs. Contact Sensors (Wearables)**
✅ **No skin contact** - More comfortable for baby  
✅ **No batteries to charge** - Always powered  
✅ **No electrodes** - No skin irritation  
✅ **Works through clothing** - No need to undress baby  
✅ **Multi-parameter** - Heart + respiratory in one sensor  

### **vs. Camera-based (Optical)**
✅ **Works in darkness** - No lighting needed  
✅ **Privacy-preserving** - No video recording  
✅ **Works through blankets** - Not affected by covering  
✅ **No occlusion issues** - Penetrates obstacles  
✅ **Lower processing** - Simple UART data vs video analysis  

### **vs. Pressure Mats**
✅ **Non-contact** - Baby can move freely  
✅ **Dual vitals** - Heart + breathing (mat only detects breathing)  
✅ **Better accuracy** - ±2-3 BPM vs ±5-10 BPM  
✅ **Faster response** - 2s vs 10-30s averaging  

---

## ⚠️ LIMITATIONS & CONSIDERATIONS

### **Environmental Factors**
- **Metal interference**: Avoid near metal cribs/beds
- **Movement**: May lose tracking if baby moves significantly
- **Multiple subjects**: Can only track one person at a time
- **Distance**: Accuracy decreases beyond 1.5 meters

### **Calibration**
- **Initial setup**: 1-2 minutes warmup after power-on
- **Per-baby calibration**: May need offset adjustment for very small infants
- **Periodic verification**: Compare with medical-grade device monthly

### **Regulatory**
- **NOT a medical device**: For monitoring only, not diagnosis
- **Backup monitoring**: Should not replace direct observation
- **Emergency response**: Parents still responsible for medical decisions

---

## 🎯 IMPLEMENTATION CHECKLIST

- [✅] Hardware: 60GHz mmWave sensor selected
- [✅] Documentation: Integration guide created
- [ ] Firmware: mmWave driver implementation
- [ ] Testing: Verify heart rate accuracy (±3 BPM)
- [ ] Testing: Verify respiratory accuracy (±2 BPM)
- [ ] Calibration: Test at 0.5m, 1.0m, 1.5m distances
- [ ] Cloud: Update data models for respiratory rate
- [ ] Flutter: Add respiratory rate to dashboard
- [ ] Alerts: Implement apnea detection
- [ ] Alerts: Implement bradypnea/tachypnea warnings
- [ ] Testing: 24-hour continuous monitoring test
- [ ] Testing: Movement/blanket interference test
- [ ] Documentation: User placement guide
- [ ] Validation: Compare with medical pulse oximeter

---

**Ready to implement!** The mmWave sensor provides superior non-contact vital signs monitoring. 📡

