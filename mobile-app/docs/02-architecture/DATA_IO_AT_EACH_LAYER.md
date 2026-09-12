# 📡 Data Input/Output at Each Layer

**System**: BabyCareApp Data Flow  
**Date**: February 2, 2026  
**Focus**: What data goes IN and OUT at each system boundary

---

## 🎯 OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER BOUNDARIES                         │
└─────────────────────────────────────────────────────────────┘

Layer 1: FIRMWARE (ESP32)
  INPUT:  Raw sensor readings (voltage, ADC values)
  OUTPUT: JSON payload via HTTPS POST
           ↓
Layer 2: CLOUD (Firebase)
  INPUT:  HTTP request with JSON
  STORAGE: Firestore document
  OUTPUT: Firestore document via WebSocket stream
           ↓
Layer 3: APP (Flutter)
  INPUT:  Firestore snapshot (JSON-like map)
  PROCESSING: Dart objects + algorithms
  OUTPUT: UI widgets with computed values
           ↓
Layer 4: USER SCREEN
  INPUT:  Widget tree
  OUTPUT: Pixels on display
```

---

## 1️⃣ FIRMWARE LAYER (ESP32)

### **INPUT: Raw Sensor Readings**

```cpp
// What the ESP32 receives from physical sensors
// ════════════════════════════════════════════════════════════

SENSOR: MAX30102 (Heart Rate + SpO2)
─────────────────────────────────────────────────────────────
INPUT TYPE:     I2C digital values
DATA FORMAT:    18-bit unsigned integers
SAMPLE RATE:    100 Hz (100 samples/second)

Example reading:
  irValue = 95847      // IR LED photodiode reading (0-262143)
  redValue = 81203     // Red LED photodiode reading (0-262143)

SENSOR: MLX90614 (IR Temperature)
─────────────────────────────────────────────────────────────
INPUT TYPE:     I2C digital values
DATA FORMAT:    16-bit, 0.02°C resolution
SAMPLE RATE:    1 Hz (1 sample/second)

Example reading:
  rawTemp = 1835       // Raw 16-bit value
  // Converted: (1835 * 0.02) - 273.15 = 36.7°C

SENSOR: Pressure Mat (Breath Rate)
─────────────────────────────────────────────────────────────
INPUT TYPE:     Analog voltage
DATA FORMAT:    12-bit ADC (0-4095)
SAMPLE RATE:    50 Hz

Example reading:
  pressureADC = 2347   // ADC value
  // Voltage: (2347 / 4095) × 3.3V = 1.89V
  // Calibrated pressure: 1.89V → chest rising

SENSOR: ESP32-CAM (Motion)
─────────────────────────────────────────────────────────────
INPUT TYPE:     Image buffer
DATA FORMAT:    320×240 grayscale pixels (8-bit each)
SAMPLE RATE:    10 FPS

Example frame:
  uint8_t frame[76800];  // 320 × 240 = 76,800 bytes
  frame[0] = 142         // Top-left pixel brightness (0-255)
  frame[1] = 138
  // ... 76,798 more pixels

SENSOR: DHT22 (Humidity + Ambient Temp)
─────────────────────────────────────────────────────────────
INPUT TYPE:     Digital pulses (1-wire protocol)
DATA FORMAT:    40-bit data (16-bit humidity, 16-bit temp, 8-bit checksum)
SAMPLE RATE:    0.5 Hz (every 2 seconds)

Example reading:
  rawHumidity = 480    // Raw value
  rawTemp = 223        // Raw value
  // Humidity: 480 / 10 = 48.0%
  // Temp: 223 / 10 = 22.3°C
```

### **PROCESSING: Sensor Data → Measurements**

```cpp
// ESP32 processes raw sensor data into meaningful values
// ════════════════════════════════════════════════════════════

