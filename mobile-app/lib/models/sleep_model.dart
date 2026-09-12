import 'package:cloud_firestore/cloud_firestore.dart';

/// Sleep session model
/// Ported from React Native SleepSession type
class SleepSession {
  final String id;
  final String babyId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? totalMinutes;
  final List<SleepStage> stages;
  final SleepQuality? quality;
  final int? wakeCount;
  final DateTime createdAt;

  SleepSession({
    required this.id,
    required this.babyId,
    required this.startTime,
    this.endTime,
    this.totalMinutes,
    this.stages = const [],
    this.quality,
    this.wakeCount,
    required this.createdAt,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    if (totalMinutes != null) {
      return Duration(minutes: totalMinutes!);
    }
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationDisplay {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Calculate percentage of each sleep stage
  Map<SleepStageType, double> get stagePercentages {
    if (stages.isEmpty) return {};

    final totalMinutes = stages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationMinutes,
    );

    if (totalMinutes == 0) return {};

    final Map<SleepStageType, int> stageTotals = {};
    for (final stage in stages) {
      stageTotals[stage.stage] =
          (stageTotals[stage.stage] ?? 0) + stage.durationMinutes;
    }

    return stageTotals.map(
      (key, value) => MapEntry(key, value / totalMinutes * 100),
    );
  }

  factory SleepSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepSession(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      totalMinutes: data['totalMinutes'],
      stages: (data['stages'] as List<dynamic>?)
              ?.map((s) => SleepStage.fromMap(s))
              .toList() ??
          [],
      quality: data['quality'] != null
          ? SleepQuality.fromString(data['quality'])
          : null,
      wakeCount: data['wakeCount'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory SleepSession.fromMap(Map<String, dynamic> data) {
    return SleepSession(
      id: data['id'] ?? '',
      babyId: data['babyId'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      totalMinutes: data['totalMinutes'],
      stages: (data['stages'] as List<dynamic>?)
              ?.map((s) => SleepStage.fromMap(s))
              .toList() ??
          [],
      quality: data['quality'] != null
          ? SleepQuality.fromString(data['quality'])
          : null,
      wakeCount: data['wakeCount'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'totalMinutes': totalMinutes,
      'stages': stages.map((s) => s.toMap()).toList(),
      'quality': quality?.value,
      'wakeCount': wakeCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Individual sleep stage within a session
class SleepStage {
  final SleepStageType stage;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime endTime;

  SleepStage({
    required this.stage,
    required this.durationMinutes,
    required this.startTime,
    required this.endTime,
  });

  factory SleepStage.fromMap(Map<String, dynamic> map) {
    return SleepStage(
      stage: SleepStageType.fromString(map['stage']),
      durationMinutes: map['durationMinutes'] ?? 0,
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stage': stage.value,
      'durationMinutes': durationMinutes,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
    };
  }
}

/// Sleep stage type enum
enum SleepStageType {
  deep('Deep'),
  light('Light'),
  rem('REM'),
  awake('Awake');

  final String value;
  const SleepStageType(this.value);

  static SleepStageType fromString(String? value) {
    return SleepStageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SleepStageType.light,
    );
  }
}

/// Sleep quality rating enum
enum SleepQuality {
  excellent('excellent'),
  good('good'),
  fair('fair'),
  poor('poor');

  final String value;
  const SleepQuality(this.value);

  static SleepQuality fromString(String? value) {
    return SleepQuality.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SleepQuality.fair,
    );
  }
}

/// Vital log entry for historical tracking
class VitalLog {
  final String id;
  final String babyId;
  final int? heartRate;
  final int? spO2;
  final double? temperature;
  final DateTime timestamp;

  VitalLog({
    required this.id,
    required this.babyId,
    this.heartRate,
    this.spO2,
    this.temperature,
    required this.timestamp,
  });

  factory VitalLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitalLog(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      heartRate: data['heartRate'],
      spO2: data['spO2'],
      temperature: (data['temperature'] as num?)?.toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory VitalLog.fromMap(Map<String, dynamic> data) {
    return VitalLog(
      id: data['id'] ?? '',
      babyId: data['babyId'] ?? '',
      heartRate: data['heartRate'],
      spO2: data['spO2'],
      temperature: (data['temperature'] as num?)?.toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'heartRate': heartRate,
      'spO2': spO2,
      'temperature': temperature,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

// CryEvent has been moved to cry_event_model.dart

/// Wetness event model
class WetnessEvent {
  final String id;
  final String babyId;
  final DateTime detectedAt;
  final String severity;
  final bool acknowledged;
  final DateTime? acknowledgedAt;

  WetnessEvent({
    required this.id,
    required this.babyId,
    required this.detectedAt,
    this.severity = 'moderate',
    this.acknowledged = false,
    this.acknowledgedAt,
  });

  factory WetnessEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WetnessEvent(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      detectedAt:
          (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      severity: data['severity'] ?? 'moderate',
      acknowledged: data['acknowledged'] ?? false,
      acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'severity': severity,
      'acknowledged': acknowledged,
      'acknowledgedAt':
          acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
    };
  }
}
