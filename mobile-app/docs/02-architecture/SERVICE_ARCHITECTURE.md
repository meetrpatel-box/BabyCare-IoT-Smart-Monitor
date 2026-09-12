# 🏗️ Complete Service Architecture (Part 2)

**Continuation from SERVICE_ARCHITECTURE.md**

---

## 7️⃣ VITALS MONITORING SERVICE

### **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                  VitalsMonitoringService                    │
│                                                             │
│  INPUT:                                                     │
│  ├─ Device sensor readings (from ESP32 via Firestore)      │
│  ├─ Heart rate (BPM)                                       │
│  ├─ SpO2 (percentage)                                      │
│  ├─ Temperature (Celsius)                                  │
│  ├─ Breath rate (breaths/min)                              │
│  └─ Motion level (percentage)                              │
│                                                             │
│  PROCESSING:                                                │
│  ├─ Real-time Firestore stream subscription                │
│  ├─ Threshold monitoring (alerts)                          │
│  ├─ Historical trend analysis                              │
│  └─ Anomaly detection                                      │
│                                                             │
│  OUTPUT:                                                    │
│  ├─ Live vitals dashboard                                  │
│  ├─ Trend charts (24h, 7d, 30d)                            │
│  ├─ Alert notifications                                    │
│  └─ Health insights                                        │
└─────────────────────────────────────────────────────────────┘
```

### **Complete Data Flow**

```dart
// ═══════════════════════════════════════════════════════════
// LAYER 1: ESP32 SENDS VITALS (Every 1 second)
// ═══════════════════════════════════════════════════════════

ESP32 reads sensors:
├─ MAX30102:   heartRate=125 bpm, spO2=98%
├─ MLX90614:   bodyTemp=36.7°C
├─ Pressure:   breathRate=30 bpm
└─ ESP32-CAM:  motionLevel=2%

ESP32 HTTP POST to Firestore:
devices/AnvayaPod-A1B2C3/vitalReadings/{auto-id}

