# 📊 Sleep Analysis System - Complete Guide

## Overview
The Sleep Analysis system uses **mmWave sensor data** from the Anavaya device to automatically detect sleep stages, calculate quality scores, and provide actionable insights for parents.

---

## 🔄 Data Flow Architecture

### **End-to-End Flow: Device → Dashboard**

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEVICE LAYER (ESP32)                        │
└─────────────────────────────────────────────────────────────────┘
         ↓
[60GHz mmWave Sensor] → Detects:
  • Respiratory rate (breaths/min)
  • Heart rate (beats/min) 
  • Movement intensity (0.0-1.0)
  • Presence detection (baby in crib)
         ↓
[ESP32 Firmware] samples at 1 Hz (every 1 second)
         ↓
[MQTT Publisher] → Publishes to topic: `devices/{deviceId}/vitals`
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                     CLOUD LAYER (Firebase)                      │
└─────────────────────────────────────────────────────────────────┘
         ↓
[Cloud Function: onVitalsReceived] → Triggered by MQTT message
         ↓
    • Validates sensor data
    • Detects sleep state changes
    • Creates sleep session if baby falls asleep
    • Appends sensor reading to session
         ↓
[Firestore: /sleep_sessions/{sessionId}/sensor_readings/{timestamp}]
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                     APP LAYER (Flutter)                         │
└─────────────────────────────────────────────────────────────────┘
         ↓
[Real-time Stream] → Listens to active sleep session
         ↓
[SleepAnalysisService] → When session ends:
    • Fetches all sensor readings
    • Runs sleep stage detection algorithm
    • Calculates quality score
    • Computes sleep efficiency
    • Updates session with analysis
         ↓
[Sleep Analytics Dashboard] → Displays:
    • Sleep timeline chart (stages over time)
    • Quality score (0-100)
    • Sleep stage distribution (Light/Deep/REM)
    • Awakenings count
    • Trends over 7 days
