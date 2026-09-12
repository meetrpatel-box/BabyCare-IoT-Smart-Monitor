# 📋 Vital Signs Monitoring - Updated Architecture Summary

**Date:** February 2, 2026  
**Status:** Updated with 60GHz mmWave Sensor

---

## 🎯 SENSOR CONFIGURATION (UPDATED)

### **Hardware Stack**

| Component | Model | Purpose | Communication | Update Rate | Status |
|-----------|-------|---------|---------------|-------------|--------|
| **60GHz mmWave** | Seeed Studio MR60BHA1 | **Heart Rate + Respiratory Rate** | UART (115200) | 2 seconds | ✅ Available |
| **MLX90614** | IR Thermometer | **Body Temperature** | I2C (0x5A) | 10 seconds | ✅ Available |
| **DHT22** | Temp + Humidity | **Environment Monitoring** | Digital | 30 seconds | ✅ Available |
| **ESP32** | DevKit-C | **Main Controller** | WiFi | - | ✅ Available |
| **MAX30102** | Pulse Oximeter | **SpO2 (Oxygen)** ⚠️ | I2C (0x57) | 5 seconds | ❌ **Need to Order** |

---

## 🔄 KEY CHANGES FROM PREVIOUS DESIGN

### **What Changed**

| Before | After | Reason |
|--------|-------|--------|
| MAX30102 for HR | **60GHz mmWave for HR** | Non-contact, works through blankets |
| No respiratory sensor | **60GHz mmWave for RR** | Critical vital sign added |
| Contact-based | **Non-contact monitoring** | More comfortable for baby |
| Pressure/motion sensor | **Radar technology** | Higher accuracy, faster response |

### **What Stayed the Same**

✅ MAX30102 still used for **SpO2** (blood oxygen)  
✅ MLX90614 still used for **body temperature**  
✅ DHT22 still used for **environment monitoring**  
✅ ESP32 main controller  
✅ Firebase Cloud Functions for alerts  
✅ Flutter app dashboard  

---

## 📊 MONITORED VITAL SIGNS

### **Phase 1: Current Hardware (Available Now)**

| # | Vital Sign | Sensor | Normal Range | Critical Threshold | Status |
|---|------------|--------|--------------|-------------------|--------|
| 1️⃣ | **Heart Rate** | mmWave | 100-160 BPM | <80 or >220 BPM | ✅ Ready |
| 2️⃣ | **Respiratory Rate** | mmWave | 30-50 BPM | <20 or >60 BPM | ✅ Ready |
| 3️⃣ | **Body Temperature** | MLX90614 | 36.5-37.5°C | <36°C or >38°C | ✅ Ready |
| 4️⃣ | **Env. Temperature** | DHT22 | 18-24°C | <16°C or >28°C | ✅ Ready |
| 5️⃣ | **Humidity** | DHT22 | 40-60% | <30% or >70% | ✅ Ready |

### **Phase 2: After MAX30102 Purchase**

| # | Vital Sign | Sensor | Normal Range | Critical Threshold | Status |
|---|------------|--------|--------------|-------------------|--------|
| 6️⃣ | **SpO2 (Oxygen)** | MAX30102 | 95-100% | <92% | ⚠️ **Hardware Needed** |

**Note:** SpO2 monitoring requires purchasing MAX30102 sensor (~$8-10). Until then, we monitor 5 vital parameters.

---

## 🚨 NEW ALERT TYPES

### **Respiratory Alerts (Critical)**

```
🚨 APNEA (No Breathing)
   Respiratory Rate < 5 BPM for >10 seconds
   → Immediate alert to all family members
   → Sound alarm on device
   → SMS backup notification

⚠️  BRADYPNEA (Slow Breathing)
   Respiratory Rate 5-19 BPM
   → Warning notification
   → Monitor for apnea

⚠️  TACHYPNEA (Fast Breathing)
   Respiratory Rate > 60 BPM
   → Warning notification
   → May indicate fever or distress

ℹ️  IRREGULAR PATTERN
   Respiratory Quality < 30%
   → Info alert (may be normal during active sleep)
```

---

## 💻 TECHNICAL IMPLEMENTATION

### **ESP32 Firmware Updates**

