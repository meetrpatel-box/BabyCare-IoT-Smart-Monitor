# 🔧 AnvayaPod Hardware Sensors Specification

**Date:** February 2, 2026  
**Device:** AnvayaPod (ESP32-based Baby Monitor)  
**Status:** Hardware Definition

---

## 📋 TABLE OF CONTENTS

1. [Available Sensors](#available-sensors)
2. [Missing/TBD Sensors](#missingtbd-sensors)
3. [Sensor Specifications](#sensor-specifications)
4. [Hardware Architecture](#hardware-architecture)
5. [Power Budget](#power-budget)

---

## 1️⃣ AVAILABLE SENSORS

### **✅ Confirmed Hardware**

| Sensor | Model | Purpose | Communication | Accuracy | Status |
|--------|-------|---------|---------------|----------|--------|
| **60GHz mmWave** | Seeed Studio MR60BHA1 | Heart Rate + Respiratory Rate | UART (115200) | ±3 BPM (HR), ±2 BPM (RR) | ✅ Available |
| **IR Thermometer** | MLX90614 | Non-contact Body Temperature | I2C (0x5A) | ±0.5°C | ✅ Available |
| **Environment Sensor** | DHT22 | Room Temperature + Humidity | Digital (1-wire) | ±0.5°C, ±2-5% RH | ✅ Available |
| **Camera** | ESP32-CAM (OV2640) | Photo/Video Capture | SPI/I2C | 2MP | ✅ Available |
| **Microcontroller** | ESP32-DevKit-C | Main Controller | - | - | ✅ Available |

---

## 2️⃣ MISSING/TBD SENSORS

### **❌ NOT Available - Need Alternative**

#### **SpO2 (Blood Oxygen Saturation)**

**Problem:** We don't have MAX30102 or similar pulse oximetry sensor

**Why It Matters:**
- SpO2 is a critical vital sign for infant health
- Low SpO2 (<92%) indicates oxygen deprivation
- Essential for detecting respiratory distress, SIDS risk

**Possible Solutions:**

| Solution | Feasibility | Cost | Accuracy | Notes |
|----------|-------------|------|----------|-------|
| **1. Purchase MAX30102** | ✅ High | ~$5-10 | ±2% | Industry standard, I2C, easy integration |
| **2. Camera-based PPG** | ⚠️ Medium | Free | ±5-10% | Complex algorithm, lighting dependent |
| **3. Bluetooth Pulse Oximeter** | ⚠️ Medium | $30-50 | Clinical grade | Requires separate device, parent must attach |
| **4. Smartphone Integration** | ⚠️ Low | Free | Varies | Requires parent's phone with sensor |
| **5. Omit for Now** | ❌ Not Recommended | - | - | Missing critical health metric |

**Recommendation:** **Purchase MAX30102 module** (~$8 on AliExpress/Amazon)
- Most cost-effective solution
- Medical-grade accuracy
- Easy ESP32 integration (I2C)
- Small form factor
- Low power consumption

**Alternative (Short-term):** Focus on what we have:
- ✅ Heart Rate (mmWave) - Primary cardiovascular indicator
- ✅ Respiratory Rate (mmWave) - Critical for apnea detection
- ✅ Temperature (MLX90614) - Fever detection
- ❌ SpO2 - **Mark as Phase 2 feature**

---

## 3️⃣ SENSOR SPECIFICATIONS

### **60GHz mmWave Sensor (MR60BHA1)**

```yaml
Model: Seeed Studio MR60BHA1
Technology: 60-64 GHz FMCW Radar
Detection:
  - Heart Rate: 60-240 BPM (±3 BPM)
  - Respiratory Rate: 10-60 BPM (±2 BPM)
  - Presence Detection: Yes
  - Distance Measurement: 0.4-3.0 meters
Range:
  - Optimal: 0.5-1.5 meters
  - Max: 3 meters
Angle: ±60° horizontal, ±40° vertical
Response Time: <2 seconds
Update Rate: 0.5 Hz (every 2 seconds)
Communication: UART (115200 baud, 8N1)
Protocol: Binary with CRC8 checksum
Power: 100-150 mA @ 5V
Voltage: 5V
Advantages:
  - Non-contact (works through blankets/clothing)
  - Dual vital signs in one sensor
  - Privacy-preserving (no camera needed)
  - Works in complete darkness
  - No batteries to charge
```

**ESP32 Connection:**
```
mmWave TX → ESP32 GPIO 16 (RX2)
mmWave RX → ESP32 GPIO 17 (TX2)
mmWave GND → ESP32 GND
mmWave VCC → 5V
```

---

### **MLX90614 IR Thermometer**

```yaml
Model: Melexis MLX90614ESF-BAA
Technology: Non-contact Infrared Thermopile
Measurement:
  - Object Temperature: -70°C to +380°C
  - Ambient Temperature: -40°C to +125°C
  - Body Temp Range: 35-42°C (optimized)
Accuracy: ±0.5°C (body temperature range)
Resolution: 0.02°C
Response Time: <1 second
Field of View: 90° cone
Optimal Distance: 1-5 cm from forehead
Communication: I2C (address 0x5A)
Update Rate: User-defined (typically 1 Hz)
Power: 1.0 mA @ 3.3V (active), <2 µA (sleep)
Voltage: 3.3V
Advantages:
  - Medical-grade accuracy
  - No skin contact required
  - Fast response
  - Low power
```

**ESP32 Connection:**
```
MLX SDA → ESP32 GPIO 21 (I2C SDA)
MLX SCL → ESP32 GPIO 22 (I2C SCL)
MLX GND → ESP32 GND
MLX VCC → ESP32 3.3V
```

---

### **DHT22 Temperature + Humidity Sensor**

```yaml
Model: DHT22 (AM2302)
Technology: Capacitive humidity sensor + NTC thermistor
Measurement:
  - Temperature: -40°C to +80°C
  - Humidity: 0-100% RH
Accuracy:
  - Temperature: ±0.5°C
  - Humidity: ±2-5% RH
Resolution:
  - Temperature: 0.1°C
  - Humidity: 0.1% RH
Response Time: 2 seconds
Sampling Rate: 0.5 Hz (max every 2 seconds)
Communication: Single-wire digital protocol
Power: 1.5 mA (measuring), 50 µA (standby)
Voltage: 3.3-5V
Use Case: Room environment monitoring
```

**ESP32 Connection:**
```
DHT22 Data → ESP32 GPIO 4
DHT22 GND → ESP32 GND
DHT22 VCC → ESP32 3.3V or 5V
```

---

### **ESP32-CAM (OV2640)**

```yaml
Model: OV2640 2MP Camera
Resolution: 1600x1200 (UXGA max)
Frame Rate: 24 fps (VGA), 15 fps (SVGA)
Interface: SPI/I2C
Use Cases:
  - Photo capture (activity tracking, milestones)
  - Video streaming (live monitoring)
  - Cloud Vision AI (object detection, smile detection)
Power: 160-260 mA @ 3.3V (active)
Storage: MicroSD card slot (up to 4GB recommended)
```

---

## 4️⃣ HARDWARE ARCHITECTURE

### **ESP32 Pin Allocation**

```
┌─────────────────────────────────────────────────────────┐
│                    ESP32-DevKit-C                        │
├─────────────────────────────────────────────────────────┤
│  I2C Bus (Shared)                                        │
│    GPIO 21 (SDA) → MLX90614 (Temp)                      │
│    GPIO 22 (SCL) → MLX90614 (Temp)                      │
│                                                          │
│  UART2 (mmWave)                                          │
│    GPIO 16 (RX2) ← mmWave TX                            │
│    GPIO 17 (TX2) → mmWave RX                            │
│                                                          │
│  Digital I/O                                             │
│    GPIO 4        → DHT22 Data                           │
│    GPIO 2        → Status LED                           │
│    GPIO 25       → Sensor Power Control (optional)      │
│                                                          │
│  Camera (ESP32-CAM module)                               │
│    Multiple GPIOs used by camera interface              │
│                                                          │
│  WiFi (Built-in)                                         │
│    802.11 b/g/n (2.4 GHz)                               │
└─────────────────────────────────────────────────────────┘
```

### **System Block Diagram**

```
┌──────────────────────────────────────────────────────────────┐
│                       AnvayaPod Device                        │
└──────────────────────────────────────────────────────────────┘

   60GHz mmWave ──┐
                   │
   MLX90614 ──────┤
                   │         ┌────────────┐
   DHT22 ─────────┤────────>│   ESP32    │───> WiFi ───> Firebase
                   │         │ DevKit-C   │
   ESP32-CAM ─────┘         └────────────┘
                                   │
                                   ├─> MicroSD (photos/videos)
                                   └─> Status LED


Data Flow:
1. mmWave → UART → Heart Rate + Respiratory Rate
2. MLX90614 → I2C → Body Temperature
3. DHT22 → Digital → Environment Temp + Humidity
4. Camera → SPI → Photos/Videos
5. All data → ESP32 → WiFi → Cloud Functions → Firestore
```

---

## 5️⃣ POWER BUDGET

### **Power Consumption (Active Monitoring)**

```
Component              Voltage    Current     Power
─────────────────────────────────────────────────────
ESP32 (WiFi on)        3.3V       160-260 mA  528-858 mW
60GHz mmWave           5V         100-150 mA  500-750 mW
MLX90614               3.3V       1.0 mA      3.3 mW
DHT22                  3.3V       1.5 mA      5.0 mW
ESP32-CAM (standby)    3.3V       ~20 mA      66 mW
Status LED             3.3V       5 mA        16.5 mW
─────────────────────────────────────────────────────
Total (Active)                    287-437 mA  ~1.1-1.7W

Battery Life (if using battery):
- 2000 mAh battery → ~4.5-7 hours continuous
- Recommended: USB powered (wall adapter)
```

### **Power Consumption (Sleep Mode)**

```
Component              Power Consumption
───────────────────────────────────────────
ESP32 (deep sleep)     10 µA
mmWave (sleep mode)    ~10 mA (if supported)
MLX90614 (sleep)       <2 µA
DHT22 (standby)        50 µA
───────────────────────────────────────────
Total (Sleep)          ~10 mA (~33 mW)

Note: mmWave sensor may not support sleep mode
Recommendation: Keep powered for continuous monitoring
```

---

## 📊 VITAL SIGNS COVERAGE

### **Current Capabilities (With Available Hardware)**

| Vital Sign | Sensor | Status | Clinical Importance |
|------------|--------|--------|---------------------|
| ❤️ **Heart Rate** | 60GHz mmWave | ✅ **Available** | 🔴 **Critical** |
| 🫁 **Respiratory Rate** | 60GHz mmWave | ✅ **Available** | 🔴 **Critical** |
| 🌡️ **Body Temperature** | MLX90614 | ✅ **Available** | 🟡 **Important** |
| 💉 **SpO2 (Oxygen)** | ❌ None | ❌ **Missing** | 🔴 **Critical** |
| 🌡️ **Room Temperature** | DHT22 | ✅ **Available** | 🟢 **Nice to Have** |
| 💧 **Humidity** | DHT22 | ✅ **Available** | 🟢 **Nice to Have** |

### **Risk Assessment Without SpO2**

**What We Can Detect:**
- ✅ Abnormal heart rate (too fast/slow)
- ✅ Apnea (stopped breathing)
- ✅ Bradypnea (slow breathing)
- ✅ Tachypnea (fast breathing)
- ✅ Fever (high body temperature)
- ✅ Hypothermia (low body temperature)

**What We CANNOT Detect:**
- ❌ Low blood oxygen (hypoxemia)
- ❌ Silent hypoxia (normal breathing but low O2)
- ❌ Respiratory distress with normal breathing rate
- ❌ Cyanosis (blue skin from low oxygen)

**Medical Opinion Needed:**
While heart rate + respiratory rate provide good indicators, SpO2 is considered a critical vital sign for infants. Recommend consulting pediatrician about monitoring strategy without SpO2.

---

## 🛒 RECOMMENDED PURCHASE: MAX30102

### **Why MAX30102?**

```yaml
Model: Maxim Integrated MAX30102
Purpose: Pulse Oximetry (SpO2) + Heart Rate
Technology: Reflective PPG (Photoplethysmography)
Measurement:
  - SpO2: 70-100% (±2% accuracy)
  - Heart Rate: 0-200 BPM (±2 BPM)
  - Perfusion Index: Yes
Form Factor: 5.6mm x 3.3mm x 1.55mm
Communication: I2C (address 0x57)
Power: 600 µA @ 1 Hz, 1.2 mA @ 50 Hz
Voltage: 1.8V core, 3.3V I/O
Cost: $5-10 USD (module with breakout board)
Availability: Amazon, AliExpress, DigiKey, Mouser
```

### **Integration Effort**

**Hardware:**
- ✅ Same I2C bus as MLX90614 (no extra pins needed)
- ✅ Same 3.3V power supply
- ⏱️ 5 minutes to wire

**Software:**
- ✅ Arduino library available (SparkFun MAX3010x)
- ✅ Well-documented examples
- ⏱️ 2-3 hours to integrate

**Total Time:** ~Half day to fully integrate and test

### **Purchase Links**

- **Amazon:** Search "MAX30102 ESP32" (~$8-12)
- **AliExpress:** Search "MAX30102 module" (~$3-5)
- **Adafruit:** MAX30102 breakout board ($9.95)
- **SparkFun:** Particle Sensor Breakout MAX30105 ($14.95)

---

## 🎯 RECOMMENDATIONS

### **Immediate (Phase 1)**
1. ✅ **Continue with current hardware** for MVP
   - Focus on: Heart Rate, Respiratory Rate, Temperature
   - Deploy with clear disclaimer: "SpO2 monitoring not available"
   
2. 🛒 **Order MAX30102 module** ($8-10)
   - Ships in 1-2 weeks
   - Add as Phase 2 upgrade

3. 📝 **Document limitations**
   - User manual: Explain what's monitored vs not monitored
   - Medical disclaimer: Not a substitute for medical-grade monitoring

### **Phase 2 (After MAX30102 Arrives)**
1. Integrate MAX30102 sensor
2. Update firmware with SpO2 reading
3. Update Cloud Functions with SpO2 alerts
4. Update Flutter app with SpO2 display
5. Full system testing

### **Alternative (If Budget Constrained)**
1. Ship MVP without SpO2
2. Market as "Basic vital signs monitor"
3. Add SpO2 as premium feature later
4. Offer hardware upgrade kit

---

## ✅ HARDWARE READINESS CHECKLIST

- [✅] 60GHz mmWave sensor - Available
- [✅] MLX90614 IR thermometer - Available  
- [✅] DHT22 environment sensor - Available
- [✅] ESP32-CAM camera - Available
- [✅] ESP32-DevKit-C controller - Available
- [❌] MAX30102 pulse oximeter - **Need to order**
- [✅] MicroSD card - Available (for camera)
- [✅] 5V power adapter - Required
- [✅] Breadboard/PCB - For prototyping
- [✅] Jumper wires - For connections

**Status:** 80% hardware complete. Only SpO2 sensor missing.

---

**Last Updated:** February 2, 2026  
**Next Review:** After MAX30102 integration