{
  "fields": {
    "timestamp": {"integerValue": "1738526400000"},
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {"integerValue": "125"},
          "spO2": {"integerValue": "98"},
          "bodyTemp": {"doubleValue": 36.7},
          "breathRate": {"integerValue": "30"},
          "motionLevel": {"integerValue": "2"}
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// LAYER 2: FIRESTORE STORES & TRIGGERS FUNCTION
// ═══════════════════════════════════════════════════════════

// Document created:
Collection: devices/AnvayaPod-A1B2C3/vitalReadings
Document: vr_12345

{
  timestamp: 1738526400000,
  vitals: {
    heartRate: 125,
    spO2: 98,
    bodyTemp: 36.7,
    breathRate: 30,
    motionLevel: 2
  },
  serverTimestamp: Timestamp(2026-02-02T10:00:00.123Z)
}

// Cloud Function triggered:
export const onVitalsUpdate = functions.firestore
  .document('devices/{deviceId}/vitalReadings/{readingId}')
  .onCreate(async (snap, context) => {
    
    const vitals = snap.data().vitals;
    const deviceId = context.params.deviceId;
    
    // 1. Check thresholds
    const alerts = [];
    
    if (vitals.heartRate > 160 || vitals.heartRate < 100) {
      alerts.push({
        type: 'heart_rate_abnormal',
        value: vitals.heartRate,
        severity: 'high'
      });
    }
    
    if (vitals.spO2 < 95) {
      alerts.push({
        type: 'low_oxygen',
        value: vitals.spO2,
        severity: 'critical'
      });
    }
    
    if (vitals.bodyTemp > 38.0) {
      alerts.push({
        type: 'fever',
        value: vitals.bodyTemp,
        severity: 'high'
      });
    }
    
    // 2. Update baby's latestVitals
    const device = await firestore
      .collection('devices')
      .doc(deviceId)
      .get();
    
    const babyId = device.data().assignedBabyId;
    
    if (babyId) {
      await firestore
        .collection('babies')
        .doc(babyId)
        .update({
          'latestVitals': vitals,
          'latestVitalsTimestamp': snap.data().timestamp
        });
    }
    
    // 3. Send alerts if any
    if (alerts.length > 0) {
      await sendPushNotifications(alerts, babyId);
    }
    
    // 4. Log to analytics
    await logVitalsToAnalytics(vitals, babyId);
  });

// ═══════════════════════════════════════════════════════════
// LAYER 3: FLUTTER APP SUBSCRIBES TO STREAM
// ═══════════════════════════════════════════════════════════

class VitalsService {
  
  // Subscribe to latest vitals for a baby
  Stream<LatestVitals> subscribeToLatestVitals(String babyId) {
    return _firestore
      .collection('babies')
      .doc(babyId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return null;
        
        final data = snapshot.data();
        if (data == null || !data.containsKey('latestVitals')) {
          return null;
        }
        
        return LatestVitals.fromMap(data['latestVitals']);
      })
      .where((vitals) => vitals != null)
      .cast<LatestVitals>();
  }
  
  // Get historical vitals for trends
  Future<List<VitalReading>> getHistoricalVitals({
    required String deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final snapshot = await _firestore
      .collection('devices')
      .doc(deviceId)
      .collection('vitalReadings')
      .where('timestamp', isGreaterThanOrEqualTo: startTime.millisecondsSinceEpoch)
      .where('timestamp', isLessThanOrEqualTo: endTime.millisecondsSinceEpoch)
      .orderBy('timestamp', descending: false)
      .get();
    
    return snapshot.docs
      .map((doc) => VitalReading.fromFirestore(doc))
      .toList();
  }
}

// ═══════════════════════════════════════════════════════════
// LAYER 4: PROVIDER MANAGES STATE
// ═══════════════════════════════════════════════════════════

class VitalsProvider extends ChangeNotifier {
  LatestVitals? _latestVitals;
  List<VitalReading> _history24h = [];
  StreamSubscription? _subscription;
  
  void startMonitoring(String babyId) {
    _subscription = VitalsService()
      .subscribeToLatestVitals(babyId)
      .listen((vitals) {
        _latestVitals = vitals;
        _checkForAlerts(vitals);
        notifyListeners();  // ← Triggers UI rebuild
      });
    
    // Load 24h history
    _load24HourHistory(babyId);
  }
  
  void _checkForAlerts(LatestVitals vitals) {
    // Heart rate alert
    if (vitals.heartRate > 160 || vitals.heartRate < 100) {
      _showAlert(
        title: 'Abnormal Heart Rate',
        message: 'Current: ${vitals.heartRate} BPM\nNormal range: 100-160 BPM',
        severity: AlertSeverity.high
      );
    }
    
    // SpO2 alert
    if (vitals.spO2 < 95) {
      _showAlert(
        title: 'Low Blood Oxygen',
        message: 'Current: ${vitals.spO2}%\nNormal: ≥95%',
        severity: AlertSeverity.critical
      );
    }
    
    // Temperature alert
    if (vitals.temperature > 38.0) {
      _showAlert(
        title: 'Fever Detected',
        message: 'Current: ${vitals.temperature.toStringAsFixed(1)}°C\nNormal: <38.0°C',
        severity: AlertSeverity.high
      );
    }
  }
  
  // Computed values for UI
  String get heartRateStatus {
    if (_latestVitals == null) return 'Unknown';
    final hr = _latestVitals!.heartRate;
    if (hr >= 100 && hr <= 160) return 'Normal';
    if (hr > 160) return 'High';
    return 'Low';
  }
  
  Color get heartRateColor {
    switch (heartRateStatus) {
      case 'Normal':
        return Colors.green;
      case 'High':
      case 'Low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// LAYER 5: UI DISPLAYS LIVE DATA
// ═══════════════════════════════════════════════════════════

class VitalsDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, provider, child) {
        
        final vitals = provider.latestVitals;
        if (vitals == null) {
          return Center(child: CircularProgressIndicator());
        }
        
        return Column(
          children: [
            // Live indicator
            LiveIndicator(
              isLive: provider.isLive,
              lastUpdate: vitals.timestamp,
            ),
            
            // Vital cards
            VitalCard(
              icon: Icons.favorite,
              label: 'Heart Rate',
              value: '${vitals.heartRate}',
              unit: 'BPM',
              status: provider.heartRateStatus,
              color: provider.heartRateColor,
              trend: provider.heartRateTrend,  // ↑ ↓ →
            ),
            
            VitalCard(
              icon: Icons.air,
              label: 'Blood Oxygen',
              value: '${vitals.spO2}',
              unit: '%',
              status: vitals.spO2 >= 95 ? 'Normal' : 'Low',
              color: vitals.spO2 >= 95 ? Colors.green : Colors.red,
            ),
            
            VitalCard(
              icon: Icons.thermostat,
              label: 'Temperature',
              value: vitals.temperature.toStringAsFixed(1),
              unit: '°C',
              status: vitals.temperature < 38.0 ? 'Normal' : 'Fever',
              color: vitals.temperature < 38.0 ? Colors.green : Colors.orange,
            ),
            
            VitalCard(
              icon: Icons.waves,
              label: 'Breathing',
              value: '${vitals.breathRate}',
              unit: '/min',
              status: 'Normal',
              color: Colors.green,
            ),
            
            // Trend chart (24 hours)
            VitalsTrendChart(
              data: provider.history24h,
              metric: VitalMetric.heartRate,
            ),
          ],
        );
      },
    );
  }
}

// RENDERED OUTPUT:
// ═══════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────┐
│  Vital Signs                                    🟢 Live     │
│  Updated: just now                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ❤️  Heart Rate                         125 BPM    ✓       │
│     Normal (100-160)                             ↑ +3       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │     Mini chart showing last hour trend          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  🫁  Blood Oxygen                        98%       ✓       │
│     Excellent (≥95%)                             → 0       │
│                                                             │
│  🌡️  Temperature                        36.7°C     ✓       │
│     Normal (<38.0°C)                             → 0       │
│                                                             │
│  💨  Breathing                           30/min    ✓       │
│     Steady and deep                              ↓ -2      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  📊 24-Hour Trend                                   │   │
│  │  ┌───────────────────────────────────────────┐     │   │
│  │  │  140 ┤                 ╭╮                 │     │   │
│  │  │  130 ┤              ╭──╯╰─╮               │     │   │
│  │  │  120 ┤           ╭──╯     ╰─╮             │     │   │
│  │  │  110 ┤        ╭──╯           ╰──╮         │     │   │
│  │  │  100 ┤     ╭──╯                 ╰─╮       │     │   │
│  │  │      └────────────────────────────────    │     │   │
│  │  │      12a  6a  12p  6p  12a  6a  Now      │     │   │
│  │  └───────────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 8️⃣ SLEEP ANALYSIS SERVICE

### **Data Flow: Complete Sleep Session**

```dart
// ═══════════════════════════════════════════════════════════
// PHASE 1: SLEEP DETECTION (Continuous monitoring)
// ═══════════════════════════════════════════════════════════

SleepIntelligenceService continuously analyzes vitals:

void _analyzeVitals(LatestVitals vitals) {
  // Calculate sleep state score
  double score = calculateSleepStateScore(vitals);
  
  if (score >= 70 && _currentSession == null) {
    // SLEEP DETECTED! Start new session
    _startSleepSession(vitals);
  } else if (score < 70 && _currentSession != null) {
    // WAKE DETECTED! End session
    _endSleepSession(vitals);
  } else if (_currentSession != null) {
    // Ongoing sleep - classify stage
    SleepStage stage = classifySleepStage(vitals, _history);
    _logSleepStage(stage, vitals);
  }
}

// ═══════════════════════════════════════════════════════════
// PHASE 2: SESSION START (8:30 PM - Emma falls asleep)
// ═══════════════════════════════════════════════════════════

void _startSleepSession(LatestVitals vitals) {
  _currentSession = SleepSession(
    id: 'session_${DateTime.now().millisecondsSinceEpoch}',
    babyId: babyId,
    startTime: vitals.timestamp,
    endTime: null,
    stageBreakdown: {},
    vitalLogs: [],
    cryEvents: [],
  );
  
  // Create Firestore document
  _firestore
    .collection('babies')
    .doc(babyId)
    .collection('sleepSessions')
    .doc(_currentSession!.id)
    .set(_currentSession!.toFirestore());
}

Firestore document created:
Collection: babies/baby_Emma_123/sleepSessions
Document: session_1738526400000

{
  id: "session_1738526400000",
  babyId: "baby_Emma_123",
  startTime: Timestamp(2026-02-02T20:30:00Z),
  endTime: null,
  currentStage: "deep",
  stageBreakdown: {
    deep: 0,
    light: 0,
    rem: 0
  },
  vitalLogs: [],
  cryEvents: [],
  quality: null,
  status: "active"
}

// ═══════════════════════════════════════════════════════════
// PHASE 3: STAGE TRACKING (Every 1 second during sleep)
// ═══════════════════════════════════════════════════════════

void _logSleepStage(SleepStage stage, LatestVitals vitals) {
  // Create vital log
  VitalLog log = VitalLog(
    timestamp: vitals.timestamp,
    heartRate: vitals.heartRate,
    breathRate: vitals.breathRate,
    bodyTemp: vitals.temperature,
    motionLevel: vitals.motionLevel,
    sleepStage: stage,
  );
  
  _currentSession!.vitalLogs.add(log);
  
  // Update stage duration
  if (!_currentSession!.stageBreakdown.containsKey(stage)) {
    _currentSession!.stageBreakdown[stage] = Duration.zero;
  }
  _currentSession!.stageBreakdown[stage] = 
    _currentSession!.stageBreakdown[stage]! + Duration(seconds: 1);
  
  // Save to Firestore every minute
  if (vitals.timestamp.second == 0) {
    _saveSessionProgress();
  }
}

Example vital logs:
Time      Stage  HR   BR  Temp  Motion
─────────────────────────────────────────
20:30:00  DEEP   125  30  36.7  2%
20:30:01  DEEP   125  30  36.7  2%
20:30:02  DEEP   124  29  36.7  1%
... (2700 seconds = 45 minutes of deep sleep)
21:15:00  LIGHT  130  32  36.8  6%
21:15:01  LIGHT  130  32  36.8  7%
... (1200 seconds = 20 minutes of light sleep)
21:35:00  REM    135  35  36.8  12%
... (900 seconds = 15 minutes of REM)

// ═══════════════════════════════════════════════════════════
// PHASE 4: CRY DETECTION (Event-driven)
// ═══════════════════════════════════════════════════════════

If cry detected during sleep:

void _logCryEvent(double noiseLevel, Duration duration) {
  CryEvent event = CryEvent(
    timestamp: DateTime.now(),
    duration: duration,
    intensity: noiseLevel,
    responded: false,
  );
  
  _currentSession!.cryEvents.add(event);
  
  // Send notification to parents
  _sendCryAlert(event);
}

Example cry event:
{
  timestamp: Timestamp(2026-02-02T23:15:00Z),
  duration: Duration(seconds: 45),
  intensity: 75.5,  // dB
  responded: true,
  responseTime: Duration(minutes: 2)
}

// ═══════════════════════════════════════════════════════════
// PHASE 5: SESSION END (6:00 AM - Emma wakes up)
// ═══════════════════════════════════════════════════════════

void _endSleepSession(LatestVitals vitals) {
  _currentSession!.endTime = vitals.timestamp;
  
  // Calculate quality score
  double quality = calculateSleepQuality(_currentSession!);
  _currentSession!.quality = quality;
  
  // Calculate sleep cycles
  int cycles = detectSleepCycles(_currentSession!.vitalLogs);
  _currentSession!.sleepCycles = cycles;
  
  // Generate insights
  SleepInsights insights = generateInsights(_currentSession!);
  
  // Save final session to Firestore
  _firestore
    .collection('babies')
    .doc(babyId)
    .collection('sleepSessions')
    .doc(_currentSession!.id)
    .update({
      'endTime': _currentSession!.endTime,
      'duration': _currentSession!.duration.inMinutes,
      'quality': quality,
      'sleepCycles': cycles,
      'status': 'completed',
      'insights': insights.toMap(),
    });
  
  _currentSession = null;
}

Final Firestore document:
{
  id: "session_1738526400000",
  babyId: "baby_Emma_123",
  startTime: Timestamp(2026-02-02T20:30:00Z),
  endTime: Timestamp(2026-02-03T06:00:00Z),
  duration: 570,  // minutes
  
  stageBreakdown: {
    deep: 330,   // 58%
    light: 150,  // 26%
    rem: 90      // 16%
  },
  
  quality: 95,  // 0-100 score
  sleepCycles: 5,
  avgCycleLength: 114,  // minutes
  
  vitalLogs: [...],  // 34,200 logs (9.5 hours × 3600 seconds/hour)
  cryEvents: [],
  
  insights: {
    achievements: [
      "Slept through the night!",
      "58% deep sleep (excellent)",
      "5 complete sleep cycles"
    ],
    recommendations: [
      "Maintain 8:30 PM bedtime",
      "Room temperature is ideal"
    ]
  },
  
  status: "completed"
}

// ═══════════════════════════════════════════════════════════
// PHASE 6: ANALYTICS & UI
// ═══════════════════════════════════════════════════════════

UI displays:
┌─────────────────────────────────────────────────────────────┐
│  Sleep Session                                              │
│  Feb 2, 2026 • 8:30 PM - 6:00 AM                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Sleep Quality                                      │   │
│  │  ┌─────────────────────────────────────┐           │   │
│  │  │          95/100                     │           │   │
│  │  │         EXCELLENT                   │           │   │
│  │  │     ●●●●●●●●●○ (4.75/5 stars)      │           │   │
│  │  └─────────────────────────────────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Duration: 9h 30m                                           │
│  Sleep Cycles: 5 complete cycles                           │
│  Wake Events: 0                                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Sleep Stages                                       │   │
│  │  ┌─────────────────────────────────────┐           │   │
│  │  │    🌙 Deep:  330 min (58%)          │ █████▓░   │   │
│  │  │    😴 Light: 150 min (26%)          │ ██▓░      │   │
│  │  │    👁️ REM:   90 min  (16%)          │ █▓░       │   │
│  │  └─────────────────────────────────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Hypnogram (Sleep stages over time)                │   │
│  │  ┌─────────────────────────────────────┐           │   │
│  │  │ AWAKE ▓                        ▓    │           │   │
│  │  │ REM   ░▓░    ░▓░        ░▓░  ▓░     │           │   │
│  │  │ LIGHT ░░▓░░  ░░▓░░    ░▓░░▓░░      │           │   │
│  │  │ DEEP  ░░░░▓▓▓░░░░▓▓▓▓▓░░░░░░▓▓▓     │           │   │
│  │  │       8PM  10  12  2AM  4   6AM     │           │   │
│  │  └─────────────────────────────────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  🏆 Achievements                                            │
│  ✓ Slept through the night!                                │
│  ✓ 58% deep sleep (excellent)                              │
│  ✓ 5 complete sleep cycles                                 │
│                                                             │
│  💡 Recommendations                                         │
│  • Maintain 8:30 PM bedtime - worked perfectly             │
│  • Room temperature (22°C) is ideal                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 9️⃣ FEEDING TRACKING SERVICE

### **Data Flow**

```dart
// ═══════════════════════════════════════════════════════════
// STEP 1: START FEEDING SESSION
// ═══════════════════════════════════════════════════════════

INPUT {
  type: FeedingType.bottle,
  startTime: DateTime(2026, 2, 2, 10, 0, 0)
}

FeedingService.startFeeding(
  babyId: "baby_Emma_123",
  type: FeedingType.bottle
)

// Create active session document
Collection: babies/baby_Emma_123/feedingSessions
Document: feeding_active

{
  id: "feeding_active",
  babyId: "baby_Emma_123",
  type: "bottle",
  startTime: Timestamp(2026-02-02T10:00:00Z),
  endTime: null,
  amount: null,
  duration: null,
  status: "active"
}

UI shows:
┌─────────────────────────────────────┐
│  🍼 Feeding in progress...          │
│                                     │
│  Started: 10:00 AM                  │
│  Duration: 00:05:23  ⏱️             │
│                                     │
│  [Stop Feeding]                    │
└─────────────────────────────────────┘

// ═══════════════════════════════════════════════════════════
// STEP 2: END FEEDING SESSION
// ═══════════════════════════════════════════════════════════

INPUT {
  amount: 120,  // ml
  endTime: DateTime(2026, 2, 2, 10, 15, 0)
}

FeedingService.endFeeding(
  sessionId: "feeding_active",
  amount: 120
)

// Update document
{
  id: "feeding_1738580400000",  // Renamed from active
  endTime: Timestamp(2026-02-02T10:15:00Z),
  duration: 15,  // minutes
  amount: 120,   // ml
  status: "completed",
  
  // Computed fields
  avgRate: 8.0,  // ml/min
  notes: null,
  diaperChangeAfter: null
}

// ═══════════════════════════════════════════════════════════
// STEP 3: ANALYTICS
// ═══════════════════════════════════════════════════════════

FeedingService.getDailyAnalytics("baby_Emma_123", DateTime(2026, 2, 2))

Aggregates all feedings for the day:

{
  date: "2026-02-02",
  totalFeedings: 8,
  totalAmount: 960,  // ml (8 × 120ml)
  avgAmountPerFeeding: 120,
  avgDurationPerFeeding: 15,
  
  feedingsByHour: {
    "00-03": 1,  // Night feeding
    "03-06": 1,
    "06-09": 2,
    "09-12": 2,
    "12-15": 1,
    "15-18": 0,
    "18-21": 1,
    "21-00": 0
  },
  
  longestGap: Duration(hours: 4, minutes: 30),
  shortestGap: Duration(hours: 2, minutes: 15),
  
  recommendation: "Emma is feeding well with consistent amounts. "
                  "The 4.5-hour gap is excellent for a 3-month-old."
}

UI shows:
┌─────────────────────────────────────────────────────────────┐
│  📊 Today's Feeding Summary                                 │
│  February 2, 2026                                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Total: 960 ml across 8 feedings                           │
│  Average: 120 ml per feeding                                │
│  Duration: ~15 minutes average                              │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Feeding Timeline                                   │   │
│  │  12a ━━  3a ━━  6a ━━━━  9a ━━━━  12p ━━  3p  ━━  6p│   │
│  │      🍼     🍼     🍼🍼      🍼🍼      🍼           🍼│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Next feeding due: ~2:30 PM (in 45 min)                    │
│                                                             │
│  ✅ Feeding pattern is excellent!                          │
│  💡 Emma is feeding well with consistent amounts           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔟 SERVICE INTEGRATION MAP

### **How Services Work Together**

```
┌─────────────────────────────────────────────────────────────┐
│                    USER JOURNEY                             │
└─────────────────────────────────────────────────────────────┘

1. ONBOARDING
   ├─ AuthService          → User sign up/login
   ├─ FamilyService        → Create family
   ├─ BabyService          → Add baby profile
   └─ DeviceService        → Register device

2. DEVICE SETUP
   ├─ WifiProvisioningService  → Connect device to WiFi
   ├─ DeviceService            → Assign device to baby
   └─ VitalsService            → Start monitoring

3. DAILY MONITORING
   ├─ VitalsService        → Real-time health data
   ├─ SleepService         → Sleep tracking
   ├─ FeedingService       → Feeding logs
   ├─ DiaperService        → Diaper changes
   └─ PhotoService         → Capture moments

4. INSIGHTS & GROWTH
   ├─ MilestoneService     → Development tracking
   ├─ AIInsightsService    → Smart recommendations
   └─ AnalyticsService     → Trends and patterns
```

### **Service Dependencies**

```
AuthService
  └─ Required by: ALL services (authentication)

FamilyService
  ├─ Depends on: AuthService
  └─ Used by: BabyService, DeviceService

BabyService
  ├─ Depends on: AuthService, FamilyService
  └─ Used by: ALL tracking services

DeviceService
  ├─ Depends on: AuthService, FamilyService
  └─ Used by: VitalsService, WifiProvisioningService

VitalsService
  ├─ Depends on: DeviceService, BabyService
  └─ Used by: SleepService, AIInsightsService

SleepService
  ├─ Depends on: VitalsService, BabyService
  └─ Used by: AIInsightsService, AnalyticsService

PhotoService
  ├─ Depends on: AuthService, BabyService
  └─ Used by: MilestoneService, AIInsightsService

AIInsightsService
  ├─ Depends on: ALL tracking services
  └─ Provides recommendations to UI
```

---

## 🎯 SUMMARY

### **Key Metrics**

| Service | Collections Used | Real-time Streams | Cloud Functions | External APIs |
|---------|------------------|-------------------|-----------------|---------------|
| AuthService | users | ✓ | onCreate User | Firebase Auth API |
| DeviceService | devices | ✓ | onHeartbeat | None |
| PhotoService | photos | ✓ | onUpload, AI tagging | Cloud Vision API |
| WifiProvisioningService | devices | ✗ | None | Bluetooth LE |
| VitalsService | vitalReadings | ✓ | onVitalsUpdate | None |
| SleepService | sleepSessions | ✓ | onSessionEnd | None |
| FeedingService | feedingSessions | ✓ | None | None |
| MilestoneService | milestones | ✓ | onMilestoneCreated | None |
| AIInsightsService | insights | ✓ | generateInsights | OpenAI/Gemini API |

### **Performance Characteristics**

- **Real-time latency**: 100-500ms (Firestore streams)
- **BLE provisioning**: 10-30 seconds
- **Photo upload**: 2-10 seconds (depends on file size)
- **AI analysis**: 1-5 seconds (Cloud Vision)
- **Sleep analysis**: Real-time (< 50ms computation)
- **Alert delivery**: < 1 second (push notifications)

**Total services: 11 core services covering complete baby care workflow!** 🚀

