# 🔄 Complete Data Flow - Sensor to Screen

**System**: BabyCareApp Real-time Vital Signs & Sleep Analysis  
**Date**: February 2, 2026

---

## 🌊 **END-TO-END DATA FLOW DIAGRAM**

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          COMPLETE DATA FLOW PIPELINE                             │
│                        (From Physical Sensor to UI Screen)                       │
└─────────────────────────────────────────────────────────────────────────────────┘

LAYER 1: HARDWARE (ESP32 Device)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  MAX30102   │  │  MLX90614   │  │   Pressure  │  │  ESP32-CAM  │
│Heart+SpO2   │  │  IR Temp    │  │  Mat (Chest)│  │   Camera    │
│   Sensor    │  │   Sensor    │  │    Sensor   │  │   Module    │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │                │
       │ I2C           │ I2C            │ Analog         │ SPI
       │ 100Hz         │ 1Hz            │ 50Hz           │ 10 FPS
       ▼                ▼                ▼                ▼
   ┌────────────────────────────────────────────────────────────┐
   │              ESP32 Microcontroller                         │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  Sensor Reading Loop (every 1 second)            │     │
   │  │  ─────────────────────────────────────           │     │
   │  │  1. Read heart rate     → 128 bpm                │     │
   │  │  2. Read SpO2           → 98%                    │     │
   │  │  3. Read body temp      → 36.8°C                 │     │
   │  │  4. Read breath rate    → 28 bpm                 │     │
   │  │  5. Capture motion data → 3% movement            │     │
   │  └──────────────────────────────────────────────────┘     │
   │                            ▼                               │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  Data Packaging (JSON)                           │     │
   │  │  ─────────────────────                           │     │
   │  │  {                                               │     │
   │  │    "deviceId": "AnvayaPod-A1B2",                │     │
   │  │    "babyId": "baby_XYZ123",                     │     │
   │  │    "timestamp": 1738454400000,                  │     │
   │  │    "vitals": {                                  │     │
   │  │      "heartRate": 128,                          │     │
   │  │      "spO2": 98,                                │     │
   │  │      "bodyTemp": 36.8,                          │     │
   │  │      "breathRate": 28,                          │     │
   │  │      "motionLevel": 3                           │     │
   │  │    }                                            │     │
   │  │  }                                              │     │
   │  └──────────────────────────────────────────────────┘     │
   └────────────────────────────┬───────────────────────────────┘
                                │ WiFi (HTTPS)
                                │ ~300-500ms latency
                                ▼

LAYER 2: CLOUD (Firebase Backend)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   ┌────────────────────────────────────────────────────────────┐
   │         Firebase Firestore REST API                        │
   │  POST /v1/projects/babytrack/databases/(default)/          │
   │       documents/devices/AnvayaPod-A1B2/vitalReadings       │
   └────────────────────────────┬───────────────────────────────┘
                                │ Write to database
                                │ ~100-200ms
                                ▼
   ┌────────────────────────────────────────────────────────────┐
   │              Firestore Database                            │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  Collection: devices/{deviceId}/vitalReadings    │     │
   │  │  ─────────────────────────────────────────       │     │
   │  │  Document {auto-id}:                             │     │
   │  │  {                                               │     │
   │  │    deviceId: "AnvayaPod-A1B2",                  │     │
   │  │    babyId: "baby_XYZ123",                       │     │
   │  │    timestamp: 1738454400000,                    │     │
   │  │    vitals: {                                    │     │
   │  │      heartRate: 128,                            │     │
   │  │      spO2: 98,                                  │     │
   │  │      bodyTemp: 36.8,                            │     │
   │  │      breathRate: 28,                            │     │
   │  │      motionLevel: 3                             │     │
   │  │    },                                           │     │
   │  │    serverTimestamp: Timestamp(...)             │     │
   │  │  }                                              │     │
   │  └──────────────────────────────────────────────────┘     │
   └─────────────────┬──────────────────────┬───────────────────┘
                     │                      │
        ┌────────────┘                      └────────────┐
        ▼ ALSO UPDATE                                    ▼ TRIGGER
   ┌────────────────────────────┐         ┌──────────────────────────────┐
   │  Collection: babies        │         │   Cloud Function             │
   │  ─────────────────────     │         │   ──────────────             │
   │  Document baby_XYZ123:     │         │   onVitalsUpdate()           │
   │  {                         │         │   ┌────────────────────┐     │
   │    name: "Emma",           │         │   │ Check thresholds   │     │
   │    latestVitals: {         │         │   │ ───────────────    │     │
   │      heartRate: 128,       │         │   │ IF heartRate > 160 │     │
   │      spO2: 98,             │         │   │   → Send Alert     │     │
   │      temperature: 36.8,    │         │   │ IF spO2 < 95       │     │
   │      breathRate: 28,       │         │   │   → Send Alert     │     │
   │      timestamp: ...        │         │   │ IF bodyTemp > 38   │     │
   │    }                       │         │   │   → Send Alert     │     │
   │  }                         │         │   └────────────────────┘     │
   └────────────────┬───────────┘         └──────────┬───────────────────┘
                    │                                │
                    │ Real-time Stream               │ Push Notification
                    │ ~100-300ms                     │ via FCM
                    ▼                                ▼