```

---

## 💾 Firestore Data Structure

### Collection: `sleep_sessions/{sessionId}`

```js
sleep_sessions/session-abc123
{
  "id": "session-abc123",
  "babyId": "baby-xyz789",
  "userId": "user-123",
  "deviceId": "ANVAYA-PRO-12345",
  
  // Timing
  "startTime": Timestamp(2026-02-09 20:00:00),
  "endTime": Timestamp(2026-02-10 07:30:00), // null if active
  "isAutoDetected": true, // Device detected vs manual
  
  // Analysis results (populated after session ends)
  "qualityScore": 82.5, // 0-100
  "awakenings": 3,
  "timeToSleep": 900, // seconds (15 min)
  "sleepEfficiency": 87.5, // percentage
  
  "lightSleepDuration": 21600, // seconds (6 hours)
  "deepSleepDuration": 14400, // seconds (4 hours)
  "remSleepDuration": 5400, // seconds (1.5 hours)
  
  // Sleep stage timeline
  "stages": [
    {
      "stage": "awake",
      "startTime": Timestamp(2026-02-09 20:00:00),
      "endTime": Timestamp(2026-02-09 20:15:00),
      "avgRespiratoryRate": 40.2,
      "avgHeartRate": 130.5,
      "avgMovement": 0.65
    },
    {
      "stage": "light",
      "startTime": Timestamp(2026-02-09 20:15:00),
      "endTime": Timestamp(2026-02-09 21:30:00),
      "avgRespiratoryRate": 35.1,
      "avgHeartRate": 115.2,
      "avgMovement": 0.12
    },
    {
      "stage": "deep",
      "startTime": Timestamp(2026-02-09 21:30:00),
      "endTime": Timestamp(2026-02-09 23:00:00),
      "avgRespiratoryRate": 28.5,
      "avgHeartRate": 95.8,
      "avgMovement": 0.03
    },
    // ... more stages
  ],
  
  "isAnalyzed": true,
  "analyzedAt": Timestamp(2026-02-10 07:35:00)
}
```

### Subcollection: `sleep_sessions/{sessionId}/sensor_readings/{timestamp}`

```js
sensor_readings/1707516000
{
  "timestamp": Timestamp(2026-02-09 20:00:00),
  "respiratoryRate": 38.5, // breaths/min
  "heartRate": 125.2, // beats/min (optional)
  "movementIntensity": 0.45, // 0.0-1.0
  "presence": 1.0 // 0.0-1.0 (baby detected)
}
```

**Storage Pattern**: 
- **1 reading per second** = 3,600 readings/hour
- **10-hour sleep session** = 36,000 readings
- **30 days of data** = ~10M readings (manageable with TTL cleanup)

---

## 🧠 Sleep Stage Detection Algorithm

### **Algorithm: Classify Sleep Stage from Sensor Data**

```dart
SleepStage _classifySleepStage(SensorReading reading) {
  // High movement = awake
  if (reading.movementIntensity > 0.4) {
    return SleepStage.awake;
  }
  
  // Very low movement + irregular breathing = REM
  if (reading.movementIntensity < 0.1 && 
      reading.respiratoryRate > 35) {
    return SleepStage.rem;
  }
  
  // Very low movement + slow breathing = deep sleep
  if (reading.movementIntensity < 0.05 && 
      reading.respiratoryRate < 30) {
    return SleepStage.deep;
  }
  
  // Default to light sleep
  return SleepStage.light;
}
```

### **Sleep Stage Characteristics (Infants)**

| Stage | Movement | Respiratory Rate | Heart Rate | Typical Duration |
|-------|----------|------------------|------------|------------------|
| **Awake** | High (>0.4) | 38-45 bpm | 120-160 bpm | Variable |
| **Light Sleep** | Low (0.1-0.4) | 30-38 bpm | 100-120 bpm | 50% of sleep |
| **Deep Sleep** | Very Low (<0.05) | 25-30 bpm | 90-100 bpm | 25% of sleep |
| **REM Sleep** | Low (<0.1) | 35-42 bpm | 110-130 bpm | 25% of sleep |

---

## 📈 Quality Score Calculation

### **Algorithm: Calculate Sleep Quality (0-100)**

```dart
double _calculateQualityScore(List<SleepStageSegment> stages) {
  double score = 100; // Start at perfect
  
  // 1. Total sleep time penalty
  final totalTime = stages.totalDuration;
  if (totalTime.inHours < 12) { // Infants need 12-16h
    score -= (12 - totalTime.inHours) * 3; // -3 per hour
  }
  
  // 2. Awakenings penalty
  final awakenings = countAwakenings(stages);
  score -= awakenings * 2; // -2 per awakening
  
  // 3. Deep sleep percentage check
  final deepPercentage = (deepSleepTime / totalTime) * 100;
  if (deepPercentage < 15) { // Healthy: 20-25%
    score -= (15 - deepPercentage) * 2;
  }
  
  // 4. Sleep fragmentation penalty
  final stageChanges = stages.length;
  if (stageChanges > 20) { // Too fragmented
    score -= (stageChanges - 20) * 0.5;
  }
  
  return score.clamp(0, 100);
}
```

### **Quality Rating Scale**

| Score | Rating | Color | Meaning |
|-------|--------|-------|---------|
| 80-100 | Excellent | Green | Optimal sleep quality |
| 65-79 | Good | Light Green | Healthy sleep |
| 50-64 | Fair | Amber | Could be improved |
| 0-49 | Poor | Red | Needs attention |

---

## 🎨 Dashboard Components

### **1. Weekly Summary Card**
```
┌────────────────────────────────────────┐
│  📅 Last 7 Days Summary                │
├────────────────────────────────────────┤
│  Avg Sleep: 11h 45m   Avg Quality: 78 │
│  Awakenings: 21       Sessions: 14    │
│                                        │
│  Sleep Stage Distribution:            │
│  Light Sleep  ████████████ 52%        │
│  Deep Sleep   ███████ 28%             │
│  REM Sleep    █████ 20%               │
└────────────────────────────────────────┘
```

### **2. Quality Trend Chart** (Line Chart)
- X-axis: Date (last 7 days)
- Y-axis: Quality score (0-100)
- Shows trend over time
- Tap point to see details

### **3. Sleep Timeline Chart** (Bar Chart)
- Shows sleep stages as colored bars
- Each bar = stage segment
- Color-coded: Red (awake), Blue (light), Indigo (deep), Purple (REM)
- X-axis: Time of night
- Y-axis: Percentage

### **4. Session List**
- Recent sleep sessions (scrollable)
- Each item shows:
  - Quality score badge
  - Date/time
  - Duration
  - Quality rating
- Tap to view details

### **5. Session Details Panel**
- Full breakdown of selected session
- Metrics: Time to sleep, awakenings, efficiency
- Sleep timeline chart
- Stage durations

---

## 🔌 ESP32 Integration (How Device Sends Data)

### **Firmware: MQTT Publisher**

```cpp
// esp32_provisioning/src/mqtt_publisher.cpp