struct VitalReading {
  uint32_t timestamp;        // INPUT: millis()
  uint16_t heartRate;        // COMPUTED: From IR peaks
  uint8_t  spO2;             // COMPUTED: From IR/Red ratio
  float    bodyTemp;         // COMPUTED: From IR sensor
  float    envTemp;          // COMPUTED: From DHT22
  uint8_t  breathRate;       // COMPUTED: From pressure peaks
  uint8_t  motionLevel;      // COMPUTED: From frame diff
  uint8_t  cryDetected;      // COMPUTED: From mic amplitude
  uint32_t humidity;         // COMPUTED: From DHT22
  uint16_t noiseLevel;       // COMPUTED: From mic ADC
  uint8_t  ledBrightness;    // INPUT: PWM duty cycle
  uint8_t  deviceStatus;     // COMPUTED: System flags
  uint32_t checksum;         // COMPUTED: CRC32
};

// ACTUAL VALUES AT 8:30 PM
VitalReading reading = {
  .timestamp      = 1738526400000,   // Unix epoch milliseconds
  .heartRate      = 125,             // BPM (from IR peaks)
  .spO2           = 98,              // Percentage
  .bodyTemp       = 36.7,            // Celsius (float)
  .envTemp        = 22.3,            // Celsius
  .breathRate     = 30,              // Breaths per minute
  .motionLevel    = 2,               // Percentage (0-100)
  .cryDetected    = 0,               // Boolean (0 or 1)
  .humidity       = 4800,            // Humidity × 100 (48.00%)
  .noiseLevel     = 350,             // dB × 10 (35.0 dB)
  .ledBrightness  = 128,             // PWM 0-255
  .deviceStatus   = 0b00000001,      // Bit flags
  .checksum       = 0x1A2B3C4D       // CRC32
};
```

### **OUTPUT: JSON Payload for Firebase**

```cpp
// ESP32 converts struct to Firestore REST API JSON format
// ════════════════════════════════════════════════════════════

StaticJsonDocument<1024> doc;

// Build Firestore-specific JSON
doc["fields"]["deviceId"]["stringValue"] = "AnvayaPod-A1B2";
doc["fields"]["babyId"]["stringValue"] = "baby_Emma_123";
doc["fields"]["timestamp"]["integerValue"] = "1738526400000";

auto vitals = doc["fields"]["vitals"]["mapValue"]["fields"];
vitals["heartRate"]["integerValue"] = "125";
vitals["spO2"]["integerValue"] = "98";
vitals["bodyTemp"]["doubleValue"] = 36.7;
vitals["envTemp"]["doubleValue"] = 22.3;
vitals["breathRate"]["integerValue"] = "30";
vitals["motionLevel"]["integerValue"] = "2";
vitals["cryDetected"]["booleanValue"] = false;
vitals["humidity"]["doubleValue"] = 48.0;
vitals["noiseLevel"]["doubleValue"] = 35.0;

String jsonPayload;
serializeJson(doc, jsonPayload);

// FIRMWARE OUTPUT (What ESP32 sends):
// ════════════════════════════════════════════════════════════
```

```json
{
  "fields": {
    "deviceId": {
      "stringValue": "AnvayaPod-A1B2"
    },
    "babyId": {
      "stringValue": "baby_Emma_123"
    },
    "timestamp": {
      "integerValue": "1738526400000"
    },
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {
            "integerValue": "125"
          },
          "spO2": {
            "integerValue": "98"
          },
          "bodyTemp": {
            "doubleValue": 36.7
          },
          "envTemp": {
            "doubleValue": 22.3
          },
          "breathRate": {
            "integerValue": "30"
          },
          "motionLevel": {
            "integerValue": "2"
          },
          "cryDetected": {
            "booleanValue": false
          },
          "humidity": {
            "doubleValue": 48.0
          },
          "noiseLevel": {
            "doubleValue": 35.0
          }
        }
      }
    }
  }
}
```

**Size:** ~486 bytes (JSON string)

---

## 2️⃣ CLOUD LAYER (Firebase)

### **INPUT: HTTP Request from Firmware**

```http
POST /v1/projects/babytrack-prod/databases/(default)/documents/devices/AnvayaPod-A1B2/vitalReadings HTTP/1.1
Host: firestore.googleapis.com
Content-Type: application/json
Content-Length: 486
Authorization: Bearer ya29.a0AfH6SMBxxx...