LAYER 3: FLUTTER APP (Mobile/Web)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   ┌────────────────────────────────────────────────────────────┐
   │         VitalsService (Data Layer)                         │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  Stream<LatestVitals> subscribeToLatestVitals() │     │
   │  │  ────────────────────────────────────────────    │     │
   │  │  return _firestore                               │     │
   │  │    .collection('babies')                         │     │
   │  │    .doc(babyId)                                  │     │
   │  │    .snapshots()                                  │     │
   │  │    .map((snapshot) {                             │     │
   │  │      return LatestVitals.fromMap(               │     │
   │  │        snapshot.data()['latestVitals']          │     │
   │  │      );                                          │     │
   │  │    });                                           │     │
   │  └──────────────────────────────────────────────────┘     │
   └────────────────────────────┬───────────────────────────────┘
                                │ Stream emits new data
                                │ ~50-100ms
                                ▼
   ┌────────────────────────────────────────────────────────────┐
   │      SleepIntelligenceService (Processing Layer)           │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  analyzeSleepData(currentReading, history)       │     │
   │  │  ──────────────────────────────────────          │     │
   │  │  1. Calculate sleep state                        │     │
   │  │     score = (breath×0.3) + (temp×0.25) +        │     │
   │  │             (motion×0.3) + (heart×0.15)         │     │
   │  │     score = 30 + 25 + 30 + 15 = 100             │     │
   │  │     → State: ASLEEP ✓                           │     │
   │  │                                                  │     │
   │  │  2. Calculate breath variability                │     │
   │  │     σ = √(Σ(xi - μ)² / n)                       │     │
   │  │     σ = 1.7 → STABLE                            │     │
   │  │                                                  │     │
   │  │  3. Classify sleep stage                        │     │
   │  │     deepScore = (1.0×0.35) + (1.0×0.3) +       │     │
   │  │                 (1.0×0.25) + (1.0×0.1)         │     │
   │  │     deepScore = 1.0 → DEEP SLEEP                │     │
   │  │                                                  │     │
   │  │  4. Return result                               │     │
   │  │     SleepAnalysisResult {                       │     │
   │  │       sleepState: ASLEEP,                       │     │
   │  │       sleepStage: DEEP,                         │     │
   │  │       timestamp: now                            │     │
   │  │     }                                           │     │
   │  └──────────────────────────────────────────────────┘     │
   └────────────────────────────┬───────────────────────────────┘
                                │ Analysis complete
                                │ ~10-20ms
                                ▼
   ┌────────────────────────────────────────────────────────────┐
   │         VitalsProvider (State Management)                  │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  _vitalsSubscription.listen((vitals) {           │     │
   │  │    _latestVitals = vitals;                       │     │
   │  │    notifyListeners();  ← Triggers UI rebuild     │     │
   │  │  });                                             │     │
   │  │                                                  │     │
   │  │  State holds:                                    │     │
   │  │  ─────────────                                   │     │
   │  │  latestVitals: {                                │     │
   │  │    heartRate: 128,                              │     │
   │  │    spO2: 98,                                    │     │
   │  │    temperature: 36.8,                           │     │
   │  │    breathRate: 28,                              │     │
   │  │    timestamp: 10:30:45                          │     │
   │  │  }                                              │     │
   │  │  history: [last 60 readings]                    │     │
   │  │  sleepStage: DEEP                               │     │
   │  └──────────────────────────────────────────────────┘     │
   └────────────────────────────┬───────────────────────────────┘
                                │ notifyListeners()
                                │ ~1-5ms
                                ▼
   ┌────────────────────────────────────────────────────────────┐
   │              UI Layer (Widgets)                            │
   │  ┌──────────────────────────────────────────────────┐     │
   │  │  Consumer<VitalsProvider>(                       │     │
   │  │    builder: (context, provider, child) {         │     │
   │  │      final vitals = provider.latestVitals;       │     │
   │  │      return VitalsCard(vitals);                  │     │
   │  │    }                                             │     │
   │  │  )                                               │     │
   │  │                                                  │     │
   │  │  VitalsCard renders:                            │     │
   │  │  ┌────────────────────────────────────┐         │     │
   │  │  │  ❤️ Heart Rate    128 bpm  🟢     │         │     │
   │  │  │  🫁 SpO2          98%      🟢     │         │     │
   │  │  │  🌡️ Temperature   36.8°C   🟢     │         │     │
   │  │  │  💨 Breathing     28/min   🟢     │         │     │
   │  │  │  😴 Sleep Stage   DEEP     🌙     │         │     │
   │  │  │                                    │         │     │
   │  │  │  Updated: just now          🟢 Live│         │     │
   │  │  └────────────────────────────────────┘         │     │
   │  └──────────────────────────────────────────────────┘     │
   └────────────────────────────────────────────────────────────┘
                                ▲
                                │ User sees data
                                │ TOTAL LATENCY: 1-2 seconds
                                │ from sensor reading to screen!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔢 **DATA TRANSFORMATIONS AT EACH LAYER**

