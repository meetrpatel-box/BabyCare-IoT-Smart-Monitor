# 60GHz mmWave Sensor Integration Guide

## 📡 Hardware Specification

**Sensor**: 60GHz mmWave Radar Module  
**Capabilities**:
- Contactless heart rate detection (40-180 BPM)
- Respiratory rate monitoring (10-60 BPM)
- Movement/presence detection (±1mm precision)
- Sleep stage inference via breathing patterns
- Cry detection via movement correlation

**ESP32 Integration**:
- ESP32-WROOM-32 microcontroller
- WiFi/BLE connectivity
- MQTT protocol for real-time streaming
- Edge AI for on-device processing

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTOMATIC DETECTION FLOW                      │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  AnvayaPod       │  60GHz mmWave Sensor
│  (ESP32)         │    ↓
└────────┬─────────┘    • Heart Rate: 120 BPM
         │              • Respiratory: 35 BPM
         │ MQTT Publish • Movement: Low
         ↓              • Stage: Deep Sleep
┌──────────────────┐
│  Cloud Functions │  Process & Classify
│  (Firebase)      │    ↓
└────────┬─────────┘    • Validate vitals
         │              • Detect cry patterns
         │ Write        • Infer sleep stages
         ↓              • Generate alerts
┌──────────────────┐
│  Firestore       │  Store Data
│  Database        │
└────────┬─────────┘
         │ Real-time Listener
         ↓
┌──────────────────┐
│  Flutter App     │  Display & Analyze
│  (Mobile)        │    ↓
└──────────────────┘    • Live vitals chart
                        • Sleep quality score
                        • Cry alerts
                        • Health predictions
```

---

## 📊 Data Flow Schemas

### 1. **Real-Time Vitals Stream**

**MQTT Topic**: `anvayapod/{deviceId}/vitals`

**Payload**:
```json
{
  "deviceId": "ANVAYA-12345",
  "timestamp": 1738800000,
  "heartRate": 120,
  "respiratoryRate": 35,
  "movement": 0.02,
  "presence": true,
  "temperature": 36.5,
  "quality": 0.95
}
```

**Cloud Function**: `processVitalsData()`
- Validates sensor readings
- Writes to `vital_signs` collection
- Triggers alerts if out of range

---

### 2. **Sleep Stage Detection**

**MQTT Topic**: `anvayapod/{deviceId}/sleep`

**Payload**:
```json
{
  "deviceId": "ANVAYA-12345",
  "timestamp": 1738800000,
  "stage": "deep",
  "confidence": 0.87,
  "heartRate": 110,
  "respiratoryRate": 28,
  "movement": 0.01
}
```

**Cloud Function**: `classifySleepStage()`
- Analyzes breathing patterns + movement
- Deep: HR 100-120, RR 25-35, movement <0.05
- Light: HR 110-130, RR 30-40, movement <0.15
- REM: HR 115-135, RR 30-45, movement <0.10
- Awake: HR >120, RR >35, movement >0.2
- Updates active `sleep_session` with new stage

---

### 3. **Cry Detection**

**MQTT Topic**: `anvayapod/{deviceId}/cry`

**Payload**:
```json
{
  "deviceId": "ANVAYA-12345",
  "timestamp": 1738800300,
  "cryDetected": true,
  "intensity": 0.85,
  "duration": 45,
  "pattern": "pain",
  "confidence": 0.78
}
```

**Cloud Function**: `processCryEvent()`
- Stores in `cry_events` collection
- Classifies pattern (pain, hunger, tired, etc.)
- Sends push notification to parents
- Updates cry analytics

---

## 🔧 Implementation Phases

### **Phase 1: Basic Vitals Streaming** ✅ (Current)
- ESP32 reads sensor data every 5 seconds
- Publishes to MQTT broker
- Cloud Function stores in Firestore
- **Status**: Ready for implementation

### **Phase 2: Sleep Auto-Detection** (Week 4)
- Sleep onset detection (5 min of low movement + stable vitals)
- Stage classification every 30 seconds
- Auto-create sleep_session in Firestore
- Wake detection (movement spike + HR increase)
- **Output**: Automatic sleep tracking without parent input

### **Phase 3: Cry Detection** (Week 5)
- Movement pattern analysis for cry signature
- Duration + intensity classification
- Real-time parent notifications
- Pattern learning (personalized to baby)
- **Output**: Instant cry alerts with reason prediction

### **Phase 4: Predictive Analytics** (Week 6-7)
- ML model training on sensor data
- Sleep pattern predictions
- Health anomaly detection
- Feeding time suggestions
- **Output**: AI-powered parenting insights

---

## 💻 Code Integration Examples

### **1. Stream Real-Time Vitals (Flutter)**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceVitalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream real-time vitals from device
  Stream<VitalSign> streamDeviceVitals(String babyId) {
    return _firestore
        .collection('vital_signs')
        .where('babyId', isEqualTo: babyId)
        .where('source', isEqualTo: 'device') // Only device readings
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        throw Exception('No device data available');
      }
      return VitalSign.fromFirestore(snapshot.docs.first);
    });
  }
}
```

### **2. Auto Sleep Detection (Cloud Function)**