{
  "fields": {
    "deviceId": {"stringValue": "AnvayaPod-A1B2"},
    "babyId": {"stringValue": "baby_Emma_123"},
    "timestamp": {"integerValue": "1738526400000"},
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {"integerValue": "125"},
          "spO2": {"integerValue": "98"},
          "bodyTemp": {"doubleValue": 36.7},
          "envTemp": {"doubleValue": 22.3},
          "breathRate": {"integerValue": "30"},
          "motionLevel": {"integerValue": "2"},
          "cryDetected": {"booleanValue": false},
          "humidity": {"doubleValue": 48.0},
          "noiseLevel": {"doubleValue": 35.0}
        }
      }
    }
  }
}
```

### **STORAGE: Firestore Document (Internal Format)**

```javascript
// What Firebase stores internally (simplified)
// ════════════════════════════════════════════════════════════

Collection: devices/AnvayaPod-A1B2/vitalReadings
Document ID: auto_generated_xyz123

{
  // Stored as typed fields in Firestore
  deviceId: "AnvayaPod-A1B2",           // string
  babyId: "baby_Emma_123",              // string
  timestamp: 1738526400000,             // int64
  vitals: {                             // map
    heartRate: 125,                     // int64
    spO2: 98,                           // int64
    bodyTemp: 36.7,                     // double
    envTemp: 22.3,                      // double
    breathRate: 30,                     // int64
    motionLevel: 2,                     // int64
    cryDetected: false,                 // boolean
    humidity: 48.0,                     // double
    noiseLevel: 35.0                    // double
  },
  // Firebase adds system fields
  serverTimestamp: Timestamp(seconds: 1738526400, nanoseconds: 123456789)
}

// ALSO UPDATES (triggered by Cloud Function):
Collection: babies
Document ID: baby_Emma_123

{
  id: "baby_Emma_123",
  name: "Emma",
  birthDate: Timestamp(...),
  parentIds: ["user_mom_123", "user_dad_456"],
  
  // Latest vitals field (updated on every reading)
  latestVitals: {
    heartRate: 125,
    spO2: 98,
    temperature: 36.7,
    envTemperature: 22.3,
    breathRate: 30,
    motionLevel: 2,
    cryDetected: false,
    humidity: 48.0,
    noiseLevel: 35.0,
    timestamp: Timestamp(seconds: 1738526400, nanoseconds: 123456789)
  },
  
  updatedAt: Timestamp(...)
}
```

### **OUTPUT: Firestore Stream to Flutter (WebSocket)**

```json
// What Firebase sends to Flutter app via WebSocket stream
// ════════════════════════════════════════════════════════════

{
  "documentChange": {
    "document": {
      "name": "projects/babytrack-prod/databases/(default)/documents/babies/baby_Emma_123",
      "fields": {
        "id": {
          "stringValue": "baby_Emma_123"
        },
        "name": {
          "stringValue": "Emma"
        },
        "latestVitals": {
          "mapValue": {
            "fields": {
              "heartRate": {
                "integerValue": "125"
              },
              "spO2": {
                "integerValue": "98"
              },
              "temperature": {
                "doubleValue": 36.7
              },
              "envTemperature": {
                "doubleValue": 22.3
              },
              "breathRate": {
                "integerValue": "30"
              },
              "motionLevel": {
                "integerValue": "2"
              },
              "cryDetected": {
                "booleanValue": false
              },
              "humidity": {
                "doubleValue": 48.0
              },
              "noiseLevel": {
                "doubleValue": 35.0
              },
              "timestamp": {
                "timestampValue": "2026-02-02T20:00:00.123456Z"
              }
            }
          }
        },
        "updatedAt": {
          "timestampValue": "2026-02-02T20:00:00.456789Z"
        }
      },
      "createTime": "2026-01-15T10:00:00.000000Z",
      "updateTime": "2026-02-02T20:00:00.456789Z"
    },
    "targetIds": [1]
  }
}
```

**Size:** ~850 bytes (with metadata)

---

## 3️⃣ APP LAYER (Flutter)

### **INPUT: Firestore Snapshot**

```dart
// What Flutter receives from Firestore stream
// ════════════════════════════════════════════════════════════