### **Transform 1: Sensor → Raw Values**

```cpp
// ESP32 Firmware
Input:  Analog voltage from MAX30102 sensor
        ADC reading: 2047 (12-bit, 0-4095 range)
        
Processing:
  1. Read IR LED photodiode value
  2. Detect peaks in signal (heartbeats)
  3. Calculate time between peaks
  4. Convert to BPM: 60000 / avgTimeBetweenPeaks
  
Output: heartRate = 128 bpm (integer)
```

**Code Example:**
```cpp
long irValue = heartSensor.getIR();
if (checkForBeat(irValue)) {
  long delta = millis() - lastBeat;
  lastBeat = millis();
  beatsPerMinute = 60000 / delta;
}
return (int)beatsPerMinute;  // → 128
```

---

### **Transform 2: Raw Values → JSON**

```cpp
// ESP32 Firmware
Input:  heartRate = 128 (int)
        spO2 = 98 (int)
        bodyTemp = 36.8 (float)
        breathRate = 28 (int)
        
Processing:
  StaticJsonDocument<512> doc;
  doc["fields"]["vitals"]["mapValue"]["fields"]["heartRate"]["integerValue"] = "128";
  doc["fields"]["vitals"]["mapValue"]["fields"]["spO2"]["integerValue"] = "98";
  // ... etc
  
  String payload;
  serializeJson(doc, payload);
  
Output: JSON string (Firestore format)
```

**Payload:**
```json
{
  "fields": {
    "deviceId": {"stringValue": "AnvayaPod-A1B2"},
    "babyId": {"stringValue": "baby_XYZ123"},
    "timestamp": {"integerValue": "1738454400000"},
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {"integerValue": "128"},
          "spO2": {"integerValue": "98"},
          "bodyTemp": {"doubleValue": 36.8},
          "breathRate": {"integerValue": "28"}
        }
      }
    }
  }
}
```