```cpp
// New Dependencies
#include "mmwave_sensor.h"  // 60GHz mmWave driver

// Sensor Instances
MMWaveSensor mmWave;
Adafruit_MLX90614 mlx;
DHT dht(DHT22_PIN, DHT22);
// MAX30102 pulseOx;  // TODO: Add after hardware arrives

// Main Loop
void loop() {
  // mmWave: Heart Rate + Respiratory (every 2s)
  if (mmWave.update()) {
    vitals.heartRate = mmWave.getVitals().heartRate;
    vitals.respiratoryRate = mmWave.getVitals().respiratoryRate;
    vitals.presenceDetected = mmWave.getVitals().presenceDetected;
  }
  
  // MLX90614: Body temperature (every 10s)
  if (shouldReadTemp()) {
    vitals.bodyTemp = mlx.readObjectTempC();
  }
  
  // DHT22: Environment (every 30s)
  if (shouldReadEnv()) {
    vitals.envTemp = dht.readTemperature();
    vitals.humidity = dht.readHumidity();
  }
  
  // TODO: Add MAX30102 SpO2 reading when hardware available
  // if (shouldReadSpO2()) {
  //   vitals.spO2 = pulseOx.getSpO2();
  // }
  
  // Upload to cloud
  if (shouldUpload()) {
    uploadVitals();
  }
}
```

### **Cloud Functions Updates**

```typescript
// New Alert Rules
export const checkRespiratoryAlerts = functions.firestore
  .document('devices/{deviceId}/vitalReadings/{readingId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Apnea detection (CRITICAL)
    if (data.respiratoryRate < 5) {
      await createCriticalAlert({
        type: 'apnea',
        severity: 'critical',
        message: 'No breathing detected - Check baby immediately!',
        notifyAll: true,
        soundAlarm: true,
        sendSMS: true,
      });
    }
    
    // Bradypnea (WARNING)
    if (data.respiratoryRate >= 5 && data.respiratoryRate < 20) {
      await createWarningAlert({
        type: 'bradypnea',
        message: `Slow breathing: ${data.respiratoryRate} BPM`,
      });
    }
    
    // Tachypnea (WARNING)
    if (data.respiratoryRate > 60) {
      await createWarningAlert({
        type: 'tachypnea',
        message: `Fast breathing: ${data.respiratoryRate} BPM`,
      });
    }
  });
```

### **Flutter UI Updates**

```dart
// Dashboard Widget
class VitalsDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: Heart Rate + Respiratory Rate (mmWave)
        Row(
          children: [
            VitalCard(
              icon: Icons.favorite,
              label: 'Heart Rate',
              value: '${vitals.heartRate}',
              unit: 'BPM',
              color: Colors.red,
              source: 'mmWave',
            ),
            VitalCard(
              icon: Icons.air,  // NEW
              label: 'Breathing',  // NEW
              value: '${vitals.respiratoryRate}',  // NEW
              unit: 'BPM',
              color: Colors.blue,
              source: 'mmWave',
            ),
          ],
        ),
        
        // Row 2: SpO2 + Temperature
        Row(
          children: [
            VitalCard(
              icon: Icons.opacity,
              label: 'SpO2',
              value: '${vitals.spO2}',
              unit: '%',
              color: Colors.purple,
              source: 'MAX30102',
            ),
            VitalCard(
              icon: Icons.thermostat,
              label: 'Body Temp',
              value: '${vitals.bodyTemp.toStringAsFixed(1)}',
              unit: '°C',
              color: Colors.orange,
              source: 'MLX90614',
            ),
          ],
        ),
        
        // Row 3: Environment (DHT22)
        EnvironmentCard(
          temp: vitals.envTemp,
          humidity: vitals.humidity,
        ),
      ],
    );
  }
}
```

---

## 📁 DOCUMENTATION FILES