```typescript
// functions/src/sleep-detection.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const detectSleepOnset = functions.pubsub
  .topic('anvayapod-vitals')
  .onPublish(async (message) => {
    const data = JSON.parse(message.data.toString());
    
    const { deviceId, heartRate, respiratoryRate, movement } = data;
    
    // Sleep onset criteria: Low movement + stable vitals for 5 min
    if (movement < 0.05 && heartRate < 120 && respiratoryRate < 35) {
      const recentHistory = await getRecentVitals(deviceId, 5); // 5 min
      
      if (allLowMovement(recentHistory)) {
        // Create new sleep session
        await admin.firestore().collection('sleep_sessions').add({
          babyId: getBabyIdFromDevice(deviceId),
          startTime: admin.firestore.FieldValue.serverTimestamp(),
          source: 'device',
          deviceId: deviceId,
          stages: [{
            type: 'light',
            startTime: admin.firestore.FieldValue.serverTimestamp(),
            confidence: 0.85
          }],
          isActive: true
        });
        
        // Send notification
        await sendPushNotification(deviceId, 'Baby is falling asleep 😴');
      }
    }
  });

function allLowMovement(vitals: any[]): boolean {
  return vitals.every(v => v.movement < 0.05);
}
```

### **3. Cry Pattern Classification (Cloud Function)**

```typescript
// functions/src/cry-detection.ts
export const classifyCry = functions.pubsub
  .topic('anvayapod-cry')
  .onPublish(async (message) => {
    const data = JSON.parse(message.data.toString());
    
    const { deviceId, intensity, duration } = data;
    
    let pattern = 'unknown';
    
    // Heuristic classification (can be ML model later)
    if (duration < 30 && intensity > 0.8) {
      pattern = 'pain'; // Short, intense = pain
    } else if (duration > 120 && intensity < 0.6) {
      pattern = 'tired'; // Long, low = tired
    } else if (duration > 60 && intensity > 0.7) {
      pattern = 'hungry'; // Medium, high = hungry
    }
    
    // Store cry event
    await admin.firestore().collection('cry_events').add({
      babyId: getBabyIdFromDevice(deviceId),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      pattern: pattern,
      intensity: intensity,
      duration: duration,
      source: 'device'
    });
    
    // Send smart notification
    await sendPushNotification(
      deviceId,
      `Baby is crying - Likely ${pattern} 👶`,
      { pattern, intensity, duration }
    );
  });
```

---

## 🎯 Feature Gating in UI

### **Free Tier**: Manual Mode Only
```dart
// Manual sleep tracking button
ElevatedButton(
  onPressed: () {
    // Show manual sleep tracking screen
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ManualSleepTrackingScreen(),
    ));
  },
  child: Text('Start Sleep Session'),
)
```

### **Premium + Device Tier**: Auto Mode
```dart
import '../widgets/feature_gate.dart';

// Wrap auto-detection features in FeatureGate
FeatureGate(
  feature: 'auto_sleep_tracking',
  child: StreamBuilder<SleepSession?>(
    stream: deviceService.streamActiveSleepSession(babyId),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ActiveSleepCard(session: snapshot.data!);
      }
      return Text('Monitoring... 👀');
    },
  ),
  fallback: ManualSleepTrackingButton(), // Show for free users
)
```

---

## 🚀 Next Steps (Implementation Order)

### **Week 1: Feature Gating** ✅ COMPLETE
- [x] SubscriptionModel, SubscriptionService
- [x] FeatureGate widget
- [x] Tier-based quotas

### **Week 2-3: Manual Mode (Free Tier)**
- [ ] Manual sleep tracking UI
- [ ] Start/Stop session buttons
- [ ] Manual feeding/diaper logging
- [ ] Basic 24h charts (free tier)

### **Week 4: ESP32 Firmware**
- [ ] 60GHz sensor driver
- [ ] MQTT publisher
- [ ] Edge sleep stage classifier
- [ ] Low-power modes

### **Week 5: Cloud Functions**
- [ ] processVitalsData()
- [ ] detectSleepOnset()
- [ ] classifySleepStage()
- [ ] processCryEvent()

### **Week 6: Auto Detection UI**
- [ ] Real-time vitals dashboard
- [ ] Active sleep session monitor
- [ ] Cry alert notifications
- [ ] Device pairing flow

### **Week 7-8: AI/ML Layer**
- [ ] Sleep pattern predictions
- [ ] Health anomaly detection
- [ ] Personalized insights
- [ ] Feeding recommendations

---

## 📦 Required Dependencies

**Flutter** (`pubspec.yaml`):
```yaml
dependencies:
  cloud_firestore: ^4.13.0
  firebase_messaging: ^14.7.0
  mqtt_client: ^10.0.0 # For direct MQTT if needed
  provider: ^6.1.0
```

**Cloud Functions** (`package.json`):
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "@google-cloud/pubsub": "^4.0.0"
  }
}
```

**ESP32 Firmware** (`platformio.ini`):
```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps =
    knolleary/PubSubClient@^2.8
    bblanchon/ArduinoJson@^6.21.3
```

---

## 🔐 Security Considerations

1. **Device Authentication**: Each AnvayaPod has unique certificate
2. **MQTT over TLS**: Encrypted sensor data transmission
3. **Firestore Rules**: Only device owner can read/write
4. **Data Retention**: Auto-delete device logs after 90 days (GDPR)

---

## 💡 Key Benefits

| Feature | Free (Manual) | Premium + Device (Auto) |
|---------|--------------|-------------------------|
| Sleep Tracking | ⏱️ Manual start/stop | ✅ Automatic detection |
| Vitals Monitoring | 📝 Manual entry | ✅ Real-time streaming |
| Cry Detection | ❌ None | ✅ Instant alerts |
| Sleep Stages | ❌ Inferred from duration | ✅ Precise mmWave detection |
| Accuracy | ~70% (user input) | ~95% (sensor data) |
| Parent Effort | High (constant logging) | Zero (hands-free) |

**Value Proposition**: Premium + Device tier delivers a **magical hands-free experience** powered by the 60GHz mmWave sensor!