---

### **Transform 3: HTTP POST → Firestore Document**

```javascript
// Firebase receives HTTP POST
Input:  HTTP body (JSON string, ~500 bytes)
        
Processing:
  1. Authenticate request (check Bearer token)
  2. Parse JSON
  3. Validate schema
  4. Add serverTimestamp
  5. Generate document ID
  6. Write to Firestore
  
Output: Firestore document created
        Document ID: "vitalReadings/abc123xyz"
```

**Stored Document:**
```javascript
{
  deviceId: "AnvayaPod-A1B2",
  babyId: "baby_XYZ123",
  timestamp: 1738454400000,
  vitals: {
    heartRate: 128,
    spO2: 98,
    bodyTemp: 36.8,
    breathRate: 28,
    motionLevel: 3
  },
  serverTimestamp: Timestamp(seconds: 1738454400, nanoseconds: 500000000)
}
```

---

### **Transform 4: Firestore → Dart Model**

```dart
// Flutter VitalsService
Input:  DocumentSnapshot from Firestore stream
        
Processing:
  factory LatestVitals.fromMap(Map<String, dynamic> map) {
    return LatestVitals(
      heartRate: map['heartRate'] ?? 0,
      spO2: map['spO2'] ?? 0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      breathRate: map['breathRate'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
  
Output: LatestVitals object
```

**Dart Object:**
```dart
LatestVitals {
  heartRate: 128,           // int
  spO2: 98,                 // int
  temperature: 36.8,        // double
  breathRate: 28,           // int
  timestamp: DateTime(2026, 2, 2, 10, 30, 45),  // DateTime
}
```

---

### **Transform 5: Raw Data → Sleep Analysis**

```dart
// SleepIntelligenceService
Input:  LatestVitals {
          heartRate: 128,
          breathRate: 28,
          temperature: 36.8,
          motionLevel: 3
        }
        
Processing:
  // Step 1: Calculate sleep state score
  breathFactor = 28 < 30 ? 30 : 0  → 30
  tempFactor = 36.8 < 36.5 ? 25 : 0  → 0 (but close, gets 15)
  motionFactor = 3 < 5 ? 30 : 0  → 30
  heartFactor = 128 < 130 ? 15 : 0  → 0 (but close, gets 10)
  
  totalScore = 30 + 15 + 30 + 10 = 85
  sleepState = score >= 70 ? ASLEEP : AWAKE  → ASLEEP
  
  // Step 2: Calculate variability
  recentBreathRates = [28, 27, 29, 28, 27]
  mean = 27.8
  variance = Σ(xi - mean)² / n = 0.56
  σ = √0.56 = 0.75
  
  // Step 3: Classify stage
  breathStability = σ < 2.0 ? 1.0 : 0.0  → 1.0
  motionPattern = 3 < 3 ? 1.0 : 0.0  → 0.95
  breathRateScore = 28 < 30 ? 1.0 : 0.0  → 0.9
  
  deepScore = (1.0×0.35) + (0.95×0.3) + (0.9×0.25) + (1.0×0.1)
            = 0.35 + 0.285 + 0.225 + 0.1
            = 0.96
  
  sleepStage = DEEP (highest score)
  
Output: SleepAnalysisResult {
          sleepState: ASLEEP,
          sleepStage: DEEP,
          confidence: 0.96
        }
```

---

### **Transform 6: Analysis → UI Display**

```dart
// VitalsCard Widget
Input:  LatestVitals + SleepAnalysisResult
        
Processing:
  // Color coding
  heartRateColor = (100 <= 128 <= 160) ? Colors.green : Colors.red
  spO2Color = (98 >= 95) ? Colors.green : Colors.red
  tempColor = (36.0 <= 36.8 <= 37.5) ? Colors.green : Colors.orange
  
  // Status icons
  heartRateStatus = heartRateColor == green ? '🟢' : '🔴'
  sleepStageIcon = stage == DEEP ? '🌙' : 
                   stage == LIGHT ? '😴' : 
                   stage == REM ? '👁️' : '😊'
  
  // Live indicator
  timeSinceUpdate = now - timestamp
  isLive = timeSinceUpdate < 5 seconds
  liveIndicator = isLive ? '🟢 Live' : '⚠️ Offline'
  
Output: Rendered widget with color-coded cards
```

