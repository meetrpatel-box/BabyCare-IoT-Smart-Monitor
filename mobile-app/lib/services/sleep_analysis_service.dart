import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sleep_data_model.dart';

/// Sleep Analysis Service
/// Fetches device data and runs sleep analysis algorithms
class SleepAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch active sleep session for baby
  Future<SleepSession?> getActiveSleepSession(String babyId) async {
    final snapshot = await _firestore
        .collection('sleep_sessions')
        .where('babyId', isEqualTo: babyId)
        .where('endTime', isEqualTo: null)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SleepSession.fromFirestore(snapshot.docs.first);
  }

  /// Stream active sleep session (real-time updates from device)
  Stream<SleepSession?> streamActiveSleepSession(String babyId) {
    return _firestore
        .collection('sleep_sessions')
        .where('babyId', isEqualTo: babyId)
        .where('endTime', isEqualTo: null)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SleepSession.fromFirestore(snapshot.docs.first);
    });
  }

  /// Fetch sleep sessions for date range
  Future<List<SleepSession>> getSleepSessions(
    String babyId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  }) async {
    Query query = _firestore
        .collection('sleep_sessions')
        .where('babyId', isEqualTo: babyId);

    if (startDate != null) {
      query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('startTime', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SleepSession.fromFirestore(doc)).toList();
  }

  /// Fetch sensor readings for a sleep session
  Stream<List<SensorReading>> streamSensorReadings(String sessionId) {
    return _firestore
        .collection('sleep_sessions')
        .doc(sessionId)
        .collection('sensor_readings')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SensorReading.fromFirestore(doc.data()))
            .toList());
  }

  /// Get latest sensor reading
  Future<SensorReading?> getLatestReading(String sessionId) async {
    final snapshot = await _firestore
        .collection('sleep_sessions')
        .doc(sessionId)
        .collection('sensor_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SensorReading.fromFirestore(snapshot.docs.first.data());
  }

  /// Analyze sleep session and calculate quality metrics
  Future<SleepSession> analyzeSleepSession(String sessionId) async {
    final sessionDoc = await _firestore
        .collection('sleep_sessions')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) {
      throw Exception('Sleep session not found');
    }

    final session = SleepSession.fromFirestore(sessionDoc);

    // If already analyzed, return as-is
    if (session.isAnalyzed) return session;

    // Fetch all sensor readings
    final readingsSnapshot = await _firestore
        .collection('sleep_sessions')
        .doc(sessionId)
        .collection('sensor_readings')
        .orderBy('timestamp')
        .get();

    final readings = readingsSnapshot.docs
        .map((doc) => SensorReading.fromFirestore(doc.data()))
        .toList();

    if (readings.isEmpty) {
      // No device data, can't analyze
      return session;
    }

    // Run analysis algorithms
    final stages = _detectSleepStages(readings);
    final qualityScore = _calculateQualityScore(stages);
    final awakenings = _countAwakenings(stages);
    final timeToSleep = _calculateTimeToSleep(stages);
    final sleepEfficiency = _calculateSleepEfficiency(session, stages);

    // Calculate stage durations
    final lightDuration = _calculateStageDuration(stages, SleepStage.light);
    final deepDuration = _calculateStageDuration(stages, SleepStage.deep);
    final remDuration = _calculateStageDuration(stages, SleepStage.rem);

    // Update session in Firestore
    await _firestore.collection('sleep_sessions').doc(sessionId).update({
      'stages': stages.map((s) => s.toFirestore()).toList(),
      'qualityScore': qualityScore,
      'awakenings': awakenings,
      'timeToSleep': timeToSleep.inSeconds,
      'sleepEfficiency': sleepEfficiency,
      'lightSleepDuration': lightDuration.inSeconds,
      'deepSleepDuration': deepDuration.inSeconds,
      'remSleepDuration': remDuration.inSeconds,
      'isAnalyzed': true,
      'analyzedAt': FieldValue.serverTimestamp(),
    });

    // Return updated session
    return SleepSession(
      id: session.id,
      babyId: session.babyId,
      userId: session.userId,
      deviceId: session.deviceId,
      startTime: session.startTime,
      endTime: session.endTime,
      isAutoDetected: session.isAutoDetected,
      stages: stages,
      qualityScore: qualityScore,
      awakenings: awakenings,
      timeToSleep: timeToSleep,
      sleepEfficiency: sleepEfficiency,
      lightSleepDuration: lightDuration,
      deepSleepDuration: deepDuration,
      remSleepDuration: remDuration,
      isAnalyzed: true,
      analyzedAt: DateTime.now(),
    );
  }

  /// Calculate sleep statistics for a period
  Future<SleepStatistics> getStatistics(
    String babyId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sessions = await getSleepSessions(
      babyId,
      startDate: startDate,
      endDate: endDate,
      limit: 1000,
    );

    if (sessions.isEmpty) {
      return SleepStatistics(
        startDate: startDate,
        endDate: endDate,
        totalSessions: 0,
        totalSleepTime: Duration.zero,
        avgSleepDuration: Duration.zero,
        avgQualityScore: 0,
        totalAwakenings: 0,
        avgTimeToSleep: Duration.zero,
        lightSleepPercentage: 0,
        deepSleepPercentage: 0,
        remSleepPercentage: 0,
      );
    }

    final totalSleepTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.totalDuration,
    );

    final avgSleepDuration = Duration(
      milliseconds: totalSleepTime.inMilliseconds ~/ sessions.length,
    );

    final avgQualityScore = sessions
            .where((s) => s.qualityScore != null)
            .fold<double>(0, (sum, s) => sum + s.qualityScore!) /
        sessions.where((s) => s.qualityScore != null).length;

    final totalAwakenings = sessions.fold<int>(
      0,
      (sum, session) => sum + (session.awakenings ?? 0),
    );

    final avgTimeToSleep = Duration(
      milliseconds: sessions
              .where((s) => s.timeToSleep != null)
              .fold<int>(0, (sum, s) => sum + s.timeToSleep!.inMilliseconds) ~/
          sessions.where((s) => s.timeToSleep != null).length,
    );

    // Calculate stage percentages
    final totalLight = sessions.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + (s.lightSleepDuration ?? Duration.zero),
    );
    final totalDeep = sessions.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + (s.deepSleepDuration ?? Duration.zero),
    );
    final totalRem = sessions.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + (s.remSleepDuration ?? Duration.zero),
    );

    final totalStageTime = totalLight.inMinutes + totalDeep.inMinutes + totalRem.inMinutes;

    return SleepStatistics(
      startDate: startDate,
      endDate: endDate,
      totalSessions: sessions.length,
      totalSleepTime: totalSleepTime,
      avgSleepDuration: avgSleepDuration,
      avgQualityScore: avgQualityScore,
      totalAwakenings: totalAwakenings,
      avgTimeToSleep: avgTimeToSleep,
      lightSleepPercentage: totalStageTime > 0 
          ? (totalLight.inMinutes / totalStageTime * 100) 
          : 0,
      deepSleepPercentage: totalStageTime > 0
          ? (totalDeep.inMinutes / totalStageTime * 100)
          : 0,
      remSleepPercentage: totalStageTime > 0
          ? (totalRem.inMinutes / totalStageTime * 100)
          : 0,
    );
  }

  /// ALGORITHM: Detect sleep stages from sensor readings
  List<SleepStageSegment> _detectSleepStages(List<SensorReading> readings) {
    if (readings.isEmpty) return [];

    final stages = <SleepStageSegment>[];
    SleepStage currentStage = SleepStage.awake;
    DateTime segmentStart = readings.first.timestamp;
    
    double totalRespRate = 0;
    double totalHeartRate = 0;
    double totalMovement = 0;
    int count = 0;

    for (int i = 0; i < readings.length; i++) {
      final reading = readings[i];
      
      // Accumulate metrics
      totalRespRate += reading.respiratoryRate;
      totalHeartRate += reading.heartRate;
      totalMovement += reading.movementIntensity;
      count++;

      // Classify sleep stage based on movement and vitals
      final stage = _classifySleepStage(reading);

      // Check if stage changed or if it's the last reading
      if (stage != currentStage || i == readings.length - 1) {
        // Create segment for previous stage
        if (count > 0) {
          stages.add(SleepStageSegment(
            stage: currentStage,
            startTime: segmentStart,
            endTime: reading.timestamp,
            avgRespiratoryRate: totalRespRate / count,
            avgHeartRate: totalHeartRate / count,
            avgMovement: totalMovement / count,
          ));
        }

        // Start new segment
        currentStage = stage;
        segmentStart = reading.timestamp;
        totalRespRate = 0;
        totalHeartRate = 0;
        totalMovement = 0;
        count = 0;
      }
    }

    return stages;
  }

  /// Classify sleep stage from sensor reading
  SleepStage _classifySleepStage(SensorReading reading) {
    // Algorithm based on movement and respiratory patterns
    
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

  /// Calculate sleep quality score (0-100)
  double _calculateQualityScore(List<SleepStageSegment> stages) {
    if (stages.isEmpty) return 0;

    double score = 100;

    // Calculate total sleep time
    final totalTime = stages.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );

    // Penalty for low sleep time (less than 12 hours for infant)
    if (totalTime.inHours < 12) {
      score -= (12 - totalTime.inHours) * 3;
    }

    // Count awakenings
    final awakenings = stages.where((s) => s.stage == SleepStage.awake).length;
    score -= awakenings * 2;

    // Check for healthy sleep stage distribution
    final deepSleepTime = stages
        .where((s) => s.stage == SleepStage.deep)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
    
    final deepPercentage = (deepSleepTime.inMinutes / totalTime.inMinutes) * 100;
    
    // Ideal deep sleep: 20-25% for infants
    if (deepPercentage < 15) {
      score -= (15 - deepPercentage) * 2;
    }

    return score.clamp(0, 100);
  }

  /// Count number of awakenings
  int _countAwakenings(List<SleepStageSegment> stages) {
    return stages.where((s) => 
      s.stage == SleepStage.awake && 
      s.duration.inMinutes > 1 // Only count if awake for >1 minute
    ).length;
  }

  /// Calculate time to fall asleep (sleep latency)
  Duration _calculateTimeToSleep(List<SleepStageSegment> stages) {
    if (stages.isEmpty) return Duration.zero;

    // Find first non-awake stage
    final firstSleep = stages.firstWhere(
      (s) => s.stage != SleepStage.awake,
      orElse: () => stages.first,
    );

    return firstSleep.startTime.difference(stages.first.startTime);
  }

  /// Calculate sleep efficiency (% of time in bed actually sleeping)
  double _calculateSleepEfficiency(
    SleepSession session,
    List<SleepStageSegment> stages,
  ) {
    if (stages.isEmpty) return 0;

    final totalTime = session.totalDuration;
    final sleepTime = stages
        .where((s) => s.stage != SleepStage.awake)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);

    return (sleepTime.inMinutes / totalTime.inMinutes * 100).clamp(0, 100);
  }

  /// Calculate total duration for a specific sleep stage
  Duration _calculateStageDuration(
    List<SleepStageSegment> stages,
    SleepStage stage,
  ) {
    return stages
        .where((s) => s.stage == stage)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
  }
}
