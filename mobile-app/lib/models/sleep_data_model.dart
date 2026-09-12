import 'package:cloud_firestore/cloud_firestore.dart';

/// Sleep Stage Classification
enum SleepStage {
  awake('awake', 'Awake', 0),
  light('light', 'Light Sleep', 1),
  deep('deep', 'Deep Sleep', 2),
  rem('rem', 'REM Sleep', 3);

  final String id;
  final String displayName;
  final int depth; // 0=awake, 3=deepest

  const SleepStage(this.id, this.displayName, this.depth);

  static SleepStage fromId(String id) {
    return values.firstWhere((s) => s.id == id, orElse: () => awake);
  }
}

/// Raw sensor reading from device (mmWave sensor)
class SensorReading {
  final DateTime timestamp;
  final double respiratoryRate; // breaths per minute
  final double heartRate; // beats per minute (if available)
  final double movementIntensity; // 0.0 - 1.0
  final double presence; // 0.0 - 1.0 (baby in crib detection)

  SensorReading({
    required this.timestamp,
    required this.respiratoryRate,
    this.heartRate = 0,
    required this.movementIntensity,
    required this.presence,
  });

  factory SensorReading.fromFirestore(Map<String, dynamic> data) {
    return SensorReading(
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      respiratoryRate: (data['respiratoryRate'] ?? 0).toDouble(),
      heartRate: (data['heartRate'] ?? 0).toDouble(),
      movementIntensity: (data['movementIntensity'] ?? 0).toDouble(),
      presence: (data['presence'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'respiratoryRate': respiratoryRate,
      'heartRate': heartRate,
      'movementIntensity': movementIntensity,
      'presence': presence,
    };
  }
}

/// Sleep stage segment (e.g., "Light sleep from 8:00 PM to 9:15 PM")
class SleepStageSegment {
  final SleepStage stage;
  final DateTime startTime;
  final DateTime endTime;
  final double avgRespiratoryRate;
  final double avgHeartRate;
  final double avgMovement;

  SleepStageSegment({
    required this.stage,
    required this.startTime,
    required this.endTime,
    required this.avgRespiratoryRate,
    required this.avgHeartRate,
    required this.avgMovement,
  });

  Duration get duration => endTime.difference(startTime);

  factory SleepStageSegment.fromFirestore(Map<String, dynamic> data) {
    return SleepStageSegment(
      stage: SleepStage.fromId(data['stage'] ?? 'awake'),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      avgRespiratoryRate: (data['avgRespiratoryRate'] ?? 0).toDouble(),
      avgHeartRate: (data['avgHeartRate'] ?? 0).toDouble(),
      avgMovement: (data['avgMovement'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stage': stage.id,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'avgRespiratoryRate': avgRespiratoryRate,
      'avgHeartRate': avgHeartRate,
      'avgMovement': avgMovement,
    };
  }
}

/// Complete sleep session with analysis
class SleepSession {
  final String id;
  final String babyId;
  final String userId;
  final String? deviceId; // null for manual tracking

  // Session timing
  final DateTime startTime;
  final DateTime? endTime; // null if session is ongoing
  final bool isAutoDetected; // true if detected by device, false if manual

  // Sleep stages (only for device-tracked sleep)
  final List<SleepStageSegment> stages;

  // Sleep quality metrics (calculated from analysis)
  final double? qualityScore; // 0-100
  final int? awakenings; // Number of wake-ups
  final Duration? timeToSleep; // How long to fall asleep
  final double? sleepEfficiency; // % of time in bed actually sleeping

  // Sleep stage durations
  final Duration? lightSleepDuration;
  final Duration? deepSleepDuration;
  final Duration? remSleepDuration;

  // Analysis status
  final bool isAnalyzed;
  final DateTime? analyzedAt;

  SleepSession({
    required this.id,
    required this.babyId,
    required this.userId,
    this.deviceId,
    required this.startTime,
    this.endTime,
    required this.isAutoDetected,
    List<SleepStageSegment>? stages,
    this.qualityScore,
    this.awakenings,
    this.timeToSleep,
    this.sleepEfficiency,
    this.lightSleepDuration,
    this.deepSleepDuration,
    this.remSleepDuration,
    this.isAnalyzed = false,
    this.analyzedAt,
  }) : stages = stages ?? [];

  /// Total sleep duration
  Duration get totalDuration {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }

  /// Is session currently active
  bool get isActive => endTime == null;

  /// Has device data (vs manual entry)
  bool get hasDeviceData => deviceId != null && stages.isNotEmpty;

  factory SleepSession.fromMap(Map<String, dynamic> data) {
    return SleepSession(
      id: data['id'] ?? '',
      babyId: data['babyId'] ?? '',
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'],
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      isAutoDetected: data['isAutoDetected'] ?? false,
      stages: (data['stages'] as List<dynamic>?)
              ?.map((s) => SleepStageSegment.fromFirestore(s as Map<String, dynamic>))
              .toList() ??
          [],
      qualityScore: (data['qualityScore'] as num?)?.toDouble(),
      awakenings: data['awakenings'],
      timeToSleep: data['timeToSleep'] != null
          ? Duration(seconds: data['timeToSleep'])
          : null,
      sleepEfficiency: (data['sleepEfficiency'] as num?)?.toDouble(),
      lightSleepDuration: data['lightSleepDuration'] != null
          ? Duration(seconds: data['lightSleepDuration'])
          : null,
      deepSleepDuration: data['deepSleepDuration'] != null
          ? Duration(seconds: data['deepSleepDuration'])
          : null,
      remSleepDuration: data['remSleepDuration'] != null
          ? Duration(seconds: data['remSleepDuration'])
          : null,
      isAnalyzed: data['isAnalyzed'] ?? false,
      analyzedAt: data['analyzedAt'] != null
          ? (data['analyzedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory SleepSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SleepSession(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null 
          ? (data['endTime'] as Timestamp).toDate() 
          : null,
      isAutoDetected: data['isAutoDetected'] ?? false,
      stages: (data['stages'] as List<dynamic>?)
          ?.map((s) => SleepStageSegment.fromFirestore(s as Map<String, dynamic>))
          .toList() ?? [],
      qualityScore: data['qualityScore']?.toDouble(),
      awakenings: data['awakenings'],
      timeToSleep: data['timeToSleep'] != null 
          ? Duration(seconds: data['timeToSleep']) 
          : null,
      sleepEfficiency: data['sleepEfficiency']?.toDouble(),
      lightSleepDuration: data['lightSleepDuration'] != null
          ? Duration(seconds: data['lightSleepDuration'])
          : null,
      deepSleepDuration: data['deepSleepDuration'] != null
          ? Duration(seconds: data['deepSleepDuration'])
          : null,
      remSleepDuration: data['remSleepDuration'] != null
          ? Duration(seconds: data['remSleepDuration'])
          : null,
      isAnalyzed: data['isAnalyzed'] ?? false,
      analyzedAt: data['analyzedAt'] != null
          ? (data['analyzedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'userId': userId,
      'deviceId': deviceId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isAutoDetected': isAutoDetected,
      'stages': stages.map((s) => s.toFirestore()).toList(),
      'qualityScore': qualityScore,
      'awakenings': awakenings,
      'timeToSleep': timeToSleep?.inSeconds,
      'sleepEfficiency': sleepEfficiency,
      'lightSleepDuration': lightSleepDuration?.inSeconds,
      'deepSleepDuration': deepSleepDuration?.inSeconds,
      'remSleepDuration': remSleepDuration?.inSeconds,
      'isAnalyzed': isAnalyzed,
      'analyzedAt': analyzedAt != null ? Timestamp.fromDate(analyzedAt!) : null,
    };
  }

  /// Get sleep quality rating
  String getQualityRating() {
    if (qualityScore == null) return 'Unknown';
    if (qualityScore! >= 80) return 'Excellent';
    if (qualityScore! >= 65) return 'Good';
    if (qualityScore! >= 50) return 'Fair';
    return 'Poor';
  }

  /// Get quality color for UI
  String getQualityColor() {
    if (qualityScore == null) return '#9E9E9E';
    if (qualityScore! >= 80) return '#4CAF50'; // Green
    if (qualityScore! >= 65) return '#8BC34A'; // Light green
    if (qualityScore! >= 50) return '#FFC107'; // Amber
    return '#F44336'; // Red
  }
}

/// Sleep statistics for a period (day, week, month)
class SleepStatistics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalSessions;
  final Duration totalSleepTime;
  final Duration avgSleepDuration;
  final double avgQualityScore;
  final int totalAwakenings;
  final Duration avgTimeToSleep;
  
  // Sleep stage percentages
  final double lightSleepPercentage;
  final double deepSleepPercentage;
  final double remSleepPercentage;

  SleepStatistics({
    required this.startDate,
    required this.endDate,
    required this.totalSessions,
    required this.totalSleepTime,
    required this.avgSleepDuration,
    required this.avgQualityScore,
    required this.totalAwakenings,
    required this.avgTimeToSleep,
    required this.lightSleepPercentage,
    required this.deepSleepPercentage,
    required this.remSleepPercentage,
  });
}