**Visual Result:**
```
╔════════════════════════════════════╗
║  Vital Signs          🟢 Live     ║
╠════════════════════════════════════╣
║  ❤️  Heart Rate    128 bpm  🟢   ║
║  🫁  SpO2          98%      🟢   ║
║  🌡️  Temperature   36.8°C   🟢   ║
║  💨  Breathing     28/min   🟢   ║
║  😴  Sleep Stage   DEEP     🌙   ║
║                                    ║
║  Updated: just now                 ║
╚════════════════════════════════════╝
```

---

## ⏱️ **TIMING BREAKDOWN**

```
STEP                                    TIME        CUMULATIVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ESP32: Read sensors                     10ms        10ms
ESP32: Package JSON                     5ms         15ms
ESP32: HTTP POST to Firebase            300ms       315ms
Firebase: Write to Firestore            100ms       415ms
Firebase: Trigger Cloud Function        50ms        465ms
Firebase: Update baby document          80ms        545ms
Firebase → Flutter: Stream emission     100ms       645ms
Flutter: Parse to Dart model            2ms         647ms
Flutter: Run sleep analysis             15ms        662ms
Flutter: Provider notify listeners      1ms         663ms
Flutter: Widget rebuild                 5ms         668ms
Flutter: Render frame                   16ms        684ms

───────────────────────────────────────────────────────────────
TOTAL END-TO-END LATENCY:              ~0.7 seconds (700ms)
───────────────────────────────────────────────────────────────

With network variance:                  0.5 - 2.0 seconds
Typical user experience:                1-2 seconds
```

---

## 📦 **DATA SIZE AT EACH LAYER**

```
LAYER                   FORMAT          SIZE        NOTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sensor (raw)            Binary          8 bytes     4 int16 values
ESP32 memory            Struct          16 bytes    C struct
JSON payload            String          ~450 bytes  Firestore format
HTTP packet             TCP/IP          ~600 bytes  With headers
Firestore doc           Database        ~500 bytes  Compressed storage
Stream to Flutter       Protocol Buffers ~300 bytes  Optimized wire format
Dart object             Memory          80 bytes    Object overhead
UI widget state         Memory          ~200 bytes  Full widget tree

───────────────────────────────────────────────────────────────
Data sent per reading:                  ~600 bytes
Readings per minute:                    60 readings
Data per hour:                          ~2.1 MB
Data per day:                           ~50 MB
Monthly bandwidth:                      ~1.5 GB
───────────────────────────────────────────────────────────────
```

---

## 🔄 **PARALLEL DATA FLOWS**

Your system actually has **3 concurrent flows**:

### **Flow 1: Real-time Vitals (Every 1 second)**
```
ESP32 → Firebase → Flutter → UI
Latency: 0.5-2 seconds
Purpose: Live monitoring
```

### **Flow 2: Sleep Analysis (Every 30 seconds)**
```
ESP32 → Firebase → Cloud Function → Analysis Engine → Firebase → Flutter
Latency: 1-3 seconds
Purpose: Sleep stage detection
```

### **Flow 3: Alert System (Event-driven)**
```
ESP32 → Firebase → Cloud Function → FCM → Push Notification
Latency: 0.5-1 second
Purpose: Critical alerts (fever, low oxygen, etc.)
```

---

## 🎯 **COMPLETE EXAMPLE: One Sensor Reading Journey**

