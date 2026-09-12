import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/colic_pattern_model.dart';

void main() {
  group('ColicRiskLevel', () {
    test('fromString parses valid values', () {
      expect(ColicRiskLevel.fromString('none'), ColicRiskLevel.none);
      expect(ColicRiskLevel.fromString('mild'), ColicRiskLevel.mild);
      expect(ColicRiskLevel.fromString('moderate'), ColicRiskLevel.moderate);
      expect(ColicRiskLevel.fromString('severe'), ColicRiskLevel.severe);
    });

    test('fromString returns none for null/invalid', () {
      expect(ColicRiskLevel.fromString(null), ColicRiskLevel.none);
      expect(ColicRiskLevel.fromString('invalid'), ColicRiskLevel.none);
    });

    test('label returns human-readable text', () {
      expect(ColicRiskLevel.none.label, 'None');
      expect(ColicRiskLevel.mild.label, 'Mild');
      expect(ColicRiskLevel.moderate.label, 'Moderate');
      expect(ColicRiskLevel.severe.label, 'Severe');
    });
  });

  group('ColicDayAnalysis', () {
    test('fromMap creates valid instance', () {
      final data = {
        'date': '2026-02-15',
        'totalCryingMinutes': 200,
        'colicCryingMinutes': 120,
        'totalEpisodes': 8,
        'colicEpisodes': 3,
        'longestEpisodeMinutes': 45,
        'peakHour': 19,
        'avgIntensity': 0.65,
        'meetsThreshold': true,
      };

      final analysis = ColicDayAnalysis.fromMap(data);

      expect(analysis.date, '2026-02-15');
      expect(analysis.totalCryingMinutes, 200);
      expect(analysis.colicCryingMinutes, 120);
      expect(analysis.totalEpisodes, 8);
      expect(analysis.colicEpisodes, 3);
      expect(analysis.longestEpisodeMinutes, 45);
      expect(analysis.peakHour, 19);
      expect(analysis.avgIntensity, closeTo(0.65, 0.01));
      expect(analysis.meetsThreshold, true);
    });

    test('fromMap handles missing fields with defaults', () {
      final analysis = ColicDayAnalysis.fromMap({});

      expect(analysis.date, '');
      expect(analysis.totalCryingMinutes, 0);
      expect(analysis.meetsThreshold, false);
      expect(analysis.peakHour, -1);
    });
  });

  group('ColicWeekSummary', () {
    test('fromMap creates valid instance', () {
      final data = {
        'weekStart': '2026-02-10',
        'daysOverThreshold': 4,
        'totalCryingMinutes': 960,
        'avgDailyCryingMinutes': 137,
        'meetsWessel': true,
      };

      final summary = ColicWeekSummary.fromMap(data);

      expect(summary.weekStart, '2026-02-10');
      expect(summary.daysOverThreshold, 4);
      expect(summary.totalCryingMinutes, 960);
      expect(summary.avgDailyCryingMinutes, 137);
      expect(summary.meetsWessel, true);
    });

    test('fromMap handles missing fields', () {
      final summary = ColicWeekSummary.fromMap({});

      expect(summary.weekStart, '');
      expect(summary.daysOverThreshold, 0);
      expect(summary.meetsWessel, false);
    });
  });

  group('ColicPatternResult', () {
    test('fromMap creates full result', () {
      final data = {
        'babyId': 'baby-1',
        'analysisDate': '2026-02-19',
        'dailyAnalysis': [
          {
            'date': '2026-02-18',
            'totalCryingMinutes': 200,
            'colicCryingMinutes': 100,
            'totalEpisodes': 5,
            'colicEpisodes': 2,
            'longestEpisodeMinutes': 30,
            'peakHour': 20,
            'avgIntensity': 0.7,
            'meetsThreshold': true,
          },
        ],
        'weeklySummaries': [
          {
            'weekStart': '2026-02-17',
            'daysOverThreshold': 3,
            'totalCryingMinutes': 600,
            'avgDailyCryingMinutes': 85,
            'meetsWessel': true,
          },
        ],
        'currentStreak': 2,
        'longestStreak': 5,
        'wesselWeeksCount': 1,
        'riskLevel': 'moderate',
        'riskScore': 45,
        'suggestions': [
          'Consider discussing with your pediatrician.',
        ],
      };

      final result = ColicPatternResult.fromMap(data);

      expect(result.babyId, 'baby-1');
      expect(result.analysisDate, '2026-02-19');
      expect(result.dailyAnalysis.length, 1);
      expect(result.dailyAnalysis[0].totalCryingMinutes, 200);
      expect(result.weeklySummaries.length, 1);
      expect(result.weeklySummaries[0].meetsWessel, true);
      expect(result.currentStreak, 2);
      expect(result.longestStreak, 5);
      expect(result.wesselWeeksCount, 1);
      expect(result.riskLevel, ColicRiskLevel.moderate);
      expect(result.riskScore, 45);
      expect(result.suggestions.length, 1);
    });

    test('fromMap handles empty data', () {
      final result = ColicPatternResult.fromMap({});

      expect(result.babyId, '');
      expect(result.dailyAnalysis, isEmpty);
      expect(result.weeklySummaries, isEmpty);
      expect(result.riskLevel, ColicRiskLevel.none);
      expect(result.riskScore, 0);
      expect(result.suggestions, isEmpty);
    });
  });
}