void publishVitals() {
  // Read mmWave sensor
  float respiratoryRate = mmWaveSensor.getRespiratoryRate();
  float heartRate = mmWaveSensor.getHeartRate();
  float movement = mmWaveSensor.getMovementIntensity();
  float presence = mmWaveSensor.getPresence();
  
  // Create JSON payload
  StaticJsonDocument<256> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["timestamp"] = getUnixTimestamp();
  doc["respiratoryRate"] = respiratoryRate;
  doc["heartRate"] = heartRate;
  doc["movementIntensity"] = movement;
  doc["presence"] = presence;
  
  char buffer[256];
  serializeJson(doc, buffer);
  
  // Publish to MQTT topic
  String topic = "devices/" + String(DEVICE_ID) + "/vitals";
  mqttClient.publish(topic.c_str(), buffer);
}

void loop() {
  // Sample at 1 Hz (every 1 second)
  publishVitals();
  delay(1000);
}
```

### **Cloud Function: Process Vitals**

```javascript
// functions/src/vitals-processor.ts

export const onVitalsReceived = functions.pubsub
  .topic('devices/{deviceId}/vitals')
  .onPublish(async (message, context) => {
    const data = JSON.parse(message.data.toString());
    const { deviceId, timestamp, respiratoryRate, heartRate, 
            movementIntensity, presence } = data;
    
    // Find device owner
    const deviceDoc = await db.collection('device_activations')
      .doc(deviceId).get();
    const userId = deviceDoc.data().userId;
    const babyId = deviceDoc.data().babyId; // Linked baby
    
    // Check if baby is currently sleeping
    const activeSessions = await db.collection('sleep_sessions')
      .where('babyId', '==', babyId)
      .where('endTime', '==', null)
      .limit(1)
      .get();
    
    let sessionId;
    
    if (activeSessions.empty) {
      // No active session - check if baby just fell asleep
      if (movementIntensity < 0.2 && presence > 0.8) {
        // Create new sleep session
        const newSession = await db.collection('sleep_sessions').add({
          babyId: babyId,
          userId: userId,
          deviceId: deviceId,
          startTime: admin.firestore.Timestamp.fromMillis(timestamp * 1000),
          endTime: null,
          isAutoDetected: true,
          isAnalyzed: false
        });
        sessionId = newSession.id;
      } else {
        return; // Baby is awake, no session
      }
    } else {
      sessionId = activeSessions.docs[0].id;
      
      // Check if baby woke up (high movement for >2 min)
      if (movementIntensity > 0.5) {
        // Mark session as ended
        await db.collection('sleep_sessions').doc(sessionId).update({
          endTime: admin.firestore.Timestamp.fromMillis(timestamp * 1000)
        });
        
        // Trigger analysis
        await analyzeSleepSession(sessionId);
        return;
      }
    }
    
    // Add sensor reading to session
    await db.collection('sleep_sessions')
      .doc(sessionId)
      .collection('sensor_readings')
      .doc(timestamp.toString())
      .set({
        timestamp: admin.firestore.Timestamp.fromMillis(timestamp * 1000),
        respiratoryRate,
        heartRate,
        movementIntensity,
        presence
      });
  });