// VitalsService listening to stream
Stream<DocumentSnapshot> babyStream = FirebaseFirestore.instance
  .collection('babies')
  .doc('baby_Emma_123')
  .snapshots();

// When stream emits, Flutter receives DocumentSnapshot:
babyStream.listen((DocumentSnapshot snapshot) {
  
  // SNAPSHOT DATA (input to app):
  Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
  
  print(data);
  // Output:
  {
    'id': 'baby_Emma_123',
    'name': 'Emma',
    'birthDate': Timestamp(seconds: 1696204800, nanoseconds: 0),
    'parentIds': ['user_mom_123', 'user_dad_456'],
    'latestVitals': {
      'heartRate': 125,                    // int (Dart int64)
      'spO2': 98,                          // int
      'temperature': 36.7,                 // double (Dart double)
      'envTemperature': 22.3,              // double
      'breathRate': 30,                    // int
      'motionLevel': 2,                    // int
      'cryDetected': false,                // bool
      'humidity': 48.0,                    // double
      'noiseLevel': 35.0,                  // double
      'timestamp': Timestamp(seconds: 1738526400, nanoseconds: 123456789)
    },
    'updatedAt': Timestamp(seconds: 1738526400, nanoseconds: 456789000)
  }
});
```

### **PROCESSING: Map → Dart Object**

```dart
// Flutter converts Map to typed Dart object
// ════════════════════════════════════════════════════════════

class LatestVitals {
  final int heartRate;
  final int spO2;
  final double temperature;
  final double envTemperature;
  final int breathRate;
  final int motionLevel;
  final bool cryDetected;
  final double humidity;
  final double noiseLevel;
  final DateTime timestamp;
  
  factory LatestVitals.fromMap(Map<String, dynamic> map) {
    return LatestVitals(
      heartRate: map['heartRate'] as int,           // 125
      spO2: map['spO2'] as int,                     // 98
      temperature: (map['temperature'] as num).toDouble(),  // 36.7
      envTemperature: (map['envTemperature'] as num).toDouble(),  // 22.3
      breathRate: map['breathRate'] as int,         // 30
      motionLevel: map['motionLevel'] as int,       // 2
      cryDetected: map['cryDetected'] as bool,      // false
      humidity: (map['humidity'] as num).toDouble(),        // 48.0
      noiseLevel: (map['noiseLevel'] as num).toDouble(),    // 35.0
      timestamp: (map['timestamp'] as Timestamp).toDate(),  // DateTime
    );
  }
}

// CREATE DART OBJECT:
LatestVitals vitals = LatestVitals.fromMap(data['latestVitals']);

// RESULT - Typed Dart object in memory:
// ════════════════════════════════════════════════════════════
LatestVitals {
  heartRate: 125,                                   // int (8 bytes in memory)
  spO2: 98,                                         // int (8 bytes)
  temperature: 36.7,                                // double (8 bytes)
  envTemperature: 22.3,                             // double (8 bytes)
  breathRate: 30,                                   // int (8 bytes)
  motionLevel: 2,                                   // int (8 bytes)
  cryDetected: false,                               // bool (1 byte + padding)
  humidity: 48.0,                                   // double (8 bytes)
  noiseLevel: 35.0,                                 // double (8 bytes)
  timestamp: DateTime(2026, 2, 2, 20, 0, 0, 123)   // DateTime object (~24 bytes)
}

