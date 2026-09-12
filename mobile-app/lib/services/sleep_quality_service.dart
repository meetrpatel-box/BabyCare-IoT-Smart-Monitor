import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sleep_model.dart';

/// Sleep Quality Scoring Service
/// Calculates sleep quality scores based on multiple factors
class SleepQualityService {
  final FirebaseFirestore? _firestore;

  SleepQualityService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Calculate sleep quality score (0-100)
  /// Based on:
  /// - Duration (optimal: 11-14 hours for infants)
  /// - Wake count (fewer is better)
  /// - Deep sleep percentage (higher is better)
  /// - Consistency (regularity of sleep pattern)
  SleepQualityScore calculateQualityScore(SleepSession session,
      {int? babyAgeInMonths}) {
    int scoreTotal = 0;
    final Map<String, int> breakdown = {};

    // 1. Duration Score (40 points max)
    final durationScore = _calculateDurationScore(
      session.totalMinutes ?? session.duration.inMinutes,
      babyAgeInMonths ?? 6, // Default to 6 months
    );
    scoreTotal += durationScore;
    breakdown['duration'] = durationScore;

    // 2. Wake Count Score (25 points max)
    final wakeScore = _calculateWakeScore(session.wakeCount ?? 0);
    scoreTotal += wakeScore;
    breakdown['wakes'] = wakeScore;

    // 3. Sleep Stage Quality (25 points max)
    final stageScore = _calculateStageScore(session.stagePercentages);
    scoreTotal += stageScore;
    breakdown['stages'] = stageScore;

    // 4. Continuity Score (10 points max)
    final continuityScore = _calculateContinuityScore(session.stages);
    scoreTotal += continuityScore;
    breakdown['continuity'] = continuityScore;

    // Determine quality rating
    final quality = _getQualityRating(scoreTotal);

    return SleepQualityScore(
      score: scoreTotal,
      quality: quality,
      breakdown: breakdown,
      recommendations: _getRecommendations(scoreTotal, breakdown),
    );
  }

  /// Calculate duration score based on age-appropriate ranges
  int _calculateDurationScore(int totalMinutes, int ageInMonths) {
    final hours = totalMinutes / 60;

    // Age-based optimal ranges (hours)
    double optimalMin, optimalMax;
    if (ageInMonths < 4) {
      optimalMin = 14.0;
      optimalMax = 17.0;
    } else if (ageInMonths < 12) {
      optimalMin = 12.0;
      optimalMax = 15.0;
    } else if (ageInMonths < 24) {
      optimalMin = 11.0;
      optimalMax = 14.0;
    } else {
      optimalMin = 10.0;
      optimalMax = 13.0;
    }

    // Perfect score if within optimal range
    if (hours >= optimalMin && hours <= optimalMax) {
      return 40;
    }

    // Calculate deviation penalty
    double deviation;
    if (hours < optimalMin) {
      deviation = optimalMin - hours;
    } else {
      deviation = hours - optimalMax;
    }

    // Deduct 5 points per hour deviation, minimum 0
    final score = (40 - (deviation * 5)).clamp(0, 40).toInt();
    return score;
  }

  /// Calculate wake score (fewer wakes = higher score)
  int _calculateWakeScore(int wakeCount) {
    if (wakeCount == 0) return 25;
    if (wakeCount == 1) return 20;
    if (wakeCount == 2) return 15;
    if (wakeCount == 3) return 10;
    if (wakeCount == 4) return 5;
    return 0; // 5+ wakes
  }

  /// Calculate sleep stage quality score
  int _calculateStageScore(Map<SleepStageType, double> stagePercentages) {
    if (stagePercentages.isEmpty) return 0;

    int score = 0;

    // Deep sleep: optimal 20-25%
    final deepPercent = stagePercentages[SleepStageType.deep] ?? 0;
    if (deepPercent >= 20 && deepPercent <= 25) {
      score += 10;
    } else if (deepPercent >= 15 && deepPercent <= 30) {
      score += 7;
    } else if (deepPercent >= 10 && deepPercent <= 35) {
      score += 4;
    }

    // REM sleep: optimal 20-25%
    final remPercent = stagePercentages[SleepStageType.rem] ?? 0;
    if (remPercent >= 20 && remPercent <= 25) {
      score += 10;
    } else if (remPercent >= 15 && remPercent <= 30) {
      score += 7;
    } else if (remPercent >= 10 && remPercent <= 35) {
      score += 4;
    }

    // Awake time: should be minimal (<5%)
    final awakePercent = stagePercentages[SleepStageType.awake] ?? 0;
    if (awakePercent <= 2) {
      score += 5;
    } else if (awakePercent <= 5) {
      score += 3;
    } else if (awakePercent <= 10) {
      score += 1;
    }

    return score;
  }

  /// Calculate sleep continuity score
  int _calculateContinuityScore(List<SleepStage> stages) {
    if (stages.isEmpty) return 0;

    // Fewer stage transitions = better continuity
    final transitions = stages.length;

    if (transitions <= 3) return 10;
    if (transitions <= 5) return 8;
    if (transitions <= 8) return 6;
    if (transitions <= 12) return 4;
    if (transitions <= 15) return 2;
    return 0;
  }

  /// Get quality rating from score
  SleepQuality _getQualityRating(int score) {
    if (score >= 85) return SleepQuality.excellent;
    if (score >= 70) return SleepQuality.good;
    if (score >= 50) return SleepQuality.fair;
    return SleepQuality.poor;
  }

