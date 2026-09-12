# 🌙 Sleep Analysis Feature - End-to-End Implementation Guide

**Feature**: Sleep Tracking & Analysis for Flutter App  
**Date**: February 2, 2026  
**Focus**: Complete implementation flow from data entry to analytics

---

## 📋 **FEATURE OVERVIEW**

### **What It Does**
Parents can:
1. **Manual Entry**: Log sleep sessions (start/end time, quality, wake count)
2. **View Analytics**: See sleep patterns, averages, trends over 7/30 days
3. **Track Sleep Stages**: Monitor deep, light, REM, and awake periods
4. **Get Insights**: Receive recommendations based on sleep data

### **Current Status**
✅ **Models**: SleepSession, SleepStage, SleepQuality - COMPLETE  
✅ **UI**: SleepAnalysisScreen with charts - COMPLETE  
🟡 **Service**: Partial (read-only via FirestoreService)  
❌ **Provider**: Missing dedicated SleepProvider  
❌ **Entry UI**: No manual sleep logging screen  
❌ **Auto-Detection**: No sensor integration  
❌ **AI Analysis**: No sleep quality scoring  

---

## 🏗️ **ARCHITECTURE OVERVIEW**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SLEEP ANALYSIS DATA FLOW                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. DATA INPUT                                                           │
│     ┌──────────────┐         ┌──────────────┐                          │
│     │ Manual Entry │   OR    │ Auto-Detect  │  (Future)                │
│     │ Screen       │         │ from Sensor  │                          │
│     └──────┬───────┘         └──────┬───────┘                          │
│            │                        │                                   │
│            └────────┬───────────────┘                                   │
│                     ▼                                                    │
│              ┌─────────────┐                                            │
│              │SleepProvider│  (State Management)                        │
│              └──────┬──────┘                                            │
│                     ▼                                                    │
│  2. DATA STORAGE                                                         │
│              ┌─────────────┐                                            │
│              │SleepService │  (Business Logic)                          │
│              └──────┬──────┘                                            │
│                     ▼                                                    │
│              ┌─────────────┐                                            │
│              │  Firestore  │  Collection: /babies/{id}/sleepSessions   │
│              └──────┬──────┘                                            │
│                     │                                                    │
│  3. DATA RETRIEVAL                                                       │
│                     ▼                                                    │
│         ┌──────────────────────┐                                        │
│         │ Stream Subscription  │  Real-time updates                     │
│         └──────────┬───────────┘                                        │
│                    ▼                                                     │
│  4. DATA PROCESSING                                                      │
│         ┌──────────────────────┐                                        │
│         │ Sleep Analytics      │  Calculations:                         │
│         │ Calculator           │  - Avg duration                        │
│         │                      │  - Stage percentages                   │
│         │                      │  - Wake count                          │
│         │                      │  - Quality score                       │
│         └──────────┬───────────┘                                        │
│                    ▼                                                     │
│  5. UI DISPLAY                                                           │
│         ┌──────────────────────┐                                        │
│         │ SleepAnalysisScreen  │  - Summary cards                       │
│         │ - Charts             │  - Pie chart (stages)                  │
│         │ - Lists              │  - Bar chart (duration)                │
│         │ - Insights           │  - Session list                        │
│         └──────────────────────┘                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 **FILE STRUCTURE**

```
baby_track_flutter/
├── lib/
│   ├── models/
│   │   └── sleep_model.dart ✅ EXISTS
│   │       ├── SleepSession
│   │       ├── SleepStage
│   │       ├── SleepStageType (enum)
│   │       └── SleepQuality (enum)
│   │
│   ├── services/
│   │   └── sleep_service.dart ❌ TO CREATE
│   │       ├── createSleepSession()
│   │       ├── updateSleepSession()
│   │       ├── endSleepSession()
│   │       ├── getSleepSessions()
│   │       ├── subscribeTo SleepSessions()
│   │       ├── calculateSleepQuality()
│   │       └── detectSleepPattern()
│   │
│   ├── providers/
│   │   └── sleep_provider.dart ❌ TO CREATE
│   │       ├── Current active session
│   │       ├── Historical sessions
│   │       ├── Analytics data
│   │       └── Notification listeners
│   │
│   ├── screens/
│   │   ├── main/
│   │   │   └── sleep_analysis_screen.dart ✅ EXISTS (READ ONLY)
│   │   │
│   │   └── sleep/
│   │       ├── sleep_log_screen.dart ❌ TO CREATE
│   │       ├── sleep_session_detail_screen.dart ❌ TO CREATE
│   │       └── sleep_timer_screen.dart ❌ TO CREATE
│   │
│   └── widgets/
│       ├── sleep/
│       │   ├── sleep_timer_widget.dart ❌ TO CREATE
│       │   ├── sleep_stage_chart.dart ❌ TO CREATE
│       │   ├── sleep_quality_indicator.dart ❌ TO CREATE
│       │   └── sleep_session_card.dart ❌ TO CREATE
│       │
│       └── sleep_summary_card.dart ✅ EXISTS
│
└── test/
    └── unit/
        ├── models/
        │   └── sleep_model_test.dart ✅ EXISTS
        └── services/
            └── sleep_service_test.dart ❌ TO CREATE
```