```

---

## 📱 Flutter Implementation

### **Usage Example**

```dart
// In your dashboard screen
StreamBuilder<SleepSession?>(
  stream: _sleepService.streamActiveSleepSession(babyId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return Text('Baby is awake');
    }
    
    final session = snapshot.data!;
    return Column(
      children: [
        Text('Sleeping for ${formatDuration(session.totalDuration)}'),
        Text('Quality: ${session.qualityScore?.toInt() ?? "Calculating..."}'),
        
        // Real-time vitals
        StreamBuilder<SensorReading?>(
          stream: _sleepService.getLatestReading(session.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            
            final reading = snapshot.data!;
            return Row(
              children: [
                VitalCard(
                  label: 'Respiratory Rate',
                  value: '${reading.respiratoryRate.toInt()} bpm',
                  icon: Icons.air,
                ),
                VitalCard(
                  label: 'Heart Rate',
                  value: '${reading.heartRate.toInt()} bpm',
                  icon: Icons.favorite,
                ),
              ],
            );
          },
        ),
      ],
    );
  },
)
```

---

## 🎯 Key Features

### ✅ **Auto Sleep Detection**
- Device detects when baby falls asleep (low movement + presence)
- Auto-creates sleep session in Firestore
- No manual "Start Sleep" button needed

### ✅ **Real-Time Monitoring**
- Live vitals displayed during sleep
- Parents can check respiratory rate, heart rate
- Movement alerts if baby is restless

### ✅ **Sleep Stage Analysis**
- Classifies sleep into 4 stages (Awake, Light, Deep, REM)
- Based on movement + breathing patterns
- Shown as timeline chart

### ✅ **Quality Scoring**
- 0-100 score calculated from multiple factors
- Considers total sleep, awakenings, stage distribution
- Color-coded rating (Excellent/Good/Fair/Poor)

### ✅ **Weekly Trends**
- 7-day summary statistics
- Quality trend chart
- Average sleep duration
- Total awakenings

### ✅ **Actionable Insights**
- "Baby woke up 5 times last night" → Check room temperature
- "Only 15% deep sleep" → Review bedtime routine
- "Quality score improving!" → Positive reinforcement

---

## 🔐 Feature Gating

### **Premium Feature** (Requires Anavaya Device)

```dart
FeatureGate(
  feature: 'sleep_analysis',
  child: SleepAnalysisScreen(babyId: currentBaby.id),
  fallback: UpgradePrompt(
    title: 'Anavaya Device Required',
    message: 'Get automatic sleep analysis with our smart monitoring device',
    ctaText: 'Get Anavaya Device',
  ),
)
```

**Access Control**:
- Free tier: Manual sleep tracking only (no analysis)
- Anavaya Device: Full sleep analysis + quality scores
- Anavaya Pro: All sleep features + temperature monitoring

---

## 📊 Performance Considerations

### **Data Volume**
- **1 reading/second** = 36,000 readings per 10-hour sleep
- **Storage**: ~2KB per reading × 36,000 = 72MB
- **Solution**: Use Firestore TTL to delete readings >30 days old

### **Real-Time Streaming**
- Flutter streams active session (updates every 1-5 seconds)
- Cloud Function batches sensor readings (writes every 5-10 seconds)
- Reduces Firestore write costs

### **Analysis Performance**
- Analysis runs **after session ends** (not during)
- Processing 36,000 readings takes ~2-5 seconds
- Cached results stored in session document

---

## 🚀 Next Steps

### **Implementation Checklist**

- [x] Sleep data models (SleepSession, SensorReading, SleepStage)
- [x] Sleep analysis service (stage detection, quality scoring)
- [x] Dashboard UI (charts, statistics, session list)
- [x] Feature gating integration
- [ ] **ESP32 firmware** - mmWave sensor driver
- [ ] **Cloud Function** - onVitalsReceived processor
- [ ] **MQTT setup** - Pub/Sub topic configuration
- [ ] **Testing** - Simulate sensor data for development
- [ ] **Alerts** - Notify parents if baby wakes up

---

**Last Updated**: February 9, 2026  
**Status**: Core implementation complete, device integration pending