| File | Purpose | Location | Status |
|------|---------|----------|--------|
| **HARDWARE_SENSORS_SPECIFICATION.md** | Complete hardware specs & SpO2 alternatives | `docs/03-specifications/device/` | ✅ Created |
| **MMWAVE_SENSOR_INTEGRATION.md** | Complete mmWave integration guide | `docs/08-implementation/` | ✅ Created |
| **VITAL_SIGNS_ARCHITECTURE_SUMMARY.md** | This summary | `docs/08-implementation/` | ✅ Created |
| **FEEDING_TRACKING_LLD.md** | Feeding tracking LLD | `docs/08-implementation/` | ✅ Created |
| **DIAPER_TRACKING_LLD.md** | Diaper tracking LLD | `docs/08-implementation/` | ✅ Created |
| **GROWTH_TRACKING_LLD.md** | Growth tracking LLD | `docs/08-implementation/` | ✅ Created |
| **VACCINE_TRACKING_LLD.md** | Vaccine tracking LLD | `docs/08-implementation/` | ✅ Created |

---

## ✅ NEXT STEPS

### **Phase 1: Hardware Testing (Week 1) - Current Sensors**
- [✅] 60GHz mmWave sensor available
- [ ] Test mmWave UART communication
- [ ] Verify heart rate accuracy (compare with medical pulse ox)
- [ ] Verify respiratory rate accuracy (visual counting)
- [ ] Test detection range (0.5m, 1.0m, 1.5m)
- [ ] Test through blankets/clothing
- [ ] Test MLX90614 temperature accuracy
- [ ] Test DHT22 environment readings

### **Phase 1.5: Order Missing Hardware**
- [ ] **Order MAX30102 pulse oximeter** (~$8-10)
- [ ] Wait for delivery (1-2 weeks)
- [ ] Alternative: Continue MVP without SpO2

### **Phase 2: Firmware Development (Week 1-2)**
- [ ] Implement mmWave driver (UART protocol)
- [ ] Integrate MLX90614 temperature reading
- [ ] Integrate DHT22 environment reading
- [ ] Add respiratory rate data to upload payload
- [ ] Test continuous operation (24 hours)
- [ ] Optimize power consumption
- [ ] Add error handling for sensor failures

### **Phase 2.5: Add SpO2 (After Hardware Arrives)**
- [ ] Integrate MAX30102 sensor
- [ ] Test SpO2 accuracy
- [ ] Update firmware with SpO2 reading
- [ ] Update upload payload

### **Phase 3: Cloud & Alerts (Week 2)**
- [ ] Update Firestore data models
- [ ] Add respiratory rate to Cloud Functions
- [ ] Implement apnea detection algorithm
- [ ] Add bradypnea/tachypnea alerts
- [ ] Test FCM push notifications
- [ ] Add SMS backup for critical alerts
- [ ] (Later) Add SpO2 alerts when hardware available

### **Phase 4: Flutter App (Week 3)**
- [ ] Update VitalReadingModel with respiratory fields
- [ ] Add respiratory rate card to dashboard
- [ ] Create respiratory trend chart
- [ ] Add respiratory alert UI
- [ ] Test real-time streaming
- [ ] Add historical respiratory data view
- [ ] (Later) Add SpO2 display when hardware available

### **Phase 5: Testing & Validation (Week 4)**
- [ ] 7-day continuous monitoring test
- [ ] Accuracy validation vs medical devices
- [ ] Alert response time testing
- [ ] Battery life testing (if battery-powered)
- [ ] WiFi resilience testing
- [ ] Multi-baby testing (if applicable)

---

## 🎯 SUCCESS METRICS

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **HR Accuracy** | ±3 BPM | Compare with medical pulse oximeter |
| **RR Accuracy** | ±2 BPM | Visual counting + stopwatch |
| **SpO2 Accuracy** | ±2% | Compare with medical pulse oximeter |
| **Temp Accuracy** | ±0.5°C | Compare with medical thermometer |
| **Apnea Detection** | <5 seconds | Simulated apnea (hold breath test) |
| **Alert Latency** | <10 seconds | Time from event to notification |
| **Uptime** | >99% | 24-hour continuous operation |
| **False Alerts** | <1 per day | Log all alerts, verify validity |

---

## 🔗 REFERENCES

- **Seeed Studio MR60BHA1**: [Product Page](https://www.seeedstudio.com/60GHz-mmWave-Sensor-Breathing-and-Heartbeat-Module-p-5305.html)
- **ESP32 UART Guide**: ESP-IDF UART API Reference
- **MAX30102 Datasheet**: Maxim Integrated
- **MLX90614 Datasheet**: Melexis

---

**Implementation Status:** ✅ Architecture Updated | 🔄 Firmware In Progress | ⏳ Testing Pending