---

## 🔧 **IMPLEMENTATION STEPS**

### **STEP 1: Create SleepService**

**Purpose**: Handle all sleep data CRUD operations and analytics

```dart
// lib/services/sleep_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sleep_model.dart';

class SleepService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // CREATE OPERATIONS
  // ============================================================================

  /// Start a new sleep session
  Future<String> startSleepSession(String babyId) async {
    final session = SleepSession(
      id: '',
      babyId: babyId,
      startTime: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .add(session.toFirestore());

    return docRef.id;
  }

  /// Log a completed sleep session manually
  Future<String> logSleepSession({
    required String babyId,
    required DateTime startTime,
    required DateTime endTime,
    SleepQuality? quality,
    int? wakeCount,
    List<SleepStage>? stages,
  }) async {
    final duration = endTime.difference(startTime);
    final totalMinutes = duration.inMinutes;

    final session = SleepSession(
      id: '',
      babyId: babyId,
      startTime: startTime,
      endTime: endTime,
      totalMinutes: totalMinutes,
      quality: quality,
      wakeCount: wakeCount,
      stages: stages ?? [],
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .add(session.toFirestore());

    return docRef.id;
  }

  // ============================================================================
  // UPDATE OPERATIONS
  // ============================================================================

  /// End an active sleep session
  Future<void> endSleepSession(String babyId, String sessionId) async {
    final now = DateTime.now();

    // Get current session to calculate duration
    final doc = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .get();

    if (!doc.exists) {
      throw Exception('Sleep session not found');
    }

    final session = SleepSession.fromFirestore(doc);
    final duration = now.difference(session.startTime);
    final totalMinutes = duration.inMinutes;

    // Calculate sleep quality based on duration and wake count
    final quality = _calculateSleepQuality(
      totalMinutes: totalMinutes,
      wakeCount: session.wakeCount ?? 0,
      babyAgeInMonths: _getBabyAgeInMonths(babyId), // Implement this
    );

    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .update({
      'endTime': Timestamp.fromDate(now),
      'totalMinutes': totalMinutes,
      'quality': quality.value,
    });
  }

  /// Update sleep session details
  Future<void> updateSleepSession(
    String babyId,
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .update(data);
  }

  /// Add sleep stages to a session (from sensor data or manual entry)
  Future<void> addSleepStages(
    String babyId,
    String sessionId,
    List<SleepStage> stages,
  ) async {
    final stagesData = stages.map((s) => s.toMap()).toList();

    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .update({'stages': FieldValue.arrayUnion(stagesData)});
  }

  // ============================================================================
  // READ OPERATIONS
  // ============================================================================

  /// Get sleep sessions for a date range
  Future<List<SleepSession>> getSleepSessions({
    required String babyId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .orderBy('startTime', descending: true);

    if (startDate != null) {
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SleepSession.fromFirestore(doc)).toList();
  }

  /// Get the currently active sleep session
  Future<SleepSession?> getActiveSleepSession(String babyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .where('endTime', isNull: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SleepSession.fromFirestore(snapshot.docs.first);
  }

  // ============================================================================
  // STREAM SUBSCRIPTIONS
  // ============================================================================

  /// Subscribe to sleep sessions updates
  Stream<List<SleepSession>> subscribeTo SleepSessions({
    required String babyId,
    DateTime? startDate,
    int? limit,
  }) {
    Query query = _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .orderBy('startTime', descending: true);

    if (startDate != null) {
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => SleepSession.fromFirestore(doc)).toList(),
        );
  }

  /// Subscribe to active sleep session
  Stream<SleepSession?> subscribeToActiveSleepSession(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .where('endTime', isNull: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SleepSession.fromFirestore(snapshot.docs.first);
    });
  }

  // ============================================================================
  // ANALYTICS & CALCULATIONS
  // ============================================================================

  /// Calculate sleep quality score
  SleepQuality _calculateSleepQuality({
    required int totalMinutes,
    required int wakeCount,
    required int babyAgeInMonths,
  }) {
    // Age-appropriate sleep duration ranges (in minutes)
    final Map<int, Map<String, int>> sleepRanges = {
      0: {'min': 720, 'optimal': 900},   // 0-2 months: 12-15h
      3: {'min': 660, 'optimal': 840},   // 3-5 months: 11-14h
      6: {'min': 600, 'optimal': 780},   // 6-11 months: 10-13h
      12: {'min': 660, 'optimal': 840},  // 12+ months: 11-14h
    };

    // Find appropriate range
    int ageGroup = 0;
    if (babyAgeInMonths >= 12) {
      ageGroup = 12;
    } else if (babyAgeInMonths >= 6) {
      ageGroup = 6;
    } else if (babyAgeInMonths >= 3) {
      ageGroup = 3;
    }

    final range = sleepRanges[ageGroup]!;
    final minDuration = range['min']!;
    final optimalDuration = range['optimal']!;

    // Calculate score (0-100)
    int score = 0;

    // Duration component (60 points max)
    if (totalMinutes >= optimalDuration) {
      score += 60;
    } else if (totalMinutes >= minDuration) {
      score += ((totalMinutes - minDuration) / (optimalDuration - minDuration) * 60).round();
    } else {
      score += (totalMinutes / minDuration * 40).round();
    }

    // Wake count component (40 points max)
    if (wakeCount == 0) {
      score += 40;
    } else if (wakeCount == 1) {
      score += 30;
    } else if (wakeCount == 2) {
      score += 20;
    } else if (wakeCount == 3) {
      score += 10;
    }

    // Map score to quality
    if (score >= 85) return SleepQuality.excellent;
    if (score >= 70) return SleepQuality.good;
    if (score >= 50) return SleepQuality.fair;
    return SleepQuality.poor;
  }

  /// Calculate sleep analytics for a period
  Future<SleepAnalytics> calculateAnalytics({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sessions = await getSleepSessions(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
    );

    if (sessions.isEmpty) {
      return SleepAnalytics(
        totalSessions: 0,
        averageDurationMinutes: 0,
        averageWakeCount: 0,
        qualityDistribution: {},
        stageDistribution: {},
      );
    }

    // Calculate averages
    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
    final totalWakes = sessions.fold<int>(0, (sum, s) => sum + (s.wakeCount ?? 0));

    // Quality distribution
    final qualityCount = <SleepQuality, int>{};
    for (final session in sessions) {
      if (session.quality != null) {
        qualityCount[session.quality!] = (qualityCount[session.quality!] ?? 0) + 1;
      }
    }

    // Stage distribution
    final stageMinutes = <SleepStageType, int>{};
    for (final session in sessions) {
      for (final stage in session.stages) {
        stageMinutes[stage.stage] = (stageMinutes[stage.stage] ?? 0) + stage.durationMinutes;
      }
    }

    return SleepAnalytics(
      totalSessions: sessions.length,
      averageDurationMinutes: (totalMinutes / sessions.length).round(),
      averageWakeCount: (totalWakes / sessions.length),
      qualityDistribution: qualityCount,
      stageDistribution: stageMinutes,
    );
  }

  /// Detect sleep patterns and generate insights
  Future<List<String>> detectPatterns({
    required String babyId,
    required int days,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final sessions = await getSleepSessions(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
    );

    final insights = <String>[];

    if (sessions.isEmpty) {
      insights.add('No sleep data available for analysis');
      return insights;
    }

    // Average duration
    final avgMinutes = sessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes) / sessions.length;
    final avgHours = (avgMinutes / 60).toStringAsFixed(1);

    if (avgMinutes < 480) {
      insights.add('⚠️ Average sleep duration ($avgHours hours) is below recommended');
    } else if (avgMinutes > 900) {
      insights.add('😴 Baby is sleeping more than average ($avgHours hours)');
    } else {
      insights.add('✅ Sleep duration ($avgHours hours) is within healthy range');
    }

    // Wake count trend
    final avgWakes = sessions.fold<int>(0, (sum, s) => sum + (s.wakeCount ?? 0)) / sessions.length;
    if (avgWakes > 3) {
      insights.add('🌙 Frequent night wakings detected (${avgWakes.toStringAsFixed(1)} per night)');
    } else if (avgWakes < 1) {
      insights.add('🎉 Great progress! Very few night wakings');
    }

    // Quality trend
    final poorQualitySessions = sessions.where((s) => s.quality == SleepQuality.poor).length;
    if (poorQualitySessions > sessions.length * 0.5) {
      insights.add('😓 Sleep quality has been declining - consider sleep training');
    }

    // Consistency check (bedtime variance)
    final bedtimes = sessions.map((s) => s.startTime.hour * 60 + s.startTime.minute).toList();
    if (bedtimes.length > 2) {
      final avgBedtime = bedtimes.reduce((a, b) => a + b) / bedtimes.length;
      final variance = bedtimes.map((t) => (t - avgBedtime).abs()).reduce((a, b) => a + b) / bedtimes.length;

      if (variance > 60) {
        insights.add('⏰ Bedtime is inconsistent - try establishing a routine');
      } else {
        insights.add('✅ Good sleep schedule consistency');
      }
    }

    return insights;
  }

  // Helper method (implement based on baby data)
  int _getBabyAgeInMonths(String babyId) {
    // This would fetch baby's DOB and calculate age
    // For now, return a default
    return 6;
  }

  // ============================================================================
  // DELETE OPERATIONS
  // ============================================================================

  /// Delete a sleep session
  Future<void> deleteSleepSession(String babyId, String sessionId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .delete();
  }
}

/// Sleep analytics data model
class SleepAnalytics {
  final int totalSessions;
  final int averageDurationMinutes;
  final double averageWakeCount;
  final Map<SleepQuality, int> qualityDistribution;
  final Map<SleepStageType, int> stageDistribution;

  SleepAnalytics({
    required this.totalSessions,
    required this.averageDurationMinutes,
    required this.averageWakeCount,
    required this.qualityDistribution,
    required this.stageDistribution,
  });

  String get averageDurationDisplay {
    final hours = averageDurationMinutes ~/ 60;
    final minutes = averageDurationMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
```