// Total object size in heap: ~100 bytes + Dart object overhead (~32 bytes) = ~132 bytes
```

### **PROCESSING: Run Sleep Analysis Algorithm**

```dart
// Flutter processes vitals through sleep intelligence algorithms
// ════════════════════════════════════════════════════════════

// INPUT: LatestVitals object
SleepAnalysisResult result = SleepIntelligenceService.analyzeSleepData(
  vitals,
  historyBuffer
);

// ALGORITHM COMPUTATIONS:
// ─────────────────────────────────────────────────────────────

// 1. Sleep State Score
double score = 0.0;
score += (vitals.breathRate < 35) ? 30.0 : 0.0;        // 30 < 35 → +30
score += (vitals.temperature < 37.0) ? 25.0 : 0.0;     // 36.7 < 37 → +25
score += (vitals.motionLevel < 5) ? 30.0 : 0.0;        // 2 < 5 → +30
score += (vitals.heartRate < 140) ? 15.0 : 0.0;        // 125 < 140 → +15
// score = 100

// 2. Breath Variability
List<int> recentBreaths = [30, 31, 29, 30, 30, 31, 29, 30];
double mean = 30.0;
double variance = 0.67;
double stdDev = 0.82;

// 3. Sleep Stage Classification
double deepScore = 1.0;
double lightScore = 0.65;
double remScore = 0.0;
SleepStage stage = SleepStage.DEEP;  // Highest score

// OUTPUT: SleepAnalysisResult object
SleepAnalysisResult {
  sleepState: SleepState.ASLEEP,
  sleepStage: SleepStage.DEEP,
  stateScore: 100.0,
  stageConfidence: 1.0,
  breathVariability: 0.82,
  timestamp: DateTime(2026, 2, 2, 20, 0, 0)
}
```

### **PROCESSING: Update UI State (Provider)**

```dart
// Provider receives data and notifies UI
// ════════════════════════════════════════════════════════════

class VitalsProvider extends ChangeNotifier {
  LatestVitals? _latestVitals;
  SleepAnalysisResult? _sleepAnalysis;
  List<LatestVitals> _history = [];
  
  // Stream subscription updates state
  void _onVitalsUpdate(LatestVitals vitals) {
    // INPUTS:
    // vitals = LatestVitals object from Firestore
    
    // PROCESSING:
    _latestVitals = vitals;
    _history.add(vitals);
    if (_history.length > 60) _history.removeAt(0);
    
    _sleepAnalysis = SleepIntelligenceService.analyzeSleepData(
      vitals,
      _history
    );
    
    // OUTPUT: Trigger UI rebuild
    notifyListeners();  // <-- This updates all listening widgets
  }
  
  // PROVIDER STATE (what UI can access):
  // ════════════════════════════════════════════════════════════
  LatestVitals get latestVitals => _latestVitals!;
  SleepAnalysisResult get sleepAnalysis => _sleepAnalysis!;
  List<LatestVitals> get history => _history;
  
  // Computed getters for UI
  String get heartRateStatus {
    if (_latestVitals == null) return 'Unknown';
    if (_latestVitals!.heartRate >= 100 && _latestVitals!.heartRate <= 160) {
      return 'Normal';
    }
    return 'Alert';
  }
  
  Color get heartRateColor {
    return heartRateStatus == 'Normal' ? Colors.green : Colors.red;
  }
  
  String get sleepStageDisplay {
    if (_sleepAnalysis == null) return 'Unknown';
    switch (_sleepAnalysis!.sleepStage) {
      case SleepStage.DEEP:
        return 'Deep Sleep 🌙';
      case SleepStage.LIGHT:
        return 'Light Sleep 😴';
      case SleepStage.REM:
        return 'REM Sleep 👁️';
      case SleepStage.AWAKE:
        return 'Awake 😊';
    }
  }
}
```

### **OUTPUT: UI Widget Data**

```dart
// What the UI widgets receive and display
// ════════════════════════════════════════════════════════════

class VitalsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, provider, child) {
        
        // WIDGET INPUTS (from Provider):
        // ─────────────────────────────────────────────────────
        final vitals = provider.latestVitals;
        final analysis = provider.sleepAnalysis;
        final heartRateColor = provider.heartRateColor;
        final sleepStage = provider.sleepStageDisplay;
        
        // Values available to widget:
        int heartRate = vitals.heartRate;              // 125
        int spO2 = vitals.spO2;                        // 98
        double temperature = vitals.temperature;        // 36.7
        int breathRate = vitals.breathRate;            // 30
        int motionLevel = vitals.motionLevel;          // 2
        String stage = sleepStage;                     // "Deep Sleep 🌙"
        Color color = heartRateColor;                  // Colors.green
        
        // WIDGET OUTPUT (rendered to screen):
        return Card(
          child: Column(
            children: [
              // Heart Rate Display
              ListTile(
                leading: Icon(Icons.favorite, color: color),
                title: Text('Heart Rate'),
                subtitle: Text('$heartRate bpm'),  // "125 bpm"
                trailing: Icon(Icons.check_circle, color: color),
              ),
              
              // SpO2 Display
              ListTile(
                leading: Icon(Icons.air),
                title: Text('Blood Oxygen'),
                subtitle: Text('$spO2%'),  // "98%"
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              
              // Temperature Display
              ListTile(
                leading: Icon(Icons.thermostat),
                title: Text('Temperature'),
                subtitle: Text('${temperature.toStringAsFixed(1)}°C'),  // "36.7°C"
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              
              // Breathing Display
              ListTile(
                leading: Icon(Icons.waves),
                title: Text('Breathing'),
                subtitle: Text('$breathRate/min'),  // "30/min"
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              
              // Sleep Stage Display
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(Icons.bedtime, size: 32),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sleep Stage', style: TextStyle(fontSize: 12)),
                        Text(stage, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        // "Deep Sleep 🌙"
                      ],
                    ),
                  ],
                ),
              ),
              
              // Live Indicator
              Container(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Live - Updated just now', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## 4️⃣ SCREEN LAYER (Display Output)

### **OUTPUT: Rendered Pixels**

```
┌─────────────────────────────────────────────────────────────┐
│  Vital Signs                                    🟢 Live     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ❤️  Heart Rate                              125 bpm  ✓   │
│     Normal range                                            │
│                                                             │
│  🫁  Blood Oxygen                             98%     ✓   │
│     Excellent                                               │
│                                                             │
│  🌡️  Temperature                             36.7°C   ✓   │
│     Normal                                                  │
│                                                             │
│  💨  Breathing                                30/min   ✓   │
│     Slow and steady                                         │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  🌙  Sleep Stage                                      │ │
│  │      Deep Sleep 🌙                                    │ │
│  │      Confidence: 100%                                 │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  🟢 Live - Updated just now                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**What user sees:**
- Text: "125 bpm", "98%", "36.7°C", "30/min", "Deep Sleep 🌙"
- Icons: ❤️, 🫁, 🌡️, 💨, 🌙
- Colors: Green checkmarks (RGB: 76, 175, 80)
- Status: "Live" with green dot
- Timestamp: "just now"

---

## 📊 COMPLETE DATA TRANSFORMATION SUMMARY

### **Data Journey: Sensor → Screen**

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER           INPUT                    OUTPUT            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SENSOR          95,847 (IR ADC)    →    125 bpm           │
│  (MAX30102)                                                 │
│                                                             │
│  FIRMWARE        125 bpm            →    "integerValue":   │
│  (ESP32)         36.7°C                  "125"             │
│                  30 bpm                  JSON ~486 bytes   │
│                                                             │
│  NETWORK         JSON payload       →    HTTP POST         │
│  (WiFi)          486 bytes               ~750 bytes        │
│                                                             │
│  CLOUD           HTTP request       →    Firestore doc     │
│  (Firebase)      JSON                    Typed storage     │
│                                          + indexes          │
│                                                             │
│  STREAM          Document update    →    WebSocket push    │
│  (WebSocket)     Firestore                JSON ~850 bytes  │
│                                                             │
│  APP INPUT       JSON map           →    Dart object       │
│  (Flutter)       Map<String,dynamic>     LatestVitals      │
│                                          ~132 bytes         │
│                                                             │
│  PROCESSING      LatestVitals       →    Sleep analysis    │
│  (Algorithms)    + history               SleepStage.DEEP   │
│                                          score: 100         │
│                                                             │
│  STATE MGMT      Analysis result    →    Provider state    │
│  (Provider)      SleepAnalysisResult     notifyListeners() │
│                                                             │
│  UI BUILD        Provider values    →    Widget tree       │
│  (Widgets)       heartRate: 125          Text("125 bpm")   │
│                  stage: DEEP             Icon(🌙)          │
│                                                             │
│  RENDER          Widget tree        →    Pixels on screen  │
│  (Engine)        Dart objects            RGB values         │
│                                          60 FPS             │
│                                                             │
│  DISPLAY         Frame buffer       →    Visual output     │
│  (Screen)        GPU memory              "125 bpm" text    │
│                                          Green checkmarks   │
│                                                             │
└─────────────────────────────────────────────────────────────┘

TOTAL TRANSFORMATIONS: 11 layers
TOTAL LATENCY: ~700ms (sensor reading → user's eyes)
DATA AMPLIFICATION: 8 bytes (raw sensor) → 750 bytes (network) → 132 bytes (app) → pixels
```

---

## 🎯 KEY INSIGHTS

### **Data Type Transformations**

```
FIRMWARE:  uint16_t (2 bytes)          → Heart rate integer
           ↓
NETWORK:   "integerValue": "125"       → JSON string (14 chars)
           ↓
CLOUD:     int64 (8 bytes)             → Firestore integer type
           ↓
APP:       int (8 bytes in Dart)       → Dart int64
           ↓
UI:        String "125 bpm"            → Display text
           ↓
SCREEN:    Pixels forming "125"        → Visual output
```

### **Size at Each Layer**

| Layer         | Format          | Size        | Reason                        |
|---------------|-----------------|-------------|-------------------------------|
| Sensor        | Binary          | 8 bytes     | Raw ADC values                |
| Firmware RAM  | C struct        | 32 bytes    | Packed structure              |
| JSON payload  | String          | 486 bytes   | Text encoding + type metadata |
| HTTP packet   | TCP/IP          | 750 bytes   | Headers + TLS overhead        |
| Firestore     | Protocol Buffer | ~500 bytes  | Compressed storage            |
| Stream        | JSON            | 850 bytes   | With document metadata        |
| Dart object   | Object          | 132 bytes   | Object overhead + fields      |
| Widget state  | Objects         | ~200 bytes  | Widget tree + styling         |

### **Processing at Each Boundary**

1. **Sensor → Firmware**: ADC conversion, peak detection, averaging
2. **Firmware → Network**: JSON serialization, Firestore type wrapping
3. **Network → Cloud**: HTTP parsing, authentication, validation
4. **Cloud → Storage**: Protocol Buffer encoding, index updates
5. **Storage → Stream**: WebSocket protocol, JSON formatting
6. **Stream → App**: JSON parsing, type conversion
7. **App → State**: Algorithm processing, object creation
8. **State → UI**: Widget building, styling, layout
9. **UI → Screen**: Rendering, rasterization, GPU upload

**This is the complete INPUT/OUTPUT flow!** 🚀

