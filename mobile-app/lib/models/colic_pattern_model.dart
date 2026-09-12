import 'package:cloud_firestore/cloud_firestore.dart';

/// Colic risk levels
enum ColicRiskLevel {
  none,
  mild,
  moderate,
  severe;

  String get label {
    switch (this) {
      case ColicRiskLevel.none:
        return 'None';
      case ColicRiskLevel.mild:
        return 'Mild';
      case ColicRiskLevel.moderate:
        return 'Moderate';
      case ColicRiskLevel.severe:
        return 'Severe';
    }
  }

  static ColicRiskLevel fromString(String? value) {
    if (value == null) return ColicRiskLevel.none;
    return ColicRiskLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ColicRiskLevel.none,
    );
  }
}

/// Single day analysis from colic pattern detection
class ColicDayAnalysis {
  final String date;
  final int totalCryingMinutes;
  final int colicCryingMinutes;
  final int totalEpisodes;
  final int colicEpisodes;
  final int longestEpisodeMinutes;
  final int peakHour;
  final double avgIntensity;
  final bool meetsThreshold;

  const ColicDayAnalysis({
    required this.date,
    required this.totalCryingMinutes,
    required this.colicCryingMinutes,
    required this.totalEpisodes,
    required this.colicEpisodes,
    required this.longestEpisodeMinutes,
    required this.peakHour,
    required this.avgIntensity,
    required this.meetsThreshold,
  });

  factory ColicDayAnalysis.fromMap(Map<String, dynamic> data) {
    return ColicDayAnalysis(
      date: data['date'] as String? ?? '',
      totalCryingMinutes: data['totalCryingMinutes'] as int? ?? 0,
      colicCryingMinutes: data['colicCryingMinutes'] as int? ?? 0,
      totalEpisodes: data['totalEpisodes'] as int? ?? 0,
      colicEpisodes: data['colicEpisodes'] as int? ?? 0,
      longestEpisodeMinutes: data['longestEpisodeMinutes'] as int? ?? 0,
      peakHour: data['peakHour'] as int? ?? -1,
      avgIntensity: (data['avgIntensity'] as num?)?.toDouble() ?? 0,
      meetsThreshold: data['meetsThreshold'] as bool? ?? false,
    );
  }
}

/// Weekly colic summary
class ColicWeekSummary {
  final String weekStart;
  final int daysOverThreshold;
  final int totalCryingMinutes;
  final int avgDailyCryingMinutes;
  final bool meetsWessel;

  const ColicWeekSummary({
    required this.weekStart,
    required this.daysOverThreshold,
    required this.totalCryingMinutes,
    required this.avgDailyCryingMinutes,
    required this.meetsWessel,
  });

  factory ColicWeekSummary.fromMap(Map<String, dynamic> data) {
    return ColicWeekSummary(
      weekStart: data['weekStart'] as String? ?? '',
      daysOverThreshold: data['daysOverThreshold'] as int? ?? 0,
      totalCryingMinutes: data['totalCryingMinutes'] as int? ?? 0,
      avgDailyCryingMinutes: data['avgDailyCryingMinutes'] as int? ?? 0,
      meetsWessel: data['meetsWessel'] as bool? ?? false,
    );
  }
}

/// Full colic pattern analysis result
///
/// Stored in: babies/{babyId}/colicPatterns/{date}
class ColicPatternResult {
  final String babyId;
  final String analysisDate;
  final List<ColicDayAnalysis> dailyAnalysis;
  final List<ColicWeekSummary> weeklySummaries;
  final int currentStreak;
  final int longestStreak;
  final int wesselWeeksCount;
  final ColicRiskLevel riskLevel;
  final int riskScore;
  final List<String> suggestions;
  final DateTime? analyzedAt;

  const ColicPatternResult({
    required this.babyId,
    required this.analysisDate,
    required this.dailyAnalysis,
    required this.weeklySummaries,
    required this.currentStreak,
    required this.longestStreak,
    required this.wesselWeeksCount,
    required this.riskLevel,
    required this.riskScore,
    required this.suggestions,
    this.analyzedAt,
  });

  factory ColicPatternResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ColicPatternResult.fromMap(data);
  }

  factory ColicPatternResult.fromMap(Map<String, dynamic> data) {
    return ColicPatternResult(
      babyId: data['babyId'] as String? ?? '',
      analysisDate: data['analysisDate'] as String? ?? '',
      dailyAnalysis: (data['dailyAnalysis'] as List<dynamic>?)
              ?.map((d) =>
                  ColicDayAnalysis.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      weeklySummaries: (data['weeklySummaries'] as List<dynamic>?)
              ?.map((d) =>
                  ColicWeekSummary.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      wesselWeeksCount: data['wesselWeeksCount'] as int? ?? 0,
      riskLevel: ColicRiskLevel.fromString(data['riskLevel'] as String?),
      riskScore: data['riskScore'] as int? ?? 0,
      suggestions: (data['suggestions'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
      analyzedAt: (data['analyzedAt'] as Timestamp?)?.toDate(),
    );
  }
}