---

### **STEP 2: Create SleepProvider**

**Purpose**: Manage sleep state and expose to UI

```dart
// lib/providers/sleep_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sleep_model.dart';
import '../services/sleep_service.dart';

class SleepProvider extends ChangeNotifier {
  final SleepService _sleepService = SleepService();

  // Current state
  SleepSession? _activeSession;
  List<SleepSession> _recentSessions = [];
  SleepAnalytics? _analytics;
  List<String> _insights = [];
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions
  StreamSubscription? _activeSessionSubscription;
  StreamSubscription? _sessionsSubscription;

  // Getters
  SleepSession? get activeSession => _activeSession;
  List<SleepSession> get recentSessions => _recentSessions;
  SleepAnalytics? get analytics => _analytics;
  List<String> get insights => _insights;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSleeping => _activeSession != null;

  /// Initialize for a baby
  Future<void> initialize(String babyId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Subscribe to active session
      _activeSessionSubscription?.cancel();
      _activeSessionSubscription =
          _sleepService.subscribeToActiveSleepSession(babyId).listen(
        (session) {
          _activeSession = session;
          notifyListeners();
        },
      );

      // Subscribe to recent sessions
      _sessionsSubscription?.cancel();
      _sessionsSubscription = _sleepService
          .subscribeTo SleepSessions(
        babyId: babyId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 50,
      )
          .listen(
        (sessions) {
          _recentSessions = sessions;
          _recalculateAnalytics(babyId);
          notifyListeners();
        },
      );

      // Load initial analytics
      await _recalculateAnalytics(babyId);

      // Load insights
      _insights = await _sleepService.detectPatterns(babyId: babyId, days: 7);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start sleep tracking
  Future<void> startSleep(String babyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sleepService.startSleepSession(babyId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// End sleep tracking
  Future<void> endSleep(String babyId) async {
    if (_activeSession == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sleepService.endSleepSession(babyId, _activeSession!.id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log a completed sleep session
  Future<void> logSleepSession({
    required String babyId,
    required DateTime startTime,
    required DateTime endTime,
    SleepQuality? quality,
    int? wakeCount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _sleepService.logSleepSession(
        babyId: babyId,
        startTime: startTime,
        endTime: endTime,
        quality: quality,
        wakeCount: wakeCount,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a sleep session
  Future<void> deleteSession(String babyId, String sessionId) async {
    try {
      await _sleepService.deleteSleepSession(babyId, sessionId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Recalculate analytics
  Future<void> _recalculateAnalytics(String babyId) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 7));

    _analytics = await _sleepService.calculateAnalytics(
      babyId: babyId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Refresh insights
  Future<void> refreshInsights(String babyId, {int days = 7}) async {
    _insights = await _sleepService.detectPatterns(babyId: babyId, days: days);
    notifyListeners();
  }

  @override
  void dispose() {
    _activeSessionSubscription?.cancel();
    _sessionsSubscription?.cancel();
    super.dispose();
  }
}
```