```
TIME: 10:30:00.000 - Baby is sleeping
─────────────────────────────────────────────────────────────

10:30:00.000  ESP32: MAX30102 detects heartbeat
              IR value: 2047 → Beat detected
              
10:30:00.005  ESP32: Calculate BPM
              Time since last beat: 468ms
              BPM = 60000 / 468 = 128.2 → 128 bpm
              
10:30:00.010  ESP32: Read all sensors
              heartRate: 128
              spO2: 98
              bodyTemp: 36.8°C
              breathRate: 28 (from pressure sensor)
              motionLevel: 3% (from camera)
              
10:30:00.015  ESP32: Build JSON
              Serialize to Firestore format: 450 bytes
              
10:30:00.020  ESP32: Start HTTP POST
              URL: firestore.googleapis.com/v1/...
              
10:30:00.320  Firebase: Request received
              Validate auth token ✓
              Parse JSON ✓
              
10:30:00.420  Firebase: Write to Firestore
              Collection: devices/AnvayaPod-A1B2/vitalReadings
              Document: auto-generated ID
              
10:30:00.500  Firebase: Update baby document
              Collection: babies/baby_XYZ123
              Field: latestVitals = {...}
              
10:30:00.550  Cloud Function: onVitalsUpdate triggered
              Check heartRate: 128 (normal) ✓
              Check spO2: 98 (normal) ✓
              Check temp: 36.8 (normal) ✓
              No alerts needed
              
10:30:00.600  Flutter: Stream receives update
              VitalsService.subscribeToLatestVitals()
              New snapshot available
              
10:30:00.602  Flutter: Parse to Dart model
              LatestVitals.fromMap(snapshot.data())
              
10:30:00.617  Flutter: Run sleep analysis
              SleepIntelligenceService.analyzeSleepData()
              Calculate: sleepState = ASLEEP
              Calculate: sleepStage = DEEP
              Calculate: confidence = 96%
              
10:30:00.618  Flutter: Update provider
              VitalsProvider._latestVitals = newVitals
              VitalsProvider.notifyListeners()
              
10:30:00.619  Flutter: Rebuild widgets
              Consumer<VitalsProvider> rebuilds
              VitalsCard receives new data
              
10:30:00.635  Flutter: Render frame
              Paint vitals with green indicators
              Show "just now" timestamp
              Show "🟢 Live" status
              
10:30:00.651  USER SEES:
              ╔════════════════════════════════════╗
              ║  Vital Signs          🟢 Live     ║
              ╠════════════════════════════════════╣
              ║  ❤️  Heart Rate    128 bpm  🟢   ║
              ║  🫁  SpO2          98%      🟢   ║
              ║  🌡️  Temperature   36.8°C   🟢   ║
              ║  💨  Breathing     28/min   🟢   ║
              ║  😴  Sleep Stage   DEEP     🌙   ║
              ║                                    ║
              ║  Updated: just now                 ║
              ╚════════════════════════════════════╝

TOTAL LATENCY: 651ms (sensor → screen)
```

---

## 🚦 **ERROR HANDLING & FALLBACKS**

```
FAILURE POINT              DETECTION                  RECOVERY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sensor read fails          No data for 5s             Retry, show stale
WiFi disconnected          HTTP timeout               Retry with backoff
Firebase write fails       Error response             Queue locally
Stream disconnects         No updates                 Auto-reconnect
Parse error                Exception thrown           Use default values
Analysis fails             Null result                Skip, use previous
UI error                   Widget crash               Error boundary
```

---

## 🎨 **VISUALIZATION: DATA TRANSFORMATION**

```
RAW SENSOR     →    JSON         →    FIRESTORE    →    DART MODEL    →    UI
═══════════          ═══════          ═══════════        ═══════════        ═══

2047 ADC       →    "128"       →    128           →    heartRate:    →    128 bpm
(12-bit)            (string)          (int64)            128 (int)          🟢

3.68V          →    "36.8"      →    36.8          →    temperature:  →    36.8°C
(analog)            (string)          (double)           36.8 (double)      🟢

Motion %       →    "3"         →    3             →    motionLevel:  →    😴 DEEP
(0-100)             (string)          (int64)            3 (int)            🌙
```

---

This is the **complete data journey** from sensor to screen! 🎯

Every **1 second**, your system processes a sensor reading through 8 layers of transformation, traveling ~5000 miles across the internet, and appears on the user's screen in **under 1 second**. That's modern cloud architecture! 🚀