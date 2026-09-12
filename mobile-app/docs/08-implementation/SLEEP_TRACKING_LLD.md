# Sleep Tracking - Low-Level Design (LLD)

**Document ID**: LLD-SLEEP-001  
**Version**: 1.0.0  
**Status**: 🟢 Ready for Implementation  
**Last Updated**: February 2, 2026  
**Feature**: Manual Sleep Tracking with Analytics

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Data Models](#data-models)
3. [Service Layer](#service-layer)
4. [Cloud Functions](#cloud-functions)
5. [UI Components](#ui-components)
6. [User Flows](#user-flows)
7. [Analytics & Insights](#analytics--insights)
8. [Implementation Roadmap](#implementation-roadmap)

---

## 1. Overview

### 1.1 Purpose

Manual sleep tracking allows parents to log:
- **Sleep sessions** (naps and nighttime sleep)
- **Sleep quality** indicators
- **Sleep environment** conditions
- **Sleep interruptions** and wake-ups

The system provides:
- Real-time sleep timers
- Daily/weekly sleep totals
- Sleep pattern analysis
- Recommended sleep windows
- Sleep quality scoring

### 1.2 Key Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Start/Stop Timer | Track sleep in real-time | P0 |
| Quick Log | Log past sleep sessions | P0 |
| Sleep Type | Categorize as nap or nighttime | P0 |
| Sleep Quality | Rate sleep quality (1-5 stars) | P1 |
| Interruptions | Log wake-ups during sleep | P1 |
| Environment | Track room temp, noise, lighting | P2 |
| Sleep Notes | Free-form notes about sleep | P2 |
| Sleep Stats | Daily/weekly totals & averages | P0 |
| Sleep Charts | Visual trend analysis | P1 |
| Sleep Score | Daily sleep quality score (0-100) | P1 |

### 1.3 Sleep Categories

```dart
enum SleepType {
  nap,          // Daytime sleep (< 4 hours)
  nightSleep,   // Nighttime sleep (typically > 4 hours)
}

enum SleepQuality {
  veryPoor,     // 1 star - Very restless, multiple wake-ups
  poor,         // 2 stars - Restless sleep
  fair,         // 3 stars - Average sleep
  good,         // 4 stars - Mostly peaceful
  excellent,    // 5 stars - Deep, peaceful sleep
}
```

---

## 2. Data Models

### 2.1 Flutter Model: `SleepSessionModel`

**File**: `lib/models/sleep_session_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SleepType {
  nap,
  nightSleep;

  String get displayName {
    switch (this) {
      case SleepType.nap:
        return 'Nap';
      case SleepType.nightSleep:
        return 'Night Sleep';
    }
  }
}

enum SleepQuality {
  veryPoor,
  poor,
  fair,
  good,
  excellent;

  String get displayName {
    switch (this) {
      case SleepQuality.veryPoor:
        return 'Very Poor';
      case SleepQuality.poor:
        return 'Poor';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.excellent:
        return 'Excellent';
    }
  }

  int get stars {
    return index + 1; // 1-5 stars
  }

  int get score {
    return (index + 1) * 20; // 20, 40, 60, 80, 100
  }
}

class SleepInterruption {
  final DateTime timestamp;
  final int durationMinutes; // How long awake
  final String? reason; // 'feeding', 'diaper', 'crying', 'other'
  final String? notes;

  SleepInterruption({
    required this.timestamp,
    required this.durationMinutes,
    this.reason,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'durationMinutes': durationMinutes,
      'reason': reason,
      'notes': notes,
    };
  }

  factory SleepInterruption.fromMap(Map<String, dynamic> map) {
    return SleepInterruption(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      durationMinutes: map['durationMinutes'] as int,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class SleepEnvironment {
  final double? roomTempCelsius;
  final String? noiseLevel; // 'silent', 'quiet', 'moderate', 'noisy'
  final String? lighting; // 'dark', 'dim', 'bright'
  final bool? whiteNoiseMachine;
  final String? notes;

  SleepEnvironment({
    this.roomTempCelsius,
    this.noiseLevel,
    this.lighting,
    this.whiteNoiseMachine,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomTempCelsius': roomTempCelsius,
      'noiseLevel': noiseLevel,
      'lighting': lighting,
      'whiteNoiseMachine': whiteNoiseMachine,
      'notes': notes,
    };
  }

  factory SleepEnvironment.fromMap(Map<String, dynamic> map) {
    return SleepEnvironment(
      roomTempCelsius: map['roomTempCelsius'] as double?,
      noiseLevel: map['noiseLevel'] as String?,
      lighting: map['lighting'] as String?,
      whiteNoiseMachine: map['whiteNoiseMachine'] as bool?,
      notes: map['notes'] as String?,
    );
  }
}

class SleepSessionModel {
  final String id;
  final String babyId;
  final String userId;
  
  // Timing
  final DateTime startTime;
  final DateTime? endTime; // null if still sleeping
  final int? durationMinutes; // Calculated when sleep ends
  
  // Classification
  final SleepType type;
  final SleepQuality? quality; // Set when sleep ends
  
  // Details
  final List<SleepInterruption> interruptions;
  final SleepEnvironment? environment;
  final String? location; // 'crib', 'bassinet', 'parent_bed', 'stroller', 'car_seat'
  final String? notes;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive; // true if sleep is ongoing
  
  SleepSessionModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.type,
    this.quality,
    this.interruptions = const [],
    this.environment,
    this.location,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = false,
  });

  // Computed properties
  bool get isNap => type == SleepType.nap;
  bool get isNightSleep => type == SleepType.nightSleep;
  
  Duration? get duration {
    if (durationMinutes != null) {
      return Duration(minutes: durationMinutes!);
    }
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    if (isActive) {
      return DateTime.now().difference(startTime);
    }
    return null;
  }

  int get interruptionCount => interruptions.length;
  
  int get totalInterruptionMinutes {
    return interruptions.fold(0, (sum, i) => sum + i.durationMinutes);
  }

  // Firestore serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationMinutes': durationMinutes,
      'type': type.name,
      'quality': quality?.name,
      'interruptions': interruptions.map((i) => i.toMap()).toList(),
      'environment': environment?.toMap(),
      'location': location,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory SleepSessionModel.fromMap(Map<String, dynamic> map) {
    return SleepSessionModel(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null 
          ? (map['endTime'] as Timestamp).toDate() 
          : null,
      durationMinutes: map['durationMinutes'] as int?,
      type: SleepType.values.firstWhere((e) => e.name == map['type']),
      quality: map['quality'] != null
          ? SleepQuality.values.firstWhere((e) => e.name == map['quality'])
          : null,
      interruptions: (map['interruptions'] as List<dynamic>?)
              ?.map((i) => SleepInterruption.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      environment: map['environment'] != null
          ? SleepEnvironment.fromMap(map['environment'] as Map<String, dynamic>)
          : null,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  factory SleepSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepSessionModel.fromMap({...data, 'id': doc.id});
  }

  SleepSessionModel copyWith({
    String? id,
    String? babyId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    SleepType? type,
    SleepQuality? quality,
    List<SleepInterruption>? interruptions,
    SleepEnvironment? environment,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return SleepSessionModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      quality: quality ?? this.quality,
      interruptions: interruptions ?? this.interruptions,
      environment: environment ?? this.environment,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
```

### 2.2 Flutter Model: `SleepStatsModel`

**File**: `lib/models/sleep_stats_model.dart`

```dart
class SleepStatsModel {
  final String babyId;
  final DateTime date;
  
  // Daily totals
  final int totalSleepMinutes;
  final int nightSleepMinutes;
  final int napMinutes;
  final int napCount;
  
  // Quality metrics
  final double averageQualityScore; // 0-100
  final int totalInterruptions;
  final int totalInterruptionMinutes;
  
  // Timing
  final DateTime? firstSleepStart;
  final DateTime? lastSleepEnd;
  final int? longestNapMinutes;
  final int? longestNightSleepMinutes;
  
  // Computed score
  final int dailySleepScore; // 0-100
  
  SleepStatsModel({
    required this.babyId,
    required this.date,
    required this.totalSleepMinutes,
    required this.nightSleepMinutes,
    required this.napMinutes,
    required this.napCount,
    required this.averageQualityScore,
    required this.totalInterruptions,
    required this.totalInterruptionMinutes,
    this.firstSleepStart,
    this.lastSleepEnd,
    this.longestNapMinutes,
    this.longestNightSleepMinutes,
    required this.dailySleepScore,
  });

  // Computed properties
  Duration get totalSleep => Duration(minutes: totalSleepMinutes);
  Duration get nightSleep => Duration(minutes: nightSleepMinutes);
  Duration get napTime => Duration(minutes: napMinutes);
  
  double get napPercentage {
    if (totalSleepMinutes == 0) return 0;
    return (napMinutes / totalSleepMinutes) * 100;
  }

  // Firestore serialization
  Map<String, dynamic> toMap() {
    return {
      'babyId': babyId,
      'date': Timestamp.fromDate(date),
      'totalSleepMinutes': totalSleepMinutes,
      'nightSleepMinutes': nightSleepMinutes,
      'napMinutes': napMinutes,
      'napCount': napCount,
      'averageQualityScore': averageQualityScore,
      'totalInterruptions': totalInterruptions,
      'totalInterruptionMinutes': totalInterruptionMinutes,
      'firstSleepStart': firstSleepStart != null 
          ? Timestamp.fromDate(firstSleepStart!) 
          : null,
      'lastSleepEnd': lastSleepEnd != null 
          ? Timestamp.fromDate(lastSleepEnd!) 
          : null,
      'longestNapMinutes': longestNapMinutes,
      'longestNightSleepMinutes': longestNightSleepMinutes,
      'dailySleepScore': dailySleepScore,
    };
  }

  factory SleepStatsModel.fromMap(Map<String, dynamic> map) {
    return SleepStatsModel(
      babyId: map['babyId'] as String,
      date: (map['date'] as Timestamp).toDate(),
      totalSleepMinutes: map['totalSleepMinutes'] as int,
      nightSleepMinutes: map['nightSleepMinutes'] as int,
      napMinutes: map['napMinutes'] as int,
      napCount: map['napCount'] as int,
      averageQualityScore: (map['averageQualityScore'] as num).toDouble(),
      totalInterruptions: map['totalInterruptions'] as int,
      totalInterruptionMinutes: map['totalInterruptionMinutes'] as int,
      firstSleepStart: map['firstSleepStart'] != null
          ? (map['firstSleepStart'] as Timestamp).toDate()
          : null,
      lastSleepEnd: map['lastSleepEnd'] != null
          ? (map['lastSleepEnd'] as Timestamp).toDate()
          : null,
      longestNapMinutes: map['longestNapMinutes'] as int?,
      longestNightSleepMinutes: map['longestNightSleepMinutes'] as int?,
      dailySleepScore: map['dailySleepScore'] as int,
    );
  }
}
```

### 2.3 Firestore Schema

#### Collection: `sleep_sessions`

```
sleep_sessions/{sessionId}
├── id: string
├── babyId: string (indexed)
├── userId: string (indexed)
├── startTime: timestamp (indexed)
├── endTime: timestamp | null
├── durationMinutes: number | null
├── type: string ('nap' | 'nightSleep')
├── quality: string | null ('veryPoor' | 'poor' | 'fair' | 'good' | 'excellent')
├── interruptions: array<object>
│   └── {
│       timestamp: timestamp,
│       durationMinutes: number,
│       reason: string | null,
│       notes: string | null
│   }
├── environment: object | null
│   ├── roomTempCelsius: number | null
│   ├── noiseLevel: string | null
│   ├── lighting: string | null
│   ├── whiteNoiseMachine: boolean | null
│   └── notes: string | null
├── location: string | null
├── notes: string | null
├── createdAt: timestamp
├── updatedAt: timestamp
└── isActive: boolean
```

**Firestore Indexes**:
```javascript
// Compound indexes needed
{
  collectionGroup: "sleep_sessions",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "startTime", order: "DESCENDING" }
  ]
}

{
  collectionGroup: "sleep_sessions",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "isActive", order: "ASCENDING" },
    { fieldPath: "startTime", order: "DESCENDING" }
  ]
}
```

#### Collection: `sleep_stats`

```
sleep_stats/{babyId}/daily/{YYYY-MM-DD}
├── babyId: string
├── date: timestamp
├── totalSleepMinutes: number
├── nightSleepMinutes: number
├── napMinutes: number
├── napCount: number
├── averageQualityScore: number
├── totalInterruptions: number
├── totalInterruptionMinutes: number
├── firstSleepStart: timestamp | null
├── lastSleepEnd: timestamp | null
├── longestNapMinutes: number | null
├── longestNightSleepMinutes: number | null
└── dailySleepScore: number
```

---

## 3. Service Layer

### 3.1 SleepService

**File**: `lib/services/sleep_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sleep_session_model.dart';
import '../models/sleep_stats_model.dart';

class SleepService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  CollectionReference get _sleepSessionsCollection =>
      _firestore.collection('sleep_sessions');
  
  CollectionReference _sleepStatsCollection(String babyId) =>
      _firestore.collection('sleep_stats').doc(babyId).collection('daily');

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Start a new sleep session
  Future<SleepSessionModel> startSleep({
    required String babyId,
    required String userId,
    required DateTime startTime,
    required SleepType type,
    String? location,
    SleepEnvironment? environment,
    String? notes,
  }) async {
    // Check for active sleep session
    final activeSleep = await getActiveSleepSession(babyId);
    if (activeSleep != null) {
      throw Exception('Baby already has an active sleep session');
    }

    final now = DateTime.now();
    final session = SleepSessionModel(
      id: '', // Will be set by Firestore
      babyId: babyId,
      userId: userId,
      startTime: startTime,
      type: type,
      location: location,
      environment: environment,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );

    final docRef = await _sleepSessionsCollection.add(session.toMap());
    
    return session.copyWith(id: docRef.id);
  }

  /// End an active sleep session
  Future<SleepSessionModel> endSleep({
    required String sessionId,
    required DateTime endTime,
    required SleepQuality quality,
    List<SleepInterruption>? interruptions,
    String? notes,
  }) async {
    final docRef = _sleepSessionsCollection.doc(sessionId);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      throw Exception('Sleep session not found');
    }

    final session = SleepSessionModel.fromFirestore(doc);
    
    if (!session.isActive) {
      throw Exception('Sleep session is not active');
    }

    final durationMinutes = endTime.difference(session.startTime).inMinutes;

    final updatedSession = session.copyWith(
      endTime: endTime,
      durationMinutes: durationMinutes,
      quality: quality,
      interruptions: interruptions ?? session.interruptions,
      notes: notes ?? session.notes,
      updatedAt: DateTime.now(),
      isActive: false,
    );

    await docRef.update(updatedSession.toMap());
    
    // Trigger stats aggregation
    await _updateDailyStats(updatedSession);

    return updatedSession;
  }

  /// Quick log past sleep session (not real-time)
  Future<SleepSessionModel> quickLogSleep({
    required String babyId,
    required String userId,
    required DateTime startTime,
    required DateTime endTime,
    required SleepType type,
    SleepQuality? quality,
    List<SleepInterruption>? interruptions,
    SleepEnvironment? environment,
    String? location,
    String? notes,
  }) async {
    final durationMinutes = endTime.difference(startTime).inMinutes;
    final now = DateTime.now();

    final session = SleepSessionModel(
      id: '',
      babyId: babyId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      type: type,
      quality: quality,
      interruptions: interruptions ?? [],
      environment: environment,
      location: location,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      isActive: false,
    );

    final docRef = await _sleepSessionsCollection.add(session.toMap());
    final createdSession = session.copyWith(id: docRef.id);
    
    // Trigger stats aggregation
    await _updateDailyStats(createdSession);

    return createdSession;
  }

  /// Add interruption to active sleep session
  Future<void> addInterruption({
    required String sessionId,
    required SleepInterruption interruption,
  }) async {
    final docRef = _sleepSessionsCollection.doc(sessionId);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      throw Exception('Sleep session not found');
    }

    final session = SleepSessionModel.fromFirestore(doc);
    
    if (!session.isActive) {
      throw Exception('Cannot add interruption to completed sleep session');
    }

    final updatedInterruptions = [...session.interruptions, interruption];

    await docRef.update({
      'interruptions': updatedInterruptions.map((i) => i.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update sleep session
  Future<void> updateSleepSession({
    required String sessionId,
    SleepType? type,
    SleepQuality? quality,
    String? location,
    SleepEnvironment? environment,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (type != null) updates['type'] = type.name;
    if (quality != null) updates['quality'] = quality.name;
    if (location != null) updates['location'] = location;
    if (environment != null) updates['environment'] = environment.toMap();
    if (notes != null) updates['notes'] = notes;

    await _sleepSessionsCollection.doc(sessionId).update(updates);
  }

  /// Delete sleep session
  Future<void> deleteSleepSession(String sessionId) async {
    final doc = await _sleepSessionsCollection.doc(sessionId).get();
    if (doc.exists) {
      final session = SleepSessionModel.fromFirestore(doc);
      await _sleepSessionsCollection.doc(sessionId).delete();
      
      // Re-aggregate stats for that day
      await _recalculateDailyStats(session.babyId, session.startTime);
    }
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /// Get active sleep session for baby
  Future<SleepSessionModel?> getActiveSleepSession(String babyId) async {
    final snapshot = await _sleepSessionsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return SleepSessionModel.fromFirestore(snapshot.docs.first);
  }

  /// Stream active sleep session
  Stream<SleepSessionModel?> streamActiveSleepSession(String babyId) {
    return _sleepSessionsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SleepSessionModel.fromFirestore(snapshot.docs.first);
    });
  }

  /// Get sleep sessions for date range
  Future<List<SleepSessionModel>> getSleepSessions({
    required String babyId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _sleepSessionsCollection
        .where('babyId', isEqualTo: babyId)
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
    return snapshot.docs
        .map((doc) => SleepSessionModel.fromFirestore(doc))
        .toList();
  }

  /// Stream sleep sessions for today
  Stream<List<SleepSessionModel>> streamTodaySleepSessions(String babyId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _sleepSessionsCollection
        .where('babyId', isEqualTo: babyId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SleepSessionModel.fromFirestore(doc))
            .toList());
  }

  // ============================================================================
  // Stats Operations
  // ============================================================================

  /// Get daily sleep stats
  Future<SleepStatsModel?> getDailyStats({
    required String babyId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final doc = await _sleepStatsCollection(babyId).doc(dateStr).get();
    
    if (!doc.exists) {
      return null;
    }

    return SleepStatsModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  /// Get weekly sleep stats
  Future<List<SleepStatsModel>> getWeeklyStats({
    required String babyId,
    required DateTime weekStart,
  }) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    final snapshot = await _sleepStatsCollection(babyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('date', isLessThan: Timestamp.fromDate(weekEnd))
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => SleepStatsModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /// Update daily stats after sleep session ends
  Future<void> _updateDailyStats(SleepSessionModel session) async {
    if (session.endTime == null) return;

    final date = session.startTime;
    final dateStr = _formatDate(date);
    
    // Get all sessions for this day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final sessions = await getSleepSessions(
      babyId: session.babyId,
      startDate: startOfDay,
      endDate: endOfDay,
    );

    // Calculate stats
    int totalSleep = 0;
    int nightSleep = 0;
    int napSleep = 0;
    int napCount = 0;
    int totalInterruptions = 0;
    int totalInterruptionMinutes = 0;
    double qualitySum = 0;
    int qualityCount = 0;
    DateTime? firstSleepStart;
    DateTime? lastSleepEnd;
    int? longestNap;
    int? longestNight;

    for (final s in sessions) {
      if (s.durationMinutes == null) continue;

      totalSleep += s.durationMinutes!;
      
      if (s.isNap) {
        napSleep += s.durationMinutes!;
        napCount++;
        if (longestNap == null || s.durationMinutes! > longestNap) {
          longestNap = s.durationMinutes;
        }
      } else {
        nightSleep += s.durationMinutes!;
        if (longestNight == null || s.durationMinutes! > longestNight) {
          longestNight = s.durationMinutes;
        }
      }

      totalInterruptions += s.interruptionCount;
      totalInterruptionMinutes += s.totalInterruptionMinutes;

      if (s.quality != null) {
        qualitySum += s.quality!.score;
        qualityCount++;
      }

      if (firstSleepStart == null || s.startTime.isBefore(firstSleepStart)) {
        firstSleepStart = s.startTime;
      }

      if (s.endTime != null) {
        if (lastSleepEnd == null || s.endTime!.isAfter(lastSleepEnd)) {
          lastSleepEnd = s.endTime;
        }
      }
    }

    final avgQuality = qualityCount > 0 ? qualitySum / qualityCount : 0.0;
    
    // Calculate daily sleep score (0-100)
    final sleepScore = _calculateDailySleepScore(
      totalSleepMinutes: totalSleep,
      averageQuality: avgQuality,
      interruptionCount: totalInterruptions,
      babyAgeMonths: 3, // TODO: Get from baby profile
    );

    final stats = SleepStatsModel(
      babyId: session.babyId,
      date: startOfDay,
      totalSleepMinutes: totalSleep,
      nightSleepMinutes: nightSleep,
      napMinutes: napSleep,
      napCount: napCount,
      averageQualityScore: avgQuality,
      totalInterruptions: totalInterruptions,
      totalInterruptionMinutes: totalInterruptionMinutes,
      firstSleepStart: firstSleepStart,
      lastSleepEnd: lastSleepEnd,
      longestNapMinutes: longestNap,
      longestNightSleepMinutes: longestNight,
      dailySleepScore: sleepScore,
    );

    await _sleepStatsCollection(session.babyId)
        .doc(dateStr)
        .set(stats.toMap(), SetOptions(merge: true));
  }

  /// Recalculate daily stats (after deletion)
  Future<void> _recalculateDailyStats(String babyId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final sessions = await getSleepSessions(
      babyId: babyId,
      startDate: startOfDay,
      endDate: endOfDay,
    );

    if (sessions.isEmpty) {
      // Delete stats document
      await _sleepStatsCollection(babyId).doc(_formatDate(date)).delete();
    } else {
      // Recalculate from first session
      await _updateDailyStats(sessions.first);
    }
  }

  /// Calculate daily sleep score (0-100)
  int _calculateDailySleepScore({
    required int totalSleepMinutes,
    required double averageQuality,
    required int interruptionCount,
    required int babyAgeMonths,
  }) {
    // Recommended sleep by age (in hours)
    final recommendedSleep = _getRecommendedSleepHours(babyAgeMonths);
    final recommendedMinutes = recommendedSleep * 60;

    // Score components
    double durationScore = 0;
    double qualityScore = averageQuality;
    double interruptionScore = 100;

    // Duration score (40% weight)
    if (totalSleepMinutes >= recommendedMinutes) {
      durationScore = 100;
    } else {
      durationScore = (totalSleepMinutes / recommendedMinutes) * 100;
    }

    // Quality score (40% weight) - already 0-100

    // Interruption penalty (20% weight)
    if (interruptionCount == 0) {
      interruptionScore = 100;
    } else if (interruptionCount <= 2) {
      interruptionScore = 80;
    } else if (interruptionCount <= 4) {
      interruptionScore = 60;
    } else {
      interruptionScore = 40;
    }

    // Weighted average
    final finalScore = (durationScore * 0.4) + 
                      (qualityScore * 0.4) + 
                      (interruptionScore * 0.2);

    return finalScore.round().clamp(0, 100);
  }

  /// Get recommended sleep hours by age
  double _getRecommendedSleepHours(int ageMonths) {
    if (ageMonths <= 3) return 16.0; // Newborn: 14-17 hours
    if (ageMonths <= 11) return 14.0; // Infant: 12-15 hours
    if (ageMonths <= 24) return 13.0; // Toddler: 11-14 hours
    return 12.0; // 2-3 years: 11-14 hours
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
```

---

## 4. Cloud Functions

### 4.1 Daily Stats Aggregation

**File**: `functions/src/sleep/aggregateDailyStats.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface SleepSession {
  babyId: string;
  startTime: admin.firestore.Timestamp;
  endTime: admin.firestore.Timestamp | null;
  durationMinutes: number | null;
  type: 'nap' | 'nightSleep';
  quality: string | null;
  interruptions: Array<{
    durationMinutes: number;
  }>;
}

/**
 * Trigger: When a sleep session is created or updated
 * Action: Update daily sleep statistics
 */
export const onSleepSessionUpdate = functions.firestore
  .document('sleep_sessions/{sessionId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() as SleepSession : null;
    const before = change.before.exists ? change.before.data() as SleepSession : null;

    // Only process completed sleep sessions
    if (!after || after.endTime === null) {
      return null;
    }

    const babyId = after.babyId;
    const sleepDate = after.startTime.toDate();
    const dateStr = formatDate(sleepDate);

    // Get all sleep sessions for this day
    const startOfDay = new Date(sleepDate.getFullYear(), sleepDate.getMonth(), sleepDate.getDate());
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const sessionsSnapshot = await admin.firestore()
      .collection('sleep_sessions')
      .where('babyId', '==', babyId)
      .where('startTime', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
      .where('startTime', '<', admin.firestore.Timestamp.fromDate(endOfDay))
      .where('endTime', '!=', null)
      .get();

    // Calculate aggregate stats
    let totalSleepMinutes = 0;
    let nightSleepMinutes = 0;
    let napMinutes = 0;
    let napCount = 0;
    let totalInterruptions = 0;
    let totalInterruptionMinutes = 0;
    let qualitySum = 0;
    let qualityCount = 0;
    let firstSleepStart: Date | null = null;
    let lastSleepEnd: Date | null = null;
    let longestNap = 0;
    let longestNight = 0;

    sessionsSnapshot.forEach(doc => {
      const session = doc.data() as SleepSession;
      
      if (session.durationMinutes) {
        totalSleepMinutes += session.durationMinutes;
        
        if (session.type === 'nap') {
          napMinutes += session.durationMinutes;
          napCount++;
          longestNap = Math.max(longestNap, session.durationMinutes);
        } else {
          nightSleepMinutes += session.durationMinutes;
          longestNight = Math.max(longestNight, session.durationMinutes);
        }
      }

      totalInterruptions += session.interruptions?.length || 0;
      session.interruptions?.forEach(i => {
        totalInterruptionMinutes += i.durationMinutes;
      });

      if (session.quality) {
        qualitySum += getQualityScore(session.quality);
        qualityCount++;
      }

      const sessionStart = session.startTime.toDate();
      const sessionEnd = session.endTime?.toDate();

      if (!firstSleepStart || sessionStart < firstSleepStart) {
        firstSleepStart = sessionStart;
      }

      if (sessionEnd && (!lastSleepEnd || sessionEnd > lastSleepEnd)) {
        lastSleepEnd = sessionEnd;
      }
    });

    const averageQuality = qualityCount > 0 ? qualitySum / qualityCount : 0;
    
    // Calculate daily sleep score
    const dailySleepScore = calculateDailySleepScore({
      totalSleepMinutes,
      averageQuality,
      interruptionCount: totalInterruptions,
      babyAgeMonths: 3, // TODO: Get from baby profile
    });

    // Update stats document
    const statsRef = admin.firestore()
      .collection('sleep_stats')
      .doc(babyId)
      .collection('daily')
      .doc(dateStr);

    await statsRef.set({
      babyId,
      date: admin.firestore.Timestamp.fromDate(startOfDay),
      totalSleepMinutes,
      nightSleepMinutes,
      napMinutes,
      napCount,
      averageQualityScore: averageQuality,
      totalInterruptions,
      totalInterruptionMinutes,
      firstSleepStart: firstSleepStart ? admin.firestore.Timestamp.fromDate(firstSleepStart) : null,
      lastSleepEnd: lastSleepEnd ? admin.firestore.Timestamp.fromDate(lastSleepEnd) : null,
      longestNapMinutes: longestNap > 0 ? longestNap : null,
      longestNightSleepMinutes: longestNight > 0 ? longestNight : null,
      dailySleepScore,
    }, { merge: true });

    return null;
  });

function getQualityScore(quality: string): number {
  const scores: Record<string, number> = {
    veryPoor: 20,
    poor: 40,
    fair: 60,
    good: 80,
    excellent: 100,
  };
  return scores[quality] || 0;
}

function calculateDailySleepScore(params: {
  totalSleepMinutes: number;
  averageQuality: number;
  interruptionCount: number;
  babyAgeMonths: number;
}): number {
  const { totalSleepMinutes, averageQuality, interruptionCount, babyAgeMonths } = params;
  
  // Recommended sleep by age (in hours)
  let recommendedHours = 16;
  if (babyAgeMonths > 3) recommendedHours = 14;
  if (babyAgeMonths > 11) recommendedHours = 13;
  if (babyAgeMonths > 24) recommendedHours = 12;
  
  const recommendedMinutes = recommendedHours * 60;

  // Duration score (40%)
  let durationScore = Math.min(100, (totalSleepMinutes / recommendedMinutes) * 100);

  // Quality score (40%)
  const qualityScore = averageQuality;

  // Interruption score (20%)
  let interruptionScore = 100;
  if (interruptionCount > 0) interruptionScore = 80;
  if (interruptionCount > 2) interruptionScore = 60;
  if (interruptionCount > 4) interruptionScore = 40;

  const finalScore = (durationScore * 0.4) + (qualityScore * 0.4) + (interruptionScore * 0.2);
  
  return Math.round(Math.max(0, Math.min(100, finalScore)));
}

function formatDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padLeft(2, '0');
  const day = String(date.getDate()).padLeft(2, '0');
  return `${year}-${month}-${day}`;
}
```

### 4.2 Sleep Pattern Insights

**File**: `functions/src/sleep/generateSleepInsights.ts`

```typescript
/**
 * Scheduled function: Run daily at 8 AM
 * Generate sleep pattern insights and recommendations
 */
export const generateDailySleepInsights = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    
    // Get all babies
    const babiesSnapshot = await admin.firestore().collection('babies').get();
    
    for (const babyDoc of babiesSnapshot.docs) {
      const babyId = babyDoc.id;
      const babyData = babyDoc.data();
      
      // Get last 7 days of sleep stats
      const weekAgo = new Date(yesterday);
      weekAgo.setDate(weekAgo.getDate() - 7);
      
      const statsSnapshot = await admin.firestore()
        .collection('sleep_stats')
        .doc(babyId)
        .collection('daily')
        .where('date', '>=', admin.firestore.Timestamp.fromDate(weekAgo))
        .where('date', '<=', admin.firestore.Timestamp.fromDate(yesterday))
        .orderBy('date', 'desc')
        .get();
      
      if (statsSnapshot.empty) continue;
      
      // Analyze patterns
      const insights = analyzeSleepPatterns(statsSnapshot.docs.map(doc => doc.data()));
      
      // Store insights
      await admin.firestore()
        .collection('sleep_insights')
        .doc(babyId)
        .collection('weekly')
        .doc(formatDate(yesterday))
        .set({
          babyId,
          weekEnding: admin.firestore.Timestamp.fromDate(yesterday),
          insights,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      // Send notification if significant pattern detected
      if (insights.alert) {
        await sendSleepAlert(babyData.parentUserId, insights);
      }
    }
    
    return null;
  });

function analyzeSleepPatterns(weekStats: any[]): any {
  // Calculate weekly averages
  const avgTotalSleep = weekStats.reduce((sum, s) => sum + s.totalSleepMinutes, 0) / weekStats.length;
  const avgQuality = weekStats.reduce((sum, s) => sum + s.averageQualityScore, 0) / weekStats.length;
  const avgInterruptions = weekStats.reduce((sum, s) => sum + s.totalInterruptions, 0) / weekStats.length;
  
  // Detect trends
  const trend = detectTrend(weekStats);
  
  // Generate insights
  const insights: any = {
    weeklyAverageSleepHours: (avgTotalSleep / 60).toFixed(1),
    averageQualityScore: Math.round(avgQuality),
    averageInterruptions: Math.round(avgInterruptions),
    trend,
    recommendations: [],
    alert: null,
  };
  
  // Recommendations
  if (avgTotalSleep < 720) { // Less than 12 hours
    insights.recommendations.push('Baby is sleeping less than recommended. Consider earlier bedtime.');
  }
  
  if (avgInterruptions > 3) {
    insights.recommendations.push('Frequent wake-ups detected. Try sleep training techniques.');
  }
  
  if (avgQuality < 60) {
    insights.recommendations.push('Sleep quality is below average. Review sleep environment.');
    insights.alert = 'low_sleep_quality';
  }
  
  return insights;
}

function detectTrend(stats: any[]): string {
  if (stats.length < 3) return 'stable';
  
  const recent = stats.slice(0, 3).reduce((sum, s) => sum + s.totalSleepMinutes, 0) / 3;
  const older = stats.slice(-3).reduce((sum, s) => sum + s.totalSleepMinutes, 0) / 3;
  
  if (recent > older * 1.1) return 'improving';
  if (recent < older * 0.9) return 'declining';
  return 'stable';
}
```

---

## 5. UI Components

### 5.1 Sleep Timer Widget

**File**: `lib/widgets/sleep/sleep_timer_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/sleep_session_model.dart';

class SleepTimerWidget extends StatefulWidget {
  final SleepSessionModel? activeSession;
  final VoidCallback onStop;

  const SleepTimerWidget({
    Key? key,
    this.activeSession,
    required this.onStop,
  }) : super(key: key);

  @override
  State<SleepTimerWidget> createState() => _SleepTimerWidgetState();
}

class _SleepTimerWidgetState extends State<SleepTimerWidget> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.activeSession != null) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.activeSession!.startTime);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeSession == null) {
      return const SizedBox.shrink();
    }

    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.activeSession!.isNap ? Icons.wb_sunny : Icons.nightlight,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                widget.activeSession!.type.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Timer display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HR'),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(color: Colors.white, fontSize: 32)),
              const SizedBox(width: 8),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MIN'),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(color: Colors.white, fontSize: 32)),
              const SizedBox(width: 8),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SEC'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Started at
          Text(
            'Started at ${_formatTime(widget.activeSession!.startTime)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Stop button
          ElevatedButton.icon(
            onPressed: widget.onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Sleep'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
```

### 5.2 Sleep Session Card

**File**: `lib/widgets/sleep/sleep_session_card.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/sleep_session_model.dart';
import 'package:intl/intl.dart';

class SleepSessionCard extends StatelessWidget {
  final SleepSessionModel session;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SleepSessionCard({
    Key? key,
    required this.session,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: session.isNap 
                          ? Colors.orange.shade50 
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      session.isNap ? Icons.wb_sunny : Icons.nightlight,
                      color: session.isNap 
                          ? Colors.orange.shade700 
                          : Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Type and duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.type.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(session.duration),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: session.isNap 
                                ? Colors.orange.shade700 
                                : Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Quality stars
                  if (session.quality != null)
                    _buildQualityStars(session.quality!),
                  
                  // Delete button
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      color: Colors.grey,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Time range
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeRange(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              
              // Interruptions
              if (session.interruptionCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${session.interruptionCount} interruption(s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Location
              if (session.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.bed, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _formatLocation(session.location!),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Notes
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityStars(SleepQuality quality) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < quality.stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatTimeRange() {
    final startTime = DateFormat('h:mm a').format(session.startTime);
    final endTime = session.endTime != null 
        ? DateFormat('h:mm a').format(session.endTime!)
        : 'ongoing';
    return '$startTime - $endTime';
  }

  String _formatLocation(String location) {
    return location
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
```

### 5.3 Daily Sleep Summary

**File**: `lib/widgets/sleep/daily_sleep_summary.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/sleep_stats_model.dart';

class DailySleepSummary extends StatelessWidget {
  final SleepStatsModel stats;

  const DailySleepSummary({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Sleep',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // Sleep score
                _buildScoreBadge(stats.dailySleepScore),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Total sleep
            _buildStatRow(
              icon: Icons.bedtime,
              label: 'Total Sleep',
              value: _formatDuration(stats.totalSleep),
              color: Colors.indigo,
            ),
            
            const Divider(height: 24),
            
            // Night vs Nap breakdown
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.nightlight,
                    label: 'Night Sleep',
                    value: _formatDuration(stats.nightSleep),
                    color: Colors.indigo.shade300,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.wb_sunny,
                    label: 'Naps',
                    value: _formatDuration(stats.napTime),
                    subtitle: '${stats.napCount} nap(s)',
                    color: Colors.orange.shade300,
                  ),
                ),
              ],
            ),
            
            if (stats.totalInterruptions > 0) ...[
              const Divider(height: 24),
              
              // Interruptions
              _buildStatRow(
                icon: Icons.warning_amber,
                label: 'Interruptions',
                value: '${stats.totalInterruptions}',
                subtitle: '${stats.totalInterruptionMinutes} min total',
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(int score) {
    Color color;
    if (score >= 80) {
      color = Colors.green;
    } else if (score >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
```

---

## 6. User Flows

### 6.1 Start Sleep Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   START SLEEP FLOW                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User taps "Start Sleep" button on Dashboard             │
│      │                                                       │
│      ▼                                                       │
│  2. Show "Start Sleep" bottom sheet                         │
│      ├─ Select sleep type (Nap / Night Sleep)              │
│      ├─ Optional: Adjust start time                         │
│      ├─ Optional: Select location                           │
│      └─ Optional: Add notes                                 │
│      │                                                       │
│      ▼                                                       │
│  3. User taps "Start" button                                │
│      │                                                       │
│      ▼                                                       │
│  4. Call SleepService.startSleep()                          │
│      ├─ Validate no active sleep exists                     │
│      ├─ Create sleep session in Firestore                   │
│      └─ Set isActive = true                                 │
│      │                                                       │
│      ▼                                                       │
│  5. Update UI to show active sleep timer                     │
│      ├─ Display elapsed time (HH:MM:SS)                     │
│      ├─ Show "Stop Sleep" button                            │
│      └─ Lock other babies from starting sleep               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 End Sleep Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    END SLEEP FLOW                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User taps "Stop Sleep" button                           │
│      │                                                       │
│      ▼                                                       │
│  2. Show "End Sleep" bottom sheet                           │
│      ├─ Display total duration (auto-calculated)            │
│      ├─ Select sleep quality (1-5 stars)                    │
│      ├─ Optional: Log interruptions                         │
│      │   ├─ Time of wake-up                                 │
│      │   ├─ Duration awake                                  │
│      │   └─ Reason (feeding, diaper, crying, other)         │
│      ├─ Optional: Add environment details                   │
│      │   ├─ Room temperature                                │
│      │   ├─ Noise level                                     │
│      │   └─ Lighting                                        │
│      └─ Optional: Add notes                                 │
│      │                                                       │
│      ▼                                                       │
│  3. User taps "Save" button                                 │
│      │                                                       │
│      ▼                                                       │
│  4. Call SleepService.endSleep()                            │
│      ├─ Update session with endTime                         │
│      ├─ Calculate durationMinutes                           │
│      ├─ Set quality, interruptions, notes                   │
│      ├─ Set isActive = false                                │
│      └─ Trigger Cloud Function for stats aggregation        │
│      │                                                       │
│      ▼                                                       │
│  5. Update UI                                               │
│      ├─ Hide sleep timer                                    │
│      ├─ Add session to history list                         │
│      ├─ Update daily stats card                             │
│      └─ Show success message                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 Quick Log Past Sleep Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  QUICK LOG PAST SLEEP                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User taps "+" (Add) or "Log Past Sleep"                 │
│      │                                                       │
│      ▼                                                       │
│  2. Show "Log Sleep" form                                   │
│      ├─ Select date (default: today)                        │
│      ├─ Select start time                                   │
│      ├─ Select end time                                     │
│      ├─ Auto-calculate duration                             │
│      ├─ Select sleep type (Nap / Night Sleep)              │
│      ├─ Select quality (1-5 stars)                          │
│      ├─ Optional: Add interruptions                         │
│      ├─ Optional: Select location                           │
│      └─ Optional: Add notes                                 │
│      │                                                       │
│      ▼                                                       │
│  3. User taps "Save" button                                 │
│      │                                                       │
│      ▼                                                       │
│  4. Validate inputs                                         │
│      ├─ End time must be after start time                   │
│      ├─ Duration must be reasonable (< 18 hours)            │
│      └─ No overlapping sleep sessions                       │
│      │                                                       │
│      ▼                                                       │
│  5. Call SleepService.quickLogSleep()                       │
│      ├─ Create completed sleep session                      │
│      ├─ Set isActive = false                                │
│      └─ Trigger stats aggregation                           │
│      │                                                       │
│      ▼                                                       │
│  6. Update UI                                               │
│      ├─ Add to session list                                 │
│      ├─ Update daily stats                                  │
│      └─ Show success message                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Analytics & Insights

### 7.1 Sleep Score Calculation

**Daily Sleep Score** (0-100) is calculated using three weighted components:

```dart
Daily Sleep Score = (Duration Score × 40%) + (Quality Score × 40%) + (Interruption Score × 20%)
```

**1. Duration Score (40% weight)**:
```dart
recommendedSleep = getRecommendedSleepByAge(babyAgeMonths);
durationScore = min(100, (totalSleepMinutes / recommendedSleep) × 100);
```

Recommended sleep by age:
- 0-3 months: 16 hours (14-17 range)
- 4-11 months: 14 hours (12-15 range)
- 12-24 months: 13 hours (11-14 range)
- 2-3 years: 12 hours (11-14 range)

**2. Quality Score (40% weight)**:
```dart
qualityScore = averageOf(allSessionQualityScores);

// Quality to score mapping:
veryPoor = 20
poor = 40
fair = 60
good = 80
excellent = 100
```

**3. Interruption Score (20% weight)**:
```dart
if (interruptionCount == 0) → 100
if (interruptionCount <= 2) → 80
if (interruptionCount <= 4) → 60
else → 40
```

**Example**:
```
Baby: 6 months old
Total Sleep: 780 minutes (13 hours)
Recommended: 840 minutes (14 hours)
Average Quality: 80 (Good)
Interruptions: 3

Duration Score = (780 / 840) × 100 = 92.9
Quality Score = 80
Interruption Score = 60

Final Score = (92.9 × 0.4) + (80 × 0.4) + (60 × 0.2)
            = 37.16 + 32 + 12
            = 81.16 → 81
```

### 7.2 Pattern Detection

**Sleep Regression Detection**:
```typescript
function detectSleepRegression(weeklyStats: SleepStats[]): boolean {
  // Compare last 3 days to previous 4 days
  const recent = weeklyStats.slice(0, 3);
  const baseline = weeklyStats.slice(3, 7);
  
  const recentAvg = average(recent.map(s => s.totalSleepMinutes));
  const baselineAvg = average(baseline.map(s => s.totalSleepMinutes));
  
  // Regression if sleep decreased by >15% AND interruptions increased
  if (recentAvg < baselineAvg * 0.85) {
    const recentInterruptions = average(recent.map(s => s.totalInterruptions));
    const baselineInterruptions = average(baseline.map(s => s.totalInterruptions));
    
    if (recentInterruptions > baselineInterruptions * 1.3) {
      return true; // Sleep regression detected
    }
  }
  
  return false;
}
```

**Optimal Sleep Window Prediction**:
```typescript
function predictOptimalSleepWindow(historicalData: SleepSession[]): TimeWindow {
  // Find most common bedtime over last 14 days
  const nightSleeps = historicalData.filter(s => s.type === 'nightSleep');
  const bedtimes = nightSleeps.map(s => s.startTime.getHours() + s.startTime.getMinutes() / 60);
  
  // Calculate median bedtime
  const medianBedtime = median(bedtimes);
  
  // Recommend ±30 minutes window
  return {
    earliest: medianBedtime - 0.5,
    optimal: medianBedtime,
    latest: medianBedtime + 0.5,
  };
}
```

---

## 8. Implementation Roadmap

### Phase 1: Core Functionality (Week 1-2)

**Week 1: Data Layer**
- [ ] Create `SleepSessionModel` with all enums
- [ ] Create `SleepStatsModel`
- [ ] Implement `SleepService` CRUD operations
- [ ] Write unit tests for models and service
- [ ] Set up Firestore collections and indexes

**Week 2: UI & Real-time Tracking**
- [ ] Build `SleepTimerWidget` with live countdown
- [ ] Create start/stop sleep bottom sheets
- [ ] Implement `SleepSessionCard` for history
- [ ] Build `DailySleepSummary` widget
- [ ] Integrate with dashboard

### Phase 2: Advanced Features (Week 3)

**Week 3: Analytics & Cloud Functions**
- [ ] Deploy `onSleepSessionUpdate` Cloud Function
- [ ] Implement daily stats aggregation
- [ ] Build weekly stats queries
- [ ] Create sleep charts (line, bar, pie)
- [ ] Add sleep score visualization

### Phase 3: Insights & Optimization (Week 4)

**Week 4: Pattern Detection**
- [ ] Deploy `generateDailySleepInsights` scheduled function
- [ ] Implement sleep regression detection
- [ ] Build optimal sleep window predictor
- [ ] Create sleep tips based on patterns
- [ ] Add FCM notifications for insights

### Phase 4: Polish (Week 5)

**Week 5: UX Enhancements**
- [ ] Add quick log past sleep form
- [ ] Implement interruption logging
- [ ] Build environment tracking UI
- [ ] Add sleep location picker
- [ ] Create CSV/PDF export

---

## 9. Testing Strategy

### 9.1 Unit Tests

```dart
// test/unit/models/sleep_session_model_test.dart
void main() {
  group('SleepSessionModel', () {
    test('should calculate duration correctly', () {
      final session = SleepSessionModel(
        id: 'test',
        babyId: 'baby1',
        userId: 'user1',
        startTime: DateTime(2026, 2, 1, 19, 0),
        endTime: DateTime(2026, 2, 2, 7, 30),
        durationMinutes: 750,
        type: SleepType.nightSleep,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(session.duration!.inMinutes, 750);
      expect(session.duration!.inHours, 12);
    });
    
    test('should serialize to/from Firestore correctly', () {
      final session = SleepSessionModel(...);
      final map = session.toMap();
      final restored = SleepSessionModel.fromMap(map);
      
      expect(restored.id, session.id);
      expect(restored.type, session.type);
      expect(restored.durationMinutes, session.durationMinutes);
    });
  });
}
```

### 9.2 Widget Tests

```dart
// test/widgets/sleep/sleep_timer_widget_test.dart
void main() {
  testWidgets('SleepTimerWidget displays correct time', (tester) async {
    final startTime = DateTime.now().subtract(Duration(hours: 2, minutes: 30));
    final session = SleepSessionModel(..., startTime: startTime);
    
    await tester.pumpWidget(
      MaterialApp(
        home: SleepTimerWidget(
          activeSession: session,
          onStop: () {},
        ),
      ),
    );
    
    expect(find.text('02'), findsOneWidget); // Hours
    expect(find.text('30'), findsOneWidget); // Minutes
  });
}
```

### 9.3 Integration Tests

```dart
// test/integration/sleep_tracking_test.dart
void main() {
  testWidgets('Complete sleep tracking flow', (tester) async {
    // 1. Start sleep
    await tester.tap(find.text('Start Sleep'));
    await tester.pumpAndSettle();
    
    // 2. Select type
    await tester.tap(find.text('Night Sleep'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    
    // 3. Verify timer running
    expect(find.byType(SleepTimerWidget), findsOneWidget);
    
    // 4. Stop sleep
    await tester.tap(find.text('Stop Sleep'));
    await tester.pumpAndSettle();
    
    // 5. Rate quality
    await tester.tap(find.byIcon(Icons.star).at(3)); // 4 stars
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    
    // 6. Verify session saved
    expect(find.byType(SleepSessionCard), findsOneWidget);
  });
}
```

---

## 10. Future Enhancements

### 10.1 Automated Sleep Detection (Phase 2)

- Integration with mmWave sensor for automatic sleep/wake detection
- Replace manual start/stop with sensor-driven tracking
- Auto-categorize naps vs night sleep based on time and duration
- See: `SLEEP_ANALYSIS_LLD.md`

### 10.2 Advanced Analytics

- Sleep cycle prediction (light/deep/REM estimation)
- Bedtime routine effectiveness tracking
- Sleep environment correlation analysis
- Multi-baby comparison for families with twins/siblings

### 10.3 Integrations

- Export to Apple Health / Google Fit
- Integration with smart home (auto-dim lights, white noise)
- Wearable sync (if parent wearing fitness tracker)
- Pediatrician report generation

---

## 11. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Daily Active Users (Sleep) | 75% of total users | Analytics |
| Average Sessions/Day | 5-8 sessions | Firestore aggregation |
| Quick Log Usage | 30% of all sessions | Event tracking |
| Sleep Score >80 | 60% of days | Stats analysis |
| Feature Retention (30-day) | 85% | Cohort analysis |
| Time to Complete Log | <30 seconds | User timing analytics |

---

**Next Steps**: 
1. Review and approve this LLD
2. Begin Phase 1 implementation (Data Layer)
3. Create `SLEEP_ANALYSIS_LLD.md` for automated sensor-based tracking