  /// Get personalized recommendations
  List<String> _getRecommendations(int totalScore, Map<String, int> breakdown) {
    final List<String> recommendations = [];

    if (breakdown['duration']! < 30) {
      recommendations.add(
          'Try to extend sleep duration with a consistent bedtime routine');
    }

    if (breakdown['wakes']! < 15) {
      recommendations.add(
          'Reduce nighttime wakes by ensuring baby is well-fed before bed');
    }

    if (breakdown['stages']! < 15) {
      recommendations.add(
          'Improve sleep environment: keep room dark, quiet, and cool (65-70°F)');
    }

    if (breakdown['continuity']! < 6) {
      recommendations
          .add('Too many sleep disturbances - check for environmental factors');
    }

    if (totalScore >= 85) {
      recommendations.add('Excellent sleep! Keep up the good routine 🌟');
    }

    return recommendations;
  }

  Future<List<SleepQualityTrend>> getSleepQualityTrends(
    String babyId,
    DateTime startDate,
    DateTime endDate, {
    int? babyAgeInMonths,
  }) async {
    final snapshot = await _db
        .collection('sleep_sessions')
        .where('babyId', isEqualTo: babyId)
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: false)
        .get();

    final List<SleepQualityTrend> trends = [];

    for (final doc in snapshot.docs) {
      final session = SleepSession.fromFirestore(doc);
      if (session.endTime != null) {
        // Only calculate for completed sessions
        final qualityScore =
            calculateQualityScore(session, babyAgeInMonths: babyAgeInMonths);
        trends.add(SleepQualityTrend(
          date: session.startTime,
          score: qualityScore.score,
          quality: qualityScore.quality,
        ));
      }
    }

    return trends;
  }

  /// Get average sleep score for last N days
  Future<double> getAverageSleepScore(String babyId, int days,
      {int? babyAgeInMonths}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final trends = await getSleepQualityTrends(
      babyId,
      startDate,
      endDate,
      babyAgeInMonths: babyAgeInMonths,
    );

    if (trends.isEmpty) return 0.0;

    final totalScore = trends.fold<int>(0, (sum, trend) => sum + trend.score);
    return totalScore / trends.length;
  }

  /// Analyze sleep patterns and identify issues
  Future<SleepAnalysis> analyzeSleepPatterns(
    String babyId,
    int days, {
    int? babyAgeInMonths,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final snapshot = await _db
        .collection('sleep_sessions')
        .where('babyId', isEqualTo: babyId)
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    if (snapshot.docs.isEmpty) {
      return SleepAnalysis(
        avgDuration: 0,
        avgWakes: 0,
        avgScore: 0,
        totalSessions: 0,
        issues: ['No sleep data available for this period'],
        strengths: [],
      );
    }

    final sessions = snapshot.docs
        .map((doc) => SleepSession.fromFirestore(doc))
        .where((s) => s.endTime != null)
        .toList();

    // Calculate averages
    final avgDuration = sessions.fold<int>(
            0, (sum, s) => sum + (s.totalMinutes ?? s.duration.inMinutes)) /
        sessions.length;

    final avgWakes =
        sessions.fold<int>(0, (sum, s) => sum + (s.wakeCount ?? 0)) /
            sessions.length;

    // Calculate average score
    final scores = sessions.map((s) =>
        calculateQualityScore(s, babyAgeInMonths: babyAgeInMonths).score);
    final avgScore = scores.reduce((a, b) => a + b) / sessions.length;

    // Identify issues and strengths
    final List<String> issues = [];
    final List<String> strengths = [];

    if (avgDuration < 600) {
      // Less than 10 hours
      issues.add('Sleep duration is below recommended range');
    } else if (avgDuration > 780) {
      // More than 13 hours
      strengths.add('Excellent sleep duration');
    }

    if (avgWakes > 3) {
      issues.add('Frequent nighttime waking - consider sleep training');
    } else if (avgWakes < 2) {
      strengths.add('Minimal nighttime disruptions');
    }

    if (avgScore >= 80) {
      strengths.add('Consistently high sleep quality');
    } else if (avgScore < 60) {
      issues.add('Sleep quality needs improvement');
    }

    return SleepAnalysis(
      avgDuration: avgDuration.round(),
      avgWakes: avgWakes.round(),
      avgScore: avgScore.round(),
      totalSessions: sessions.length,
      issues: issues,
      strengths: strengths,
    );
  }
}

/// Sleep quality score result
class SleepQualityScore {
  final int score; // 0-100
  final SleepQuality quality;
  final Map<String, int> breakdown;
  final List<String> recommendations;

  SleepQualityScore({
    required this.score,
    required this.quality,
    required this.breakdown,
    required this.recommendations,
  });
}

/// Sleep quality trend for charting
class SleepQualityTrend {
  final DateTime date;
  final int score;
  final SleepQuality quality;

  SleepQualityTrend({
    required this.date,
    required this.score,
    required this.quality,
  });
}

/// Sleep analysis summary
class SleepAnalysis {
  final int avgDuration; // minutes
  final int avgWakes;
  final int avgScore;
  final int totalSessions;
  final List<String> issues;
  final List<String> strengths;

  SleepAnalysis({
    required this.avgDuration,
    required this.avgWakes,
    required this.avgScore,
    required this.totalSessions,
    required this.issues,
    required this.strengths,
  });
}