---

### **STEP 3: Create Sleep Log Screen**

**Purpose**: Manual entry UI for logging sleep sessions

```dart
// lib/screens/sleep/sleep_log_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/baby_provider.dart';
import '../../providers/sleep_provider.dart';
import '../../models/sleep_model.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/smart_back_button.dart';

class SleepLogScreen extends StatefulWidget {
  const SleepLogScreen({super.key});

  @override
  State<SleepLogScreen> createState() => _SleepLogScreenState();
}

class _SleepLogScreenState extends State<SleepLogScreen> {
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 8));
  DateTime _endTime = DateTime.now();
  int _wakeCount = 0;
  SleepQuality _quality = SleepQuality.good;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Log Sleep Session'),
        leading: const SmartCloseButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start Time
            _buildTimePicker(
              label: 'Start Time',
              time: _startTime,
              onTap: () => _selectDateTime(context, true),
            ),

            const SizedBox(height: AppSpacing.lg),

            // End Time
            _buildTimePicker(
              label: 'End Time',
              time: _endTime,
              onTap: () => _selectDateTime(context, false),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Duration Display
            _buildDurationDisplay(),

            const SizedBox(height: AppSpacing.xl),

            // Wake Count
            _buildWakeCountPicker(),

            const SizedBox(height: AppSpacing.xl),

            // Sleep Quality
            _buildQualityPicker(),

            const SizedBox(height: AppSpacing.xxl),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSleepSession,
                child: const Text('Save Sleep Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required DateTime time,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(_formatDateTime(time)),
        trailing: const Icon(Icons.access_time),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDurationDisplay() {
    final duration = _endTime.difference(_startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Card(
      color: DesignTokens.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bedtime, size: 32),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${hours}h ${minutes}m',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWakeCountPicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wake Count',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_wakeCount > 0) {
                      setState(() => _wakeCount--);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text(
                    '$_wakeCount',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _wakeCount++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityPicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sleep Quality',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: SleepQuality.values.map((quality) {
                final isSelected = _quality == quality;
                return ChoiceChip(
                  label: Text(quality.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _quality = quality);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );

      if (pickedTime != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartTime) {
            _startTime = newDateTime;
            // Ensure end time is after start time
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            _endTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _saveSleepSession() async {
    final babyProvider = context.read<BabyProvider>();
    final sleepProvider = context.read<SleepProvider>();

    if (babyProvider.selectedBaby == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No baby selected')),
      );
      return;
    }

    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    await sleepProvider.logSleepSession(
      babyId: babyProvider.selectedBaby!.id,
      startTime: _startTime,
      endTime: _endTime,
      quality: _quality,
      wakeCount: _wakeCount,
    );

    if (context.mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep session logged!')),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
```

