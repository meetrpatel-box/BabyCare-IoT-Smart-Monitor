import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stress_indicator_model.dart';
import '../models/sleep_data_model.dart';

/// Service for analyzing stress indicators from sleep patterns
/// Calculates stress levels based on wake frequency, quality drops, restlessness, etc.
class StressAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate stress from sleep patterns over a date range
  /// Algorithm:
  /// - High wake frequency (>4/night) → +30 points
  /// - Quality drops (>20 pts day-to-day) → +25 points
  /// - High restlessness (awake >15%) → +20 points
  /// - Inconsistent sleep times (>2hr variance) → +15 points
  /// - Short deep sleep (<15% total) → +10 points
  Future<StressIndicator> calculateStressFromSleep(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Fetch sleep sessions for the period
      final sessions = await _getSleepSessions(babyId, startDate, endDate);

      if (sessions.isEmpty) {
        // No data - return zero stress
        return _createZeroStressIndicator(babyId);
      }

      // Analyze sleep patterns
      final factors = analyzeStressFactors(sessions);

      // Calculate overall stress (0-100)
      final calculatedStress = factors.values.fold(0.0, (sum, value) => sum + value);
      final clampedStress = calculatedStress.clamp(0.0, 100.0);

      // Create stress indicator
      return StressIndicator(
        id: '${babyId}_${DateTime.now().millisecondsSinceEpoch}',
        babyId: babyId,
        timestamp: DateTime.now(),
        calculatedStressLevel: clampedStress,
        calculatedFactors: factors,
        overallStressLevel: clampedStress, // No measured data yet
        stressLevelCategory: _getStressLevelFromScore(clampedStress),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    } catch (e) {
      print('[StressAnalysisService] Error calculating stress: $e');
      return _createZeroStressIndicator(babyId);
    }
  }

  /// Analyze specific stress factors from sleep sessions
  Map<String, double> analyzeStressFactors(List<SleepSession> sessions) {
    final factors = <String, double>{};

    if (sessions.isEmpty) return factors;

    // Factor 1: High wake frequency (+30 if avg >4 per night)
    final avgWakeCount = _calculateAvgWakeCount(sessions);
    if (avgWakeCount > 4) {
      factors['wakeFrequency'] = 30.0;
    } else if (avgWakeCount > 3) {
      factors['wakeFrequency'] = 20.0;
    } else if (avgWakeCount > 2) {
      factors['wakeFrequency'] = 10.0;
    }

    // Factor 2: Quality drops (+25 if >20 point drop day-to-day)
    final qualityDrops = _detectQualityDrops(sessions);
    if (qualityDrops > 20) {
      factors['qualityDrops'] = 25.0;
    } else if (qualityDrops > 10) {
      factors['qualityDrops'] = 15.0;
    }

    // Factor 3: High restlessness (+20 if awake time >15%)
    final avgAwakePercent = _calculateAvgAwakePercent(sessions);
    if (avgAwakePercent > 15) {
      factors['restlessness'] = 20.0;
    } else if (avgAwakePercent > 10) {
      factors['restlessness'] = 10.0;
    }

    // Factor 4: Inconsistent sleep times (+15 if > 2hr variance)
    final timeVariance = _calculateSleepTimeVariance(sessions);
    if (timeVariance > 2.0) {
      factors['inconsistentTimes'] = 15.0;
    } else if (timeVariance > 1.0) {
      factors['inconsistentTimes'] = 8.0;
    }

    // Factor 5: Short deep sleep (+10 if <15% of total)
    final avgDeepSleepPercent = _calculateAvgDeepSleepPercent(sessions);
    if (avgDeepSleepPercent < 15) {
      factors['shortDeepSleep'] = 10.0;
    } else if (avgDeepSleepPercent < 20) {
      factors['shortDeepSleep'] = 5.0;
    }

    return factors;
  }

  /// Get stress trend over last N days
  Future<List<StressIndicator>> getStressTrend(String babyId, int days) async {
    final trend = <StressIndicator>[];

    for (int i = days - 1; i >= 0; i--) {
      final endDate = DateTime.now().subtract(Duration(days: i));
      final startDate = endDate.subtract(const Duration(days: 1));

      final indicator = await calculateStressFromSleep(babyId, startDate, endDate);
      trend.add(indicator);
    }

    return trend;
  }

  // ============== PRIVATE HELPERS ==============

  /// Fetch sleep sessions for date range
  Future<List<SleepSession>> _getSleepSessions(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('sleepSessions')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('isAnalyzed', isEqualTo: true)
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SleepSession.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('[StressAnalysisService] Error fetching sleep sessions: $e');
      return [];
    }
  }

  /// Calculate average wake count across sessions
  double _calculateAvgWakeCount(List<SleepSession> sessions) {
    if (sessions.isEmpty) return 0.0;

    final totalWakes = sessions.fold<int>(
      0,
      (sum, session) => sum + (session.awakenings ?? 0),
    );

    return totalWakes / sessions.length;
  }

  /// Detect quality drops between consecutive sessions
  double _detectQualityDrops(List<SleepSession> sessions) {
    if (sessions.length < 2) return 0.0;

    double maxDrop = 0.0;

    for (int i = 0; i < sessions.length - 1; i++) {
      final current = sessions[i].qualityScore ?? 0;
      final previous = sessions[i + 1].qualityScore ?? 0;
      final drop = previous - current;

      if (drop > maxDrop) {
        maxDrop = drop;
      }
    }

    return maxDrop;
  }

  /// Calculate average awake percentage
  double _calculateAvgAwakePercent(List<SleepSession> sessions) {
    if (sessions.isEmpty) return 0.0;

    double totalAwakePercent = 0.0;
    int validSessions = 0;

    for (var session in sessions) {
      // Find awake stage
      final awakeStage = session.stages.where(
        (stage) => stage.stage == SleepStage.awake,
      ).firstOrNull;

      if (awakeStage != null && awakeStage.duration.inMinutes > 0) {
        final totalMinutes = session.stages.fold<int>(
          0,
          (sum, stage) => sum + stage.duration.inMinutes,
        );

        if (totalMinutes > 0) {
          totalAwakePercent += (awakeStage.duration.inMinutes / totalMinutes) * 100;
          validSessions++;
        }
      }
    }

    return validSessions > 0 ? totalAwakePercent / validSessions : 0.0;
  }

  /// Calculate sleep time variance (in hours)
  double _calculateSleepTimeVariance(List<SleepSession> sessions) {
    if (sessions.length < 2) return 0.0;

    // Get start hours for each session
    final startHours = sessions
        .map((s) => s.startTime.hour + (s.startTime.minute / 60.0))
        .toList();

    // Calculate variance
    final mean = startHours.reduce((a, b) => a + b) / startHours.length;
    final variance = startHours
            .map((h) => (h - mean).abs())
            .reduce((a, b) => a + b) /
        startHours.length;

    return variance;
  }

  /// Calculate average deep sleep percentage
  double _calculateAvgDeepSleepPercent(List<SleepSession> sessions) {
    if (sessions.isEmpty) return 0.0;

    double totalDeepPercent = 0.0;
    int validSessions = 0;

    for (var session in sessions) {
      // Find deep stage
      final deepStage = session.stages.where(
        (stage) => stage.stage == SleepStage.deep,
      ).firstOrNull;

      if (deepStage != null && deepStage.duration.inMinutes > 0) {
        final totalMinutes = session.stages.fold<int>(
          0,
          (sum, stage) => sum + stage.duration.inMinutes,
        );

        if (totalMinutes > 0) {
          totalDeepPercent += (deepStage.duration.inMinutes / totalMinutes) * 100;
          validSessions++;
        }
      }
    }

    return validSessions > 0 ? totalDeepPercent / validSessions : 0.0;
  }

  /// Create zero-stress indicator (no data)
  StressIndicator _createZeroStressIndicator(String babyId) {
    return StressIndicator(
      id: '${babyId}_${DateTime.now().millisecondsSinceEpoch}',
      babyId: babyId,
      timestamp: DateTime.now(),
      calculatedStressLevel: 0.0,
      calculatedFactors: {},
      overallStressLevel: 0.0,
      stressLevelCategory: StressLevel.low,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Determine stress level category from score
  StressLevel _getStressLevelFromScore(double score) {
    if (score <= 30) return StressLevel.low;
    if (score <= 60) return StressLevel.moderate;
    if (score <= 85) return StressLevel.high;
    return StressLevel.critical;
  }
}
