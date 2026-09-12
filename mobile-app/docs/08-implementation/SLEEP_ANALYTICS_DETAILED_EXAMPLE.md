# 🌙 Sleep Analytics: Sensor to Insight (Detailed Example)

**System**: BabyCareApp Sleep Analysis Pipeline  
**Date**: February 2, 2026  
**Baby**: Emma (3 months old)  
**Scenario**: Complete sleep session from 8:00 PM to 6:00 AM

---

## 📖 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Minute-by-Minute Example](#minute-by-minute-example)
3. [Raw Sensor Readings](#raw-sensor-readings)
4. [Data Processing](#data-processing)
5. [Sleep Stage Classification](#sleep-stage-classification)
6. [Analytics Generation](#analytics-generation)
7. [Complete Session Analysis](#complete-session-analysis)

---

## 1️⃣ OVERVIEW

### **The Complete Pipeline**

```
SENSOR LAYER (ESP32)
─────────────────────────────────────────────────────────────
Raw physical measurements from baby's crib
↓

PROCESSING LAYER (Algorithms)
─────────────────────────────────────────────────────────────
Mathematical transformations and pattern detection
↓

CLASSIFICATION LAYER (ML/Rules)
─────────────────────────────────────────────────────────────
Sleep stage identification and state changes
↓

ANALYTICS LAYER (Aggregation)
─────────────────────────────────────────────────────────────
Session summaries, trends, insights
↓

UI LAYER (Visualization)
─────────────────────────────────────────────────────────────
Charts, cards, recommendations for parents
```

---

## 2️⃣ MINUTE-BY-MINUTE EXAMPLE

### **Scenario: Emma's Bedtime Routine → Deep Sleep**

**Timeline: 8:00 PM - 8:30 PM (30 minutes)**

```
TIME: 8:00 PM - Baby Emma placed in crib, lights dimmed
══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    PHYSICAL OBSERVATIONS                        │
├─────────────────────────────────────────────────────────────────┤
│ Emma is awake, eyes open, moving arms and legs                 │
│ Room temperature: 22°C                                          │
│ White noise machine on                                          │
│ Parent rocking gently                                           │
└─────────────────────────────────────────────────────────────────┘

SENSOR READINGS (8:00:00 PM)
─────────────────────────────────────────────────────────────────

ESP32 Device: AnvayaPod-A1B2
Located: Under crib mattress

┌──────────────────────┬──────────┬──────────────────────────────┐
│ SENSOR               │ VALUE    │ HOW IT'S MEASURED            │
├──────────────────────┼──────────┼──────────────────────────────┤
│ MAX30102 (Heart)     │ 145 bpm  │ IR LED reflects off blood    │
│ MAX30102 (SpO2)      │ 99%      │ Red/IR light absorption      │
│ MLX90614 (Body Temp) │ 37.1°C   │ IR thermometer (forehead)    │
│ DHT22 (Room Temp)    │ 22.3°C   │ Digital temp sensor          │
│ Pressure Mat         │ 45 bpm   │ Chest movement from breath   │
│ ESP32-CAM            │ 25% move │ Frame difference detection   │
│ Microphone (ADC)     │ 38 dB    │ Sound level (white noise)    │
│ DHT22 (Humidity)     │ 48%      │ Capacitive humidity sensor   │
└──────────────────────┴──────────┴──────────────────────────────┘

RAW DATA STRUCTURE (C Struct on ESP32)
─────────────────────────────────────────────────────────────────

struct VitalReading reading_8pm = {
  .timestamp      = 1738526400000,  // Unix epoch ms
  .heartRate      = 145,             // BPM
  .spO2           = 99,              // Percentage
  .bodyTemp       = 37.1,            // Celsius
  .envTemp        = 22.3,            // Celsius
  .breathRate     = 45,              // Breaths/min
  .motionLevel    = 25,              // Percentage (0-100)
  .cryDetected    = 0,               // Boolean (not crying)
  .humidity       = 48,              // Percentage
  .noiseLevel     = 38,              // Decibels
  .deviceStatus   = 0b00000001       // WiFi connected
};

STEP 1: ESP32 PROCESSES SENSOR DATA
─────────────────────────────────────────────────────────────────

// Heart Rate Calculation (MAX30102)
long irValue = 2134;  // IR photodiode reading
if (checkForBeat(irValue)) {
  long delta = millis() - lastBeat;  // Time since last beat
  lastBeat = millis();
  beatsPerMinute = 60000 / delta;    // Convert to BPM
  // delta = 414ms → BPM = 60000/414 = 145 bpm
}

// Breath Rate Calculation (Pressure Sensor)
int pressureValue = analogRead(A0);  // ADC reading
// Detect peaks in pressure signal (chest rising)
// Count peaks over 60 seconds = 45 breaths/min

// Motion Detection (Camera)
int pixelDiff = compareFrames(currentFrame, previousFrame);
motionLevel = (pixelDiff / totalPixels) * 100;
// 250,000 changed pixels / 1,000,000 total = 25%

STEP 2: ESP32 PACKAGES DATA FOR FIREBASE
─────────────────────────────────────────────────────────────────

StaticJsonDocument<1024> doc;

// Build Firestore-compatible JSON
doc["fields"]["deviceId"]["stringValue"] = "AnvayaPod-A1B2";
doc["fields"]["babyId"]["stringValue"] = "baby_Emma_123";
doc["fields"]["timestamp"]["integerValue"] = "1738526400000";

auto vitals = doc["fields"]["vitals"]["mapValue"]["fields"];
vitals["heartRate"]["integerValue"] = "145";
vitals["spO2"]["integerValue"] = "99";
vitals["bodyTemp"]["doubleValue"] = 37.1;
vitals["breathRate"]["integerValue"] = "45";
vitals["motionLevel"]["integerValue"] = "25";

String payload;
serializeJson(doc, payload);
// Resulting JSON: ~450 bytes

STEP 3: ESP32 SENDS TO FIREBASE
─────────────────────────────────────────────────────────────────

HTTPClient http;
http.begin("https://firestore.googleapis.com/v1/projects/babytrack/...");
http.addHeader("Content-Type", "application/json");
http.addHeader("Authorization", "Bearer ya29.a0AfH6SMB...");

int httpCode = http.POST(payload);
// Response: 200 OK
// Latency: ~350ms

STEP 4: FIREBASE STORES DATA
─────────────────────────────────────────────────────────────────

Firestore Document Created:
Collection: devices/AnvayaPod-A1B2/vitalReadings/auto_id_xyz

{
  deviceId: "AnvayaPod-A1B2",
  babyId: "baby_Emma_123",
  timestamp: 1738526400000,
  vitals: {
    heartRate: 145,
    spO2: 99,
    bodyTemp: 37.1,
    envTemp: 22.3,
    breathRate: 45,
    motionLevel: 25,
    cryDetected: false,
    humidity: 48,
    noiseLevel: 38
  },
  serverTimestamp: Timestamp(2026-02-02T20:00:00.123Z)
}

ALSO UPDATED: babies/baby_Emma_123/latestVitals = {...}

STEP 5: FLUTTER APP RECEIVES UPDATE
─────────────────────────────────────────────────────────────────

// VitalsService listening to Firestore stream
Stream<LatestVitals> subscribeToLatestVitals(String babyId) {
  return _firestore
    .collection('babies')
    .doc(babyId)
    .snapshots()
    .map((snapshot) {
      final data = snapshot.data();
      return LatestVitals.fromMap(data['latestVitals']);
    });
}

// Stream emits new LatestVitals object:
LatestVitals vitals_8pm = LatestVitals(
  heartRate: 145,
  spO2: 99,
  temperature: 37.1,
  envTemperature: 22.3,
  breathRate: 45,
  motionLevel: 25,
  cryDetected: false,
  humidity: 48,
  noiseLevel: 38,
  timestamp: DateTime(2026, 2, 2, 20, 0, 0)
);

STEP 6: SLEEP INTELLIGENCE SERVICE ANALYZES
─────────────────────────────────────────────────────────────────

SleepIntelligenceService.analyzeSleepData(vitals_8pm, history)

// ALGORITHM 1: Sleep State Detection
// ═══════════════════════════════════════════════════════════

double calculateSleepStateScore(LatestVitals vitals) {
  double score = 0.0;
  
  // Factor 1: Breath Rate (30% weight)
  // Infant awake: 35-45 bpm, asleep: 25-35 bpm
  if (vitals.breathRate >= 35 && vitals.breathRate <= 45) {
    score += 0;  // Awake breathing
  } else if (vitals.breathRate >= 25 && vitals.breathRate < 35) {
    score += 30;  // Sleep breathing
  }
  // Emma: 45 bpm → score += 0
  
  // Factor 2: Body Temperature (25% weight)
  // Body temp drops 0.3-0.5°C during sleep
  if (vitals.temperature > 37.0) {
    score += 0;  // Normal awake temp
  } else if (vitals.temperature <= 37.0 && vitals.temperature >= 36.5) {
    score += 25;  // Sleep temp
  }
  // Emma: 37.1°C → score += 0
  
  // Factor 3: Motion Level (30% weight)
  // Asleep: < 5% motion, Awake: > 15%
  if (vitals.motionLevel < 5) {
    score += 30;  // Very still
  } else if (vitals.motionLevel >= 5 && vitals.motionLevel < 15) {
    score += 20;  // Somewhat still
  } else {
    score += 0;   // Active
  }
  // Emma: 25% motion → score += 0
  
  // Factor 4: Heart Rate (15% weight)
  // Infant awake: 120-160 bpm, asleep: 100-140 bpm
  if (vitals.heartRate >= 100 && vitals.heartRate <= 140) {
    score += 15;  // Sleep heart rate
  } else {
    score += 0;   // Awake heart rate
  }
  // Emma: 145 bpm → score += 0
  
  return score;
  // TOTAL: 0 + 0 + 0 + 0 = 0 points
}

SleepState state = score >= 70 ? ASLEEP : AWAKE;
// Emma: 0 < 70 → AWAKE ✓

RESULT @ 8:00 PM:
┌────────────────────────────────────────────┐
│ Sleep State: AWAKE                         │
│ Confidence: 100%                           │
│ Indicators:                                │
│  ❌ High breath rate (45 bpm)             │
│  ❌ High body temp (37.1°C)               │
│  ❌ High motion (25%)                     │
│  ❌ High heart rate (145 bpm)             │
└────────────────────────────────────────────┘
```

---

### **15 Minutes Later: Drowsiness Phase**

```
TIME: 8:15 PM - Baby Emma getting drowsy
══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    PHYSICAL OBSERVATIONS                        │
├─────────────────────────────────────────────────────────────────┤
│ Emma's eyes closing, yawning, less movement                     │
│ Sucking on pacifier rhythmically                                │
│ Parent still present, no longer rocking                         │
└─────────────────────────────────────────────────────────────────┘

SENSOR READINGS (8:15:00 PM)
─────────────────────────────────────────────────────────────────

┌──────────────────────┬──────────┬──────────────────────────────┐
│ SENSOR               │ VALUE    │ CHANGE FROM 8:00 PM          │
├──────────────────────┼──────────┼──────────────────────────────┤
│ Heart Rate           │ 138 bpm  │ ↓ 7 bpm (slowing down)       │
│ SpO2                 │ 99%      │ → (stable)                   │
│ Body Temp            │ 36.9°C   │ ↓ 0.2°C (cooling slightly)   │
│ Room Temp            │ 22.1°C   │ ↓ 0.2°C                      │
│ Breath Rate          │ 38 bpm   │ ↓ 7 bpm (slowing)            │
│ Motion Level         │ 12%      │ ↓ 13% (less movement)        │
│ Cry Detected         │ No       │ → (quiet)                    │
│ Noise Level          │ 36 dB    │ ↓ 2 dB                       │
└──────────────────────┴──────────┴──────────────────────────────┘

FLUTTER RECEIVES & ANALYZES
─────────────────────────────────────────────────────────────────

LatestVitals vitals_815pm = LatestVitals(
  heartRate: 138,
  breathRate: 38,
  temperature: 36.9,
  motionLevel: 12,
  // ...
);

// Sleep State Score Calculation
double score = 0.0;

// Breath Rate: 38 bpm (still in awake range but borderline)
score += 0;  // 38 > 35, so still awake

// Body Temperature: 36.9°C (dropped slightly)
score += 0;  // 36.9 > 37.0 but not yet sleep range

// Motion Level: 12% (reduced but not asleep level)
score += 20;  // 12% is in 5-15% range → partial points

// Heart Rate: 138 bpm (borderline)
score += 0;  // 138 < 140 but close → awake range

TOTAL: 0 + 0 + 20 + 0 = 20 points

SleepState = 20 < 70 → AWAKE (but transitioning)

RESULT @ 8:15 PM:
┌────────────────────────────────────────────┐
│ Sleep State: AWAKE (Drowsy)                │
│ Confidence: 80%                            │
│ Indicators:                                │
│  ⚠️ Breath rate decreasing                │
│  ⚠️ Motion decreasing                     │
│  ✅ Temperature dropping                  │
│  ⚠️ Heart rate slowing                    │
└────────────────────────────────────────────┘

// Store in history buffer for trend analysis
List<LatestVitals> history = [vitals_8pm, vitals_815pm];
```

---

### **15 Minutes Later: Fell Asleep!**

```
TIME: 8:30 PM - Baby Emma has fallen asleep
══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    PHYSICAL OBSERVATIONS                        │
├─────────────────────────────────────────────────────────────────┤
│ Emma's eyes closed, breathing deeply and regularly              │
│ No movement, completely still                                   │
│ Pacifier fell out, no response                                  │
│ Parent has left room quietly                                    │
└─────────────────────────────────────────────────────────────────┘

SENSOR READINGS (8:30:00 PM)
─────────────────────────────────────────────────────────────────

┌──────────────────────┬──────────┬──────────────────────────────┐
│ SENSOR               │ VALUE    │ CHANGE FROM 8:15 PM          │
├──────────────────────┼──────────┼──────────────────────────────┤
│ Heart Rate           │ 125 bpm  │ ↓ 13 bpm (significant drop)  │
│ SpO2                 │ 98%      │ ↓ 1% (slight)                │
│ Body Temp            │ 36.7°C   │ ↓ 0.2°C (continuing to drop) │
│ Room Temp            │ 22.0°C   │ ↓ 0.1°C                      │
│ Breath Rate          │ 30 bpm   │ ↓ 8 bpm (sleep breathing!)   │
│ Motion Level         │ 2%       │ ↓ 10% (almost no movement)   │
│ Cry Detected         │ No       │ → (quiet)                    │
│ Noise Level          │ 35 dB    │ ↓ 1 dB                       │
└──────────────────────┴──────────┴──────────────────────────────┘

FLUTTER ANALYZES - SLEEP DETECTED!
─────────────────────────────────────────────────────────────────

LatestVitals vitals_830pm = LatestVitals(
  heartRate: 125,
  breathRate: 30,
  temperature: 36.7,
  motionLevel: 2,
  // ...
);

// Sleep State Score Calculation
double score = 0.0;

// Factor 1: Breath Rate - 30 bpm
// 30 is in sleep range (25-35)
score += 30;  ✓

// Factor 2: Body Temperature - 36.7°C
// Dropped 0.4°C from awake state → sleep range
score += 25;  ✓

// Factor 3: Motion Level - 2%
// 2% < 5% → very still
score += 30;  ✓

// Factor 4: Heart Rate - 125 bpm
// 125 is in sleep range (100-140)
score += 15;  ✓

TOTAL: 30 + 25 + 30 + 15 = 100 points! 🌙

SleepState = 100 >= 70 → ASLEEP! ✓

// Update history
history = [vitals_8pm, vitals_815pm, vitals_830pm];

RESULT @ 8:30 PM:
┌────────────────────────────────────────────┐
│ ✅ SLEEP DETECTED!                        │
│ State: ASLEEP                              │
│ Confidence: 100%                           │
│ Sleep onset time: 8:30 PM                  │
│ Time to fall asleep: 30 minutes            │
│                                            │
│ All indicators confirm:                    │
│  ✅ Breath rate: 30 bpm (sleep range)     │
│  ✅ Body temp: 36.7°C (dropped 0.4°C)     │
│  ✅ Motion: 2% (minimal)                  │
│  ✅ Heart rate: 125 bpm (sleep range)     │
└────────────────────────────────────────────┘

// Trigger sleep session creation
SleepService.createSleepSession(
  babyId: "baby_Emma_123",
  startTime: DateTime(2026, 2, 2, 20, 30, 0),
  initialVitals: vitals_830pm
);
```

---

## 3️⃣ RAW SENSOR READINGS (DETAILED)

### **How Each Sensor Works**

#### **Heart Rate (MAX30102 - PPG Sensor)**

```
PRINCIPLE: Photoplethysmography (PPG)
─────────────────────────────────────────────────────────────────

┌────────────────────────────────────────────────────────────┐
│          MAX30102 Sensor on Baby's Wrist                   │
│                                                            │
│  [IR LED]  ───→  Skin  ───→  [Photodiode]                │
│                    ↓                                       │
│              Blood flow                                    │
│              (pulsating)                                   │
└────────────────────────────────────────────────────────────┘

HOW IT WORKS:
1. IR LED emits infrared light (880nm wavelength)
2. Light penetrates skin and reflects off blood vessels
3. Photodiode measures reflected light intensity
4. Blood absorbs more IR light during heartbeat (pulse)
5. Signal shows peaks and valleys

SIGNAL PROCESSING:
─────────────────────────────────────────────────────────────────

Raw ADC readings (18-bit, 0-262,143):
Time    IR Value    Red Value   Interpretation
─────────────────────────────────────────────────
0ms     95,000      80,000      Baseline
50ms    98,000      82,000      Rising
100ms   105,000     88,000      Peak (heartbeat!)
150ms   102,000     85,000      Falling
200ms   95,000      80,000      Baseline
250ms   98,000      82,000      Rising
300ms   104,000     87,500      Peak (heartbeat!)
350ms   101,000     84,000      Falling
400ms   95,000      80,000      Baseline

PEAK DETECTION ALGORITHM:
──────────────────────────────────────────────────────────────

long lastBeat = 0;
long beatsPerMinute = 0;
const int THRESHOLD = 100000;

void loop() {
  long irValue = particleSensor.getIR();
  
  if (irValue > THRESHOLD) {  // Beat detected!
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    if (delta > 300 && delta < 2000) {  // Valid beat (30-200 bpm)
      beatsPerMinute = 60000 / delta;
      
      // Example: delta = 480ms
      // BPM = 60000 / 480 = 125 bpm
    }
  }
}

REAL CALCULATION @ 8:30 PM:
──────────────────────────────────────────────────────────────
Peak 1 at: 1738526400000 ms (8:30:00.000)
Peak 2 at: 1738526400480 ms (8:30:00.480)
Delta = 480 ms
Heart Rate = 60000 / 480 = 125 bpm ✓
```

#### **Breath Rate (Pressure Mat Sensor)**

```
PRINCIPLE: Piezoelectric Pressure Sensing
─────────────────────────────────────────────────────────────────

┌────────────────────────────────────────────────────────────┐
│              Baby Lying on Pressure Mat                    │
│                                                            │
│         ╔═══════════════════════════╗                     │
│         ║    [Pressure Sensors]     ║                     │
│         ║  ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ ▪ ║  ← Under mattress  │
│         ╚═══════════════════════════╝                     │
│                     ↑                                      │
│              Chest movement                                │
│          (breathing in and out)                            │
└────────────────────────────────────────────────────────────┘

HOW IT WORKS:
1. Pressure mat embedded under crib mattress
2. Baby's chest rises and falls with breathing
3. Weight shifts create pressure changes
4. Piezoelectric sensor converts pressure → voltage
5. ADC reads voltage changes

SIGNAL PROCESSING:
─────────────────────────────────────────────────────────────────

Raw ADC readings (12-bit, 0-4095):
Time     Pressure    Interpretation
──────────────────────────────────────────
0.0s     2100        Exhale (chest down)
0.5s     2300        Inhaling
1.0s     2500        Inhale peak (chest up)
1.5s     2300        Exhaling
2.0s     2100        Exhale (chest down)
2.5s     2300        Inhaling
3.0s     2500        Inhale peak (chest up)
3.5s     2300        Exhaling
4.0s     2100        Exhale (chest down)

BREATH DETECTION ALGORITHM:
──────────────────────────────────────────────────────────────

const int BREATH_THRESHOLD = 2400;
int lastBreathTime = 0;
int breathCount = 0;
int breathRate = 0;

void loop() {
  int pressure = analogRead(PRESSURE_PIN);
  
  // Detect breath (chest rising above threshold)
  if (pressure > BREATH_THRESHOLD && !breathDetected) {
    breathDetected = true;
    breathCount++;
    
    // Calculate rate every 60 seconds
    if (millis() - lastCalcTime > 60000) {
      breathRate = breathCount;
      breathCount = 0;
      lastCalcTime = millis();
    }
  }
  
  if (pressure < BREATH_THRESHOLD) {
    breathDetected = false;
  }
}

REAL CALCULATION @ 8:30 PM:
──────────────────────────────────────────────────────────────
Breaths counted in last 60 seconds: 30
Breath Rate = 30 breaths/minute ✓

Pattern analysis:
Average breath duration: 2.0 seconds (inhale + exhale)
Breathing rhythm: Regular, consistent
Variability (σ): 0.15 seconds (very stable) → Deep sleep!
```

#### **Body Temperature (MLX90614 - IR Thermometer)**

```
PRINCIPLE: Infrared Thermal Radiation
─────────────────────────────────────────────────────────────────

┌────────────────────────────────────────────────────────────┐
│           MLX90614 Sensor Above Baby's Forehead            │
│                                                            │
│              [IR Thermopile]                               │
│                    ↓                                       │
│               IR radiation                                 │
│                    ↓                                       │
│        ┌─────────────────────┐                            │
│        │   Baby's Forehead   │                            │
│        │    (36.7°C)         │                            │
│        └─────────────────────┘                            │
└────────────────────────────────────────────────────────────┘

HOW IT WORKS:
1. All objects emit infrared radiation proportional to temperature
2. MLX90614 thermopile detects IR radiation
3. Sensor calculates temperature using Stefan-Boltzmann law
4. Compensates for ambient temperature
5. Outputs digital temperature via I2C

READING PROCESS:
─────────────────────────────────────────────────────────────────

#include <Adafruit_MLX90614.h>

Adafruit_MLX90614 mlx = Adafruit_MLX90614();

void setup() {
  mlx.begin();
}

void loop() {
  // Read object (baby) temperature
  double objectTemp = mlx.readObjectTempC();
  
  // Read ambient (room) temperature
  double ambientTemp = mlx.readAmbientTempC();
  
  // Example readings @ 8:30 PM:
  // objectTemp = 36.72°C (baby's forehead)
  // ambientTemp = 22.05°C (room)
  
  bodyTemp = objectTemp;  // 36.7°C ✓
}

ACCURACY:
──────────────────────────────────────────────────────────────
Resolution: 0.02°C
Accuracy: ±0.5°C for body temperature range
Measurement time: < 1 second
```

#### **Motion Detection (ESP32-CAM)**

```
PRINCIPLE: Frame Difference Algorithm
─────────────────────────────────────────────────────────────────

┌────────────────────────────────────────────────────────────┐
│              ESP32-CAM Mounted Above Crib                  │
│                                                            │
│              [Camera Module]                               │
│                    ↓                                       │
│              Field of view                                 │
│                    ↓                                       │
│        ┌─────────────────────┐                            │
│        │    Baby in Crib     │                            │
│        └─────────────────────┘                            │
└────────────────────────────────────────────────────────────┘

HOW IT WORKS:
1. Capture frame every 100ms (10 FPS)
2. Convert to grayscale for efficiency
3. Compare with previous frame pixel-by-pixel
4. Count pixels that changed beyond threshold
5. Calculate motion percentage

ALGORITHM:
─────────────────────────────────────────────────────────────────

#include "esp_camera.h"

camera_fb_t *previousFrame = NULL;
camera_fb_t *currentFrame = NULL;

int calculateMotion() {
  currentFrame = esp_camera_fb_get();
  
  if (previousFrame == NULL) {
    previousFrame = currentFrame;
    return 0;
  }
  
  int changedPixels = 0;
  int totalPixels = currentFrame->width * currentFrame->height;
  const int MOTION_THRESHOLD = 25;  // Brightness difference
  
  for (int i = 0; i < totalPixels; i++) {
    int diff = abs(currentFrame->buf[i] - previousFrame->buf[i]);
    if (diff > MOTION_THRESHOLD) {
      changedPixels++;
    }
  }
  
  previousFrame = currentFrame;
  
  // Calculate percentage
  int motionLevel = (changedPixels * 100) / totalPixels;
  return motionLevel;
}

REAL CALCULATION @ 8:30 PM:
──────────────────────────────────────────────────────────────
Image resolution: 320×240 = 76,800 pixels
Changed pixels: 1,536 (baby barely moving, just breathing)
Motion level = (1,536 / 76,800) × 100 = 2% ✓

Interpretation:
0-3%:   Deep sleep (almost no movement)
4-10%:  Light sleep (small movements)
11-20%: REM sleep (eye movements, twitches)
21-50%: Drowsy/transitioning
50%+:   Awake and active
```

---

## 4️⃣ DATA PROCESSING

### **Creating Historical Context**

```dart
// SleepIntelligenceService stores recent readings in a buffer

class SleepIntelligenceService {
  // Circular buffer: Last 60 readings (1 minute of data at 1 Hz)
  final List<LatestVitals> _historyBuffer = [];
  static const int BUFFER_SIZE = 60;
  
  void addReading(LatestVitals vitals) {
    _historyBuffer.add(vitals);
    if (_historyBuffer.length > BUFFER_SIZE) {
      _historyBuffer.removeAt(0);  // Remove oldest
    }
  }
  
  // EXAMPLE: History at 8:30 PM (30 readings stored)
  // ═══════════════════════════════════════════════════════════
  
  // Reading 1 (8:00:00 PM): HR=145, BR=45, Temp=37.1, Motion=25%
  // Reading 2 (8:00:01 PM): HR=145, BR=44, Temp=37.1, Motion=24%
  // Reading 3 (8:00:02 PM): HR=144, BR=45, Temp=37.1, Motion=26%
  // ...
  // Reading 900 (8:15:00 PM): HR=138, BR=38, Temp=36.9, Motion=12%
  // ...
  // Reading 1800 (8:30:00 PM): HR=125, BR=30, Temp=36.7, Motion=2%
}
```

### **Calculating Breath Rate Variability (σ)**

```dart
// ALGORITHM 5: Breath Rate Variability Analysis
// ═══════════════════════════════════════════════════════════

double calculateBreathVariability(List<LatestVitals> history) {
  if (history.length < 10) return 0.0;
  
  // Get recent breath rates (last 30 seconds)
  List<int> recentBreathRates = history
    .skip(history.length - 30)
    .map((v) => v.breathRate)
    .toList();
  
  // EXAMPLE @ 8:30 PM:
  // recentBreathRates = [30, 31, 29, 30, 30, 31, 29, 30, 31, 30, ...]
  
  // Step 1: Calculate mean (μ)
  double mean = recentBreathRates.reduce((a, b) => a + b) / 
                recentBreathRates.length;
  
  // mean = 900 / 30 = 30.0 bpm
  
  // Step 2: Calculate variance
  double variance = 0.0;
  for (int rate in recentBreathRates) {
    double diff = rate - mean;
    variance += diff * diff;
  }
  variance /= recentBreathRates.length;
  
  // Example calculation:
  // (30-30)² = 0
  // (31-30)² = 1
  // (29-30)² = 1
  // (30-30)² = 0
  // ... sum = 20
  // variance = 20 / 30 = 0.67
  
  // Step 3: Calculate standard deviation (σ)
  double stdDev = sqrt(variance);
  
  // σ = √0.67 = 0.82
  
  return stdDev;
}

// INTERPRETATION:
// σ < 2.0:   Very stable breathing → Deep sleep
// σ 2.0-4.0: Moderate variation → Light sleep
// σ > 4.0:   High variation → REM sleep or awake

// Emma @ 8:30 PM: σ = 0.82 → Deep sleep! ✓
```

---

## 5️⃣ SLEEP STAGE CLASSIFICATION

### **Algorithm 2: Multi-Factor Sleep Stage Classification**

```dart
// Now we determine: Is Emma in DEEP, LIGHT, or REM sleep?
// ═══════════════════════════════════════════════════════════

SleepStage classifySleepStage(
  LatestVitals current,
  List<LatestVitals> history
) {
  // FEATURE 1: Breath Rate Stability
  // ──────────────────────────────────────────────────────────
  double breathVariability = calculateBreathVariability(history);
  double breathStability = 0.0;
  
  if (breathVariability < 2.0) {
    breathStability = 1.0;  // Very stable
  } else if (breathVariability < 4.0) {
    breathStability = 0.5;  // Moderately stable
  } else {
    breathStability = 0.0;  // Unstable (REM)
  }
  
  // Emma: σ = 0.82 → breathStability = 1.0 ✓
  
  // FEATURE 2: Motion Pattern
  // ──────────────────────────────────────────────────────────
  double motionScore = 0.0;
  
  if (current.motionLevel < 3) {
    motionScore = 1.0;  // Almost no movement (deep sleep)
  } else if (current.motionLevel < 10) {
    motionScore = 0.6;  // Some movement (light sleep)
  } else if (current.motionLevel < 20) {
    motionScore = 0.2;  // Periodic movement (REM)
  } else {
    motionScore = 0.0;  // Active (awake)
  }
  
  // Emma: motion = 2% → motionScore = 1.0 ✓
  
  // FEATURE 3: Absolute Breath Rate
  // ──────────────────────────────────────────────────────────
  double breathRateScore = 0.0;
  
  // Deep sleep: 25-30 bpm (slowest)
  // Light sleep: 30-35 bpm
  // REM sleep: 28-40 bpm (variable)
  
  if (current.breathRate >= 25 && current.breathRate <= 30) {
    breathRateScore = 1.0;  // Deep sleep range
  } else if (current.breathRate > 30 && current.breathRate <= 35) {
    breathRateScore = 0.6;  // Light sleep range
  } else {
    breathRateScore = 0.3;  // REM or awake
  }
  
  // Emma: BR = 30 bpm → breathRateScore = 1.0 ✓
  
  // FEATURE 4: Heart Rate Variability (HRV)
  // ──────────────────────────────────────────────────────────
  double hrvScore = calculateHRV(history);
  
  // HRV is higher in deep sleep (parasympathetic dominance)
  // HRV is lower in REM sleep (sympathetic activation)
  
  // Emma's recent HR: [125, 124, 126, 125, 125, 124, 126, ...]
  // HRV = 1.2 → High variability → Deep sleep
  
  if (hrvScore > 1.0) {
    hrvScore = 1.0;  // High HRV → deep sleep
  } else if (hrvScore > 0.5) {
    hrvScore = 0.5;  // Moderate HRV → light sleep
  } else {
    hrvScore = 0.0;  // Low HRV → REM
  }
  
  // Emma: HRV = 1.2 → hrvScore = 1.0 ✓
  
  // WEIGHTED SCORING FOR EACH STAGE
  // ══════════════════════════════════════════════════════════
  
  // DEEP SLEEP SCORE (weights sum to 1.0)
  double deepScore = 
    (breathStability * 0.35) +    // 1.0 × 0.35 = 0.35
    (motionScore * 0.30) +         // 1.0 × 0.30 = 0.30
    (breathRateScore * 0.25) +     // 1.0 × 0.25 = 0.25
    (hrvScore * 0.10);             // 1.0 × 0.10 = 0.10
  // deepScore = 1.0 (perfect!)
  
  // LIGHT SLEEP SCORE
  double lightScore = 
    ((1.0 - breathStability) * 0.35) +  // 0.0 × 0.35 = 0
    (motionScore * 0.30) +               // 1.0 × 0.30 = 0.30
    ((breathRateScore < 0.6 ? 0 : breathRateScore) * 0.25) + // 0.25
    (hrvScore * 0.10);                   // 0.10
  // lightScore = 0.65
  
  // REM SLEEP SCORE
  double remScore = 
    ((breathVariability > 4.0 ? 1.0 : 0.0) * 0.40) + // 0 × 0.40 = 0
    ((current.motionLevel > 10 ? 0.8 : 0.0) * 0.30) + // 0 × 0.30 = 0
    ((breathRateScore < 0.5 ? 0.5 : 0.0) * 0.30);    // 0 × 0.30 = 0
  // remScore = 0.0
  
  // SELECT HIGHEST SCORING STAGE
  // ══════════════════════════════════════════════════════════
  
  if (deepScore > lightScore && deepScore > remScore) {
    return SleepStage.DEEP;  ✓ Emma is in DEEP sleep!
  } else if (lightScore > remScore) {
    return SleepStage.LIGHT;
  } else {
    return SleepStage.REM;
  }
}

FINAL RESULT @ 8:30 PM:
┌─────────────────────────────────────────────────────────────┐
│ 🌙 DEEP SLEEP DETECTED                                     │
│                                                             │
│ Stage: DEEP                                                 │
│ Confidence: 100% (score = 1.0)                              │
│                                                             │
│ Evidence:                                                   │
│  ✅ Breath variability: 0.82 (very stable)                 │
│  ✅ Motion level: 2% (minimal movement)                    │
│  ✅ Breath rate: 30 bpm (deep sleep range)                 │
│  ✅ Heart rate variability: High (parasympathetic)         │
│                                                             │
│ Alternative scores:                                         │
│  • Light sleep: 0.65 (ruled out)                           │
│  • REM sleep: 0.0 (ruled out)                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 6️⃣ ANALYTICS GENERATION

### **Building the Sleep Session**

```dart
// As Emma sleeps through the night, we collect all stages
// ═══════════════════════════════════════════════════════════

class SleepService {
  Future<void> trackSleepSession(String babyId) async {
    // Session started at 8:30 PM when sleep was first detected
    
    SleepSession session = SleepSession(
      id: 'session_20260202_2030',
      babyId: babyId,
      startTime: DateTime(2026, 2, 2, 20, 30, 0),
      endTime: null,  // Still sleeping
      stageBreakdown: {},
      vitalLogs: [],
      cryEvents: [],
    );
    
    // Stream of vitals updates every second
    _vitalsStream.listen((vitals) {
      // Analyze and classify
      SleepStage stage = classifySleepStage(vitals, history);
      
      // Log vital + stage
      session.vitalLogs.add(VitalLog(
        timestamp: vitals.timestamp,
        heartRate: vitals.heartRate,
        breathRate: vitals.breathRate,
        bodyTemp: vitals.temperature,
        motionLevel: vitals.motionLevel,
        sleepStage: stage,
      ));
      
      // Update stage breakdown
      if (!session.stageBreakdown.containsKey(stage)) {
        session.stageBreakdown[stage] = Duration.zero;
      }
      session.stageBreakdown[stage] += Duration(seconds: 1);
      
      // Save to Firestore every minute
      if (vitals.timestamp.second == 0) {
        _saveSession(session);
      }
    });
  }
}

EXAMPLE: Emma's Sleep Stages Over 10 Hours
═══════════════════════════════════════════════════════════

Time      Stage   Duration  Vitals
──────────────────────────────────────────────────────────────
8:30 PM   DEEP    45 min    HR=125, BR=30, Temp=36.7, Motion=2%
9:15 PM   LIGHT   20 min    HR=130, BR=32, Temp=36.8, Motion=6%
9:35 PM   REM     15 min    HR=135, BR=35, Temp=36.8, Motion=12%
9:50 PM   LIGHT   25 min    HR=128, BR=31, Temp=36.7, Motion=7%
10:15 PM  DEEP    60 min    HR=122, BR=28, Temp=36.6, Motion=1%
11:15 PM  LIGHT   30 min    HR=132, BR=33, Temp=36.8, Motion=8%
11:45 PM  REM     20 min    HR=138, BR=36, Temp=36.9, Motion=15%
12:05 AM  DEEP    90 min    HR=120, BR=27, Temp=36.5, Motion=1%
1:35 AM   LIGHT   25 min    HR=128, BR=31, Temp=36.7, Motion=6%
2:00 AM   DEEP    75 min    HR=123, BR=29, Temp=36.6, Motion=2%
3:15 AM   LIGHT   20 min    HR=130, BR=32, Temp=36.8, Motion=7%
3:35 AM   REM     25 min    HR=136, BR=37, Temp=36.9, Motion=14%
4:00 AM   DEEP    60 min    HR=124, BR=29, Temp=36.6, Motion=1%
5:00 AM   LIGHT   30 min    HR=131, BR=33, Temp=36.8, Motion=8%
5:30 AM   REM     30 min    HR=140, BR=38, Temp=37.0, Motion=18%
6:00 AM   AWAKE   --        HR=145, BR=42, Temp=37.1, Motion=30%

SESSION SUMMARY:
──────────────────────────────────────────────────────────────
Total Sleep Duration: 9 hours 30 minutes

Stage Breakdown:
  Deep Sleep:  330 minutes (58%)  ✓ Excellent!
  Light Sleep: 150 minutes (26%)
  REM Sleep:   90 minutes  (16%)

Sleep Cycles: 5 complete cycles
Average Cycle Length: 114 minutes

Wake Events: 0 (slept through the night!)
Cry Events: 0

Vital Ranges:
  Heart Rate: 120-140 bpm (healthy)
  Breath Rate: 27-38 bpm (normal)
  Body Temp: 36.5-37.0°C (stable)
  Motion: 1-18% (typical)
```

### **Algorithm 3: Sleep Quality Scoring**

```dart
// Calculate overall quality score (0-100)
// ═══════════════════════════════════════════════════════════

double calculateSleepQuality(SleepSession session) {
  double totalScore = 0.0;
  
  // COMPONENT 1: Duration (30% weight)
  // ──────────────────────────────────────────────────────────
  // Ideal: 12-15 hours for 3-month-old
  int durationMinutes = session.duration.inMinutes;
  double durationScore = 0.0;
  
  if (durationMinutes >= 720 && durationMinutes <= 900) {
    durationScore = 30.0;  // Perfect duration (12-15 hours)
  } else if (durationMinutes >= 600 && durationMinutes <= 1080) {
    durationScore = 25.0;  // Good (10-18 hours)
  } else if (durationMinutes >= 480 && durationMinutes <= 1200) {
    durationScore = 20.0;  // Acceptable (8-20 hours)
  } else {
    durationScore = 10.0;  // Too short or too long
  }
  
  // Emma: 570 minutes (9.5 hours) → 25 points ✓
  
  // COMPONENT 2: Sleep Architecture (25% weight)
  // ──────────────────────────────────────────────────────────
  // Ideal distribution: 50-60% deep, 20-30% light, 15-25% REM
  
  double deepPercent = (session.stageBreakdown[SleepStage.DEEP]?.inMinutes ?? 0) / 
                       durationMinutes * 100;
  double lightPercent = (session.stageBreakdown[SleepStage.LIGHT]?.inMinutes ?? 0) / 
                        durationMinutes * 100;
  double remPercent = (session.stageBreakdown[SleepStage.REM]?.inMinutes ?? 0) / 
                      durationMinutes * 100;
  
  double architectureScore = 0.0;
  
  // Check deep sleep percentage
  if (deepPercent >= 50 && deepPercent <= 60) {
    architectureScore += 12.5;  // Perfect
  } else if (deepPercent >= 40 && deepPercent <= 70) {
    architectureScore += 10.0;  // Good
  } else {
    architectureScore += 5.0;   // Suboptimal
  }
  
  // Check REM percentage
  if (remPercent >= 15 && remPercent <= 25) {
    architectureScore += 12.5;  // Perfect
  } else if (remPercent >= 10 && remPercent <= 30) {
    architectureScore += 10.0;  // Good
  } else {
    architectureScore += 5.0;   // Suboptimal
  }
  
  // Emma: Deep=58%, Light=26%, REM=16%
  // Deep in range (50-60%) → 12.5 points
  // REM in range (15-25%) → 12.5 points
  // architectureScore = 25.0 ✓
  
  // COMPONENT 3: Sleep Continuity (20% weight)
  // ──────────────────────────────────────────────────────────
  // Count wake episodes and stage transitions
  
  int wakeCount = session.vitalLogs
    .where((log) => log.sleepStage == SleepStage.AWAKE)
    .length;
  
  double continuityScore = 0.0;
  
  if (wakeCount == 0) {
    continuityScore = 20.0;  // Slept through the night!
  } else if (wakeCount <= 2) {
    continuityScore = 15.0;  // 1-2 brief wakings (normal)
  } else if (wakeCount <= 5) {
    continuityScore = 10.0;  // 3-5 wakings
  } else {
    continuityScore = 5.0;   // Fragmented sleep
  }
  
  // Emma: 0 wake events → 20 points ✓
  
  // COMPONENT 4: Respiratory Stability (15% weight)
  // ──────────────────────────────────────────────────────────
  // Average breath rate variability across session
  
  List<double> breathRates = session.vitalLogs
    .map((log) => log.breathRate.toDouble())
    .toList();
  
  double avgVariability = calculateStdDev(breathRates);
  double respiratoryScore = 0.0;
  
  if (avgVariability < 3.0) {
    respiratoryScore = 15.0;  // Very stable
  } else if (avgVariability < 5.0) {
    respiratoryScore = 12.0;  // Stable
  } else if (avgVariability < 7.0) {
    respiratoryScore = 8.0;   // Moderately stable
  } else {
    respiratoryScore = 4.0;   // Unstable
  }
  
  // Emma: σ = 2.8 → 15 points ✓
  
  // COMPONENT 5: Physiological Stability (10% weight)
  // ──────────────────────────────────────────────────────────
  // Heart rate and temperature stability
  
  List<double> heartRates = session.vitalLogs
    .map((log) => log.heartRate.toDouble())
    .toList();
  
  double hrVariability = calculateStdDev(heartRates);
  double physioScore = 0.0;
  
  if (hrVariability < 5.0) {
    physioScore = 10.0;  // Very stable vitals
  } else if (hrVariability < 10.0) {
    physioScore = 8.0;   // Stable
  } else {
    physioScore = 5.0;   // Some variation
  }
  
  // Emma: HR σ = 4.2 → 10 points ✓
  
  // TOTAL SCORE
  // ══════════════════════════════════════════════════════════
  
  totalScore = durationScore +      // 25
               architectureScore +   // 25
               continuityScore +     // 20
               respiratoryScore +    // 15
               physioScore;          // 10
  
  return totalScore;  // 95 / 100 → EXCELLENT! ✓
}

EMMA'S SLEEP QUALITY REPORT:
┌─────────────────────────────────────────────────────────────┐
│ 🌟 SLEEP QUALITY: 95/100 - EXCELLENT!                      │
│                                                             │
│ Breakdown:                                                  │
│  ✅ Duration:          25/30  (9.5 hours - good)           │
│  ✅ Architecture:      25/25  (perfect distribution)       │
│  ✅ Continuity:        20/20  (no wake events!)            │
│  ✅ Respiratory:       15/15  (very stable breathing)      │
│  ✅ Physiological:     10/10  (stable vitals)              │
│                                                             │
│ Rating: EXCELLENT                                           │
│ Grade: A                                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 7️⃣ COMPLETE SESSION ANALYSIS

### **Generated Insights & Recommendations**

```dart
class SleepAnalytics {
  
  SleepInsights generateInsights(SleepSession session) {
    return SleepInsights(
      
      // KEY METRICS
      // ═══════════════════════════════════════════════════════
      totalDuration: session.duration,
      sleepQuality: 95,  // Calculated above
      deepSleepPercentage: 58,
      lightSleepPercentage: 26,
      remSleepPercentage: 16,
      sleepCycles: 5,
      avgCycleLength: Duration(minutes: 114),
      
      // ACHIEVEMENTS
      // ═══════════════════════════════════════════════════════
      achievements: [
        '🏆 Slept through the night!',
        '🌙 58% deep sleep (excellent)',
        '🎯 5 complete sleep cycles',
        '😴 9.5 hours total sleep',
      ],
      
      // TRENDS (vs previous nights)
      // ═══════════════════════════════════════════════════════
      trends: [
        TrendData(
          metric: 'Deep Sleep',
          current: 58,
          previous: 52,
          change: +6,
          direction: TrendDirection.UP,
          interpretation: 'Improved by 6%'
        ),
        TrendData(
          metric: 'Wake Events',
          current: 0,
          previous: 2,
          change: -2,
          direction: TrendDirection.DOWN,
          interpretation: 'Slept through for first time!'
        ),
      ],
      
      // RECOMMENDATIONS
      // ═══════════════════════════════════════════════════════
      recommendations: [
        Recommendation(
          title: 'Maintain bedtime routine',
          description: 'The 8:30 PM bedtime worked perfectly. '
                      'Keep this consistent for best results.',
          priority: RecommendationPriority.HIGH,
        ),
        Recommendation(
          title: 'Room temperature is ideal',
          description: 'Room stayed at 22°C throughout the night. '
                      'This is perfect for infant sleep.',
          priority: RecommendationPriority.INFO,
        ),
        Recommendation(
          title: 'Consider slightly earlier bedtime',
          description: 'Emma could benefit from 30 more minutes '
                      'to reach the ideal 10-hour mark.',
          priority: RecommendationPriority.MEDIUM,
        ),
      ],
      
      // ALERTS & WARNINGS
      // ═══════════════════════════════════════════════════════
      alerts: [],  // None! Perfect night
      
      // DETAILED TIMELINE
      // ═══════════════════════════════════════════════════════
      timeline: [
        TimelineEvent(
          time: DateTime(2026, 2, 2, 20, 30),
          event: 'Fell asleep',
          stage: SleepStage.DEEP,
          vitals: 'HR: 125, BR: 30',
        ),
        TimelineEvent(
          time: DateTime(2026, 2, 2, 21, 15),
          event: 'Transitioned to light sleep',
          stage: SleepStage.LIGHT,
          vitals: 'HR: 130, BR: 32',
        ),
        // ... (all stage transitions)
        TimelineEvent(
          time: DateTime(2026, 2, 3, 6, 0),
          event: 'Woke up naturally',
          stage: SleepStage.AWAKE,
          vitals: 'HR: 145, BR: 42',
        ),
      ],
    );
  }
}
```

### **UI Visualization**

```dart
// How this appears in the Flutter app
// ═══════════════════════════════════════════════════════════

class SleepAnalysisScreen extends StatelessWidget {
  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sleep Analysis')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            
            // QUALITY SCORE CARD
            // ─────────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  Text('Sleep Quality', style: heading),
                  
                  // Circular progress indicator
                  CircularPercentIndicator(
                    radius: 120,
                    percent: 0.95,  // 95/100
                    lineWidth: 20,
                    progressColor: Colors.green,
                    center: Column(
                      children: [
                        Text('95', style: giant),
                        Text('EXCELLENT', style: subtitle),
                      ],
                    ),
                  ),
                  
                  // Component breakdown
                  Row(
                    children: [
                      _scoreChip('Duration', 25, 30),
                      _scoreChip('Architecture', 25, 25),
                      _scoreChip('Continuity', 20, 20),
                    ],
                  ),
                ],
              ),
            ),
            
            // SLEEP STAGES PIE CHART
            // ─────────────────────────────────────────────
            Card(
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: 58,  // Deep sleep %
                      title: 'Deep\n58%',
                      color: Colors.blue[900],
                      radius: 100,
                    ),
                    PieChartSectionData(
                      value: 26,  // Light sleep %
                      title: 'Light\n26%',
                      color: Colors.blue[400],
                      radius: 90,
                    ),
                    PieChartSectionData(
                      value: 16,  // REM sleep %
                      title: 'REM\n16%',
                      color: Colors.purple,
                      radius: 90,
                    ),
                  ],
                ),
              ),
            ),
            
            // HYPNOGRAM (Sleep stages over time)
            // ─────────────────────────────────────────────
            Card(
              child: LineChart(
                LineChartData(
                  // X-axis: Time (8PM - 6AM)
                  // Y-axis: Sleep stage (DEEP=0, LIGHT=1, REM=2, AWAKE=3)
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        FlSpot(0, 0),    // 8:30 PM - Deep
                        FlSpot(45, 1),   // 9:15 PM - Light
                        FlSpot(65, 2),   // 9:35 PM - REM
                        // ... all transitions
                        FlSpot(570, 3),  // 6:00 AM - Awake
                      ],
                      colors: [Colors.blue],
                      isCurved: false,  // Step chart
                    ),
                  ],
                ),
              ),
            ),
            
            // ACHIEVEMENTS
            // ─────────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon('🏆'),
                    title: Text('Slept through the night!'),
                    subtitle: Text('No wake events detected'),
                  ),
                  ListTile(
                    leading: Icon('🌙'),
                    title: Text('58% deep sleep'),
                    subtitle: Text('Excellent recovery sleep'),
                  ),
                ],
              ),
            ),
            
            // RECOMMENDATIONS
            // ─────────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.tips_and_updates),
                    title: Text('Maintain bedtime routine'),
                    subtitle: Text('8:30 PM worked perfectly'),
                    trailing: Chip(label: Text('HIGH')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 COMPLETE SUMMARY

### **The Journey: Sensor → Insight**

```
PHYSICAL WORLD
══════════════════════════════════════════════════════════════
Baby Emma sleeping peacefully in crib at 8:30 PM
  ↓ Emits IR radiation (body heat)
  ↓ Blood pulses through vessels
  ↓ Chest rises and falls with breathing
  ↓ Minimal body movement

SENSOR LAYER (ESP32)
══════════════════════════════════════════════════════════════
MLX90614:        36.7°C body temperature
MAX30102:        125 bpm heart rate, 98% SpO2
Pressure Mat:    30 breaths/minute
ESP32-CAM:       2% motion level
  ↓ Read every 100ms
  ↓ Process signals
  ↓ Package into struct

DATA TRANSMISSION
══════════════════════════════════════════════════════════════
C Struct → JSON → HTTPS POST → Firebase
32 bytes → 450 bytes → 750 bytes → Stored
  ↓ 350ms latency
  ↓ Firestore document created

CLOUD PROCESSING
══════════════════════════════════════════════════════════════
Firestore:       Document stored
Indexes:         Updated for queries
Cloud Function:  Checks for alerts (none needed)
Streams:         Push update to Flutter app
  ↓ 100ms latency

FLUTTER APP PROCESSING
══════════════════════════════════════════════════════════════
Stream:          Receives new vitals
Parser:          Maps to Dart object
Provider:        Updates state
  ↓ notifyListeners()

ALGORITHM LAYER
══════════════════════════════════════════════════════════════
Sleep State:     Calculate score (100/100) → ASLEEP
Breath Variance: σ = 0.82 → Very stable
Sleep Stage:     Multi-factor scoring → DEEP SLEEP
  ↓ Classification complete

ANALYTICS LAYER
══════════════════════════════════════════════════════════════
Session:         Update sleep session
Stages:          Track DEEP: 330min, LIGHT: 150min, REM: 90min
Quality:         Calculate score → 95/100 (EXCELLENT)
Insights:        Generate recommendations
  ↓ Analytics ready

UI LAYER
══════════════════════════════════════════════════════════════
Widget:          Build UI components
Charts:          Render pie chart, hypnogram
Cards:           Display quality score, achievements
Recommendations: Show actionable tips
  ↓ 16ms render time

USER'S EYES
══════════════════════════════════════════════════════════════
Parent sees:     "95/100 - EXCELLENT SLEEP"
                "🏆 Slept through the night!"
                "🌙 58% deep sleep"
                
Total time: Raw sensor reading → Screen = ~700ms
```

---

## 📊 KEY TAKEAWAYS

**Mathematical Transformations:**
1. **ADC Value** (2134) → **Heart Rate** (125 bpm) → **Sleep State** (ASLEEP)
2. **Pressure Peaks** (30/min) → **Breath Rate** (30 bpm) → **Stage** (DEEP)
3. **Pixel Differences** (1536/76800) → **Motion** (2%) → **Confidence** (100%)

**Multi-Layer Processing:**
- **Physical**: Temperature, pressure, light reflection
- **Electrical**: Voltage, ADC readings, I2C signals
- **Digital**: Integers, floats, booleans
- **Network**: JSON, HTTP, Protocol Buffers
- **Application**: Dart objects, state management
- **Analytics**: Scores, percentages, classifications
- **Visualization**: Charts, colors, text

**Intelligence Stack:**
- **Rule-based**: Threshold comparisons (if breath < 35...)
- **Statistical**: Standard deviation, variance
- **Weighted scoring**: Multi-factor evaluation
- **Temporal**: Trend analysis over time
- **Pattern recognition**: Sleep cycle detection

This is how **raw physics becomes actionable parenting insights**! 🚀