---

## 🔄 **DATA FLOW EXAMPLES**

### **Example 1: Manual Sleep Logging**

```
USER ACTION → PROVIDER → SERVICE → FIRESTORE → UI UPDATE

1. User taps "Log Sleep" button
   ↓
2. SleepLogScreen opened
   ↓
3. User enters:
   - Start: Feb 1, 11:00 PM
   - End: Feb 2, 7:00 AM  
   - Wake count: 2
   - Quality: Good
   ↓
4. User taps "Save"
   ↓
5. SleepProvider.logSleepSession() called
   ↓
6. SleepService.logSleepSession() calculates:
   - duration = 480 minutes (8 hours)
   - quality score = 70 (good)
   ↓
7. Data written to Firestore:
   /babies/{babyId}/sleepSessions/{sessionId}
   {
     babyId: "baby123",
     startTime: Timestamp(2026-02-01 23:00),
     endTime: Timestamp(2026-02-02 07:00),
     totalMinutes: 480,
     wakeCount: 2,
     quality: "good",
     stages: [],
     createdAt: Timestamp(2026-02-02 07:05)
   }
   ↓
8. Stream subscription receives update
   ↓
9. SleepProvider notifies listeners
   ↓
10. SleepAnalysisScreen rebuilds with new data
```

---

### **Example 2: Real-time Sleep Tracking**

```
START TRACKING → MONITOR → END TRACKING → CALCULATE

1. User taps "Start Sleep" button (9:00 PM)
   ↓
2. SleepProvider.startSleep() called
   ↓
3. SleepService creates active session:
   {
     babyId: "baby123",
     startTime: Timestamp(2026-02-01 21:00),
     endTime: null,
     createdAt: Timestamp(2026-02-01 21:00)
   }
   ↓
4. UI shows timer widget with elapsed time
   ↓
5. Timer runs for 8 hours...
   ↓
6. User taps "End Sleep" button (5:00 AM)
   ↓
7. SleepProvider.endSleep() called
   ↓
8. SleepService.endSleepSession():
   - Calculates duration: 480 minutes
   - Calculates quality based on duration & baby age
   - Updates session with endTime and quality
   ↓
9. Session marked as complete in Firestore
   ↓
10. Analytics recalculated
   ↓
11. Insights regenerated
   ↓
12. UI shows completed session in history
```

---

## 📊 **FIRESTORE SCHEMA**

```
/babies/{babyId}/sleepSessions/{sessionId}
{
  babyId: string,
  startTime: Timestamp,
  endTime: Timestamp | null,
  totalMinutes: number | null,
  quality: "excellent" | "good" | "fair" | "poor" | null,
  wakeCount: number | null,
  stages: [
    {
      stage: "Deep" | "Light" | "REM" | "Awake",
      durationMinutes: number,
      startTime: Timestamp,
      endTime: Timestamp
    }
  ],
  createdAt: Timestamp
}

// Indexes needed:
- babyId ASC, startTime DESC
- babyId ASC, endTime ASC (for active sessions)
```

---

## ✅ **TESTING STRATEGY**

### **Unit Tests**

```dart
// test/unit/services/sleep_service_test.dart

void main() {
  group('SleepService', () {
    test('calculates sleep quality correctly', () {
      // Test quality calculation for different scenarios
    });

    test('detects sleep patterns', () {
      // Test pattern detection logic
    });

    test('calculates analytics correctly', () {
      // Test analytics calculations
    });
  });
}
```

### **Widget Tests**

```dart
// test/widgets/sleep_log_screen_test.dart

void main() {
  testWidgets('Sleep log screen validates input', (tester) async {
    // Test form validation
  });

  testWidgets('Sleep log screen saves session', (tester) async {
    // Test save flow
  });
}
```

---

## 🚀 **IMPLEMENTATION PRIORITY**

1. ✅ **SleepService** - Core business logic (4 hours)
2. ✅ **SleepProvider** - State management (2 hours)
3. ✅ **SleepLogScreen** - Manual entry UI (3 hours)
4. ✅ **Update SleepAnalysisScreen** - Connect to provider (1 hour)
5. ⏳ **Sleep Timer Widget** - Real-time tracking UI (2 hours)
6. ⏳ **Unit Tests** - Service and provider tests (2 hours)

**Total Estimated Time**: 14 hours

---

## 📝 **NEXT STEPS**

After implementing sleep analysis, apply same pattern to:
- Feeding tracking
- Diaper tracking  
- Growth tracking
- Milestone detection

Each feature follows the same architecture:
**Model → Service → Provider → Screen → Widgets**

Would you like me to start implementing these files in your Flutter app?
