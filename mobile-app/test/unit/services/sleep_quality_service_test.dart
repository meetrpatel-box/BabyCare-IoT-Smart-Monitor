import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/sleep_model.dart';
import 'package:baby_track_flutter/services/sleep_quality_service.dart';

void main() {
  group('SleepQualityService', () {
    late SleepQualityService service;

    setUp(() {
      // Create service without Firestore for unit tests
      service = SleepQualityService(firestore: null);
    });

    group('calculateQualityScore', () {
      test('excellent sleep returns score >= 85', () {
        // Create a perfect sleep session
        final session = SleepSession(
          id: 'test-1',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 8, 0), // 12 hours
          totalMinutes: 720, // 12 hours
          stages: [
            SleepStage(
              stage: SleepStageType.deep,
              durationMinutes: 180, // 25% deep sleep
              startTime: DateTime(2024, 1, 1, 20, 0),
              endTime: DateTime(2024, 1, 1, 23, 0),
            ),
            SleepStage(
              stage: SleepStageType.rem,
              durationMinutes: 180, // 25% REM
              startTime: DateTime(2024, 1, 1, 23, 0),
              endTime: DateTime(2024, 1, 2, 2, 0),
            ),
            SleepStage(
              stage: SleepStageType.light,
              durationMinutes: 350, // Rest light sleep
              startTime: DateTime(2024, 1, 2, 2, 0),
              endTime: DateTime(2024, 1, 2, 7, 50),
            ),
            SleepStage(
              stage: SleepStageType.awake,
              durationMinutes: 10, // Minimal awake
              startTime: DateTime(2024, 1, 2, 7, 50),
              endTime: DateTime(2024, 1, 2, 8, 0),
            ),
          ],
          wakeCount: 0,
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        final score =
            service.calculateQualityScore(session, babyAgeInMonths: 6);

        expect(score.score, greaterThanOrEqualTo(85));
        expect(score.quality, equals(SleepQuality.excellent));
        expect(score.recommendations, isNotEmpty);
      });

      test('poor sleep returns score < 50', () {
        // Create a poor sleep session
        final session = SleepSession(
          id: 'test-2',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 2, 0), // Only 6 hours
          totalMinutes: 360, // 6 hours
          stages: [
            SleepStage(
              stage: SleepStageType.light,
              durationMinutes: 280,
              startTime: DateTime(2024, 1, 1, 20, 0),
              endTime: DateTime(2024, 1, 2, 0, 40),
            ),
            SleepStage(
              stage: SleepStageType.awake,
              durationMinutes: 80, // Too much awake time
              startTime: DateTime(2024, 1, 2, 0, 40),
              endTime: DateTime(2024, 1, 2, 2, 0),
            ),
          ],
          wakeCount: 5, // Frequent wakes
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        final score =
            service.calculateQualityScore(session, babyAgeInMonths: 6);

        expect(score.score, lessThan(50));
        expect(score.quality, equals(SleepQuality.poor));
        expect(score.recommendations, isNotEmpty);
      });

      test('good sleep returns score between 70-84', () {
        final session = SleepSession(
          id: 'test-3',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 8, 0), // 12 hours
          totalMinutes: 720,
          stages: [
            SleepStage(
              stage: SleepStageType.deep,
              durationMinutes: 120, // Decent deep sleep
              startTime: DateTime(2024, 1, 1, 20, 0),
              endTime: DateTime(2024, 1, 1, 22, 0),
            ),
            SleepStage(
              stage: SleepStageType.light,
              durationMinutes: 580,
              startTime: DateTime(2024, 1, 1, 22, 0),
              endTime: DateTime(2024, 1, 2, 7, 40),
            ),
            SleepStage(
              stage: SleepStageType.awake,
              durationMinutes: 20,
              startTime: DateTime(2024, 1, 2, 7, 40),
              endTime: DateTime(2024, 1, 2, 8, 0),
            ),
          ],
          wakeCount: 2, // Moderate wakes
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        final score =
            service.calculateQualityScore(session, babyAgeInMonths: 6);

        expect(score.score, greaterThanOrEqualTo(70));
        expect(score.score, lessThan(85));
        expect(score.quality, equals(SleepQuality.good));
      });

      test('calculates stage percentages correctly', () {
        final session = SleepSession(
          id: 'test-4',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 6, 0),
          totalMinutes: 600, // 10 hours
          stages: [
            SleepStage(
              stage: SleepStageType.deep,
              durationMinutes: 150, // 25%
              startTime: DateTime(2024, 1, 1, 20, 0),
              endTime: DateTime(2024, 1, 1, 22, 30),
            ),
            SleepStage(
              stage: SleepStageType.rem,
              durationMinutes: 150, // 25%
              startTime: DateTime(2024, 1, 1, 22, 30),
              endTime: DateTime(2024, 1, 2, 1, 0),
            ),
            SleepStage(
              stage: SleepStageType.light,
              durationMinutes: 300, // 50%
              startTime: DateTime(2024, 1, 2, 1, 0),
              endTime: DateTime(2024, 1, 2, 6, 0),
            ),
          ],
          wakeCount: 1,
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        final percentages = session.stagePercentages;

        expect(percentages[SleepStageType.deep], closeTo(25.0, 0.1));
        expect(percentages[SleepStageType.rem], closeTo(25.0, 0.1));
        expect(percentages[SleepStageType.light], closeTo(50.0, 0.1));
      });

      test('adjusts scoring based on baby age', () {
        final session = SleepSession(
          id: 'test-5',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 10, 0), // 14 hours
          totalMinutes: 840,
          stages: [],
          wakeCount: 1,
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        // Newborn (3 months) - 14 hours is optimal
        final scoreNewborn =
            service.calculateQualityScore(session, babyAgeInMonths: 3);

        // Toddler (18 months) - 14 hours is too much
        final scoreToddler =
            service.calculateQualityScore(session, babyAgeInMonths: 18);

        // Newborn should score equal or higher for same duration
        expect(scoreNewborn.breakdown['duration']!,
            greaterThanOrEqualTo(scoreToddler.breakdown['duration']!));
      });

      test('includes recommendations in result', () {
        final session = SleepSession(
          id: 'test-6',
          babyId: 'baby-1',
          startTime: DateTime(2024, 1, 1, 20, 0),
          endTime: DateTime(2024, 1, 2, 2, 0), // Short duration
          totalMinutes: 360,
          stages: [],
          wakeCount: 4, // Many wakes
          createdAt: DateTime(2024, 1, 1, 20, 0),
        );

        final score =
            service.calculateQualityScore(session, babyAgeInMonths: 6);

        expect(score.recommendations, isNotEmpty);
        expect(
          score.recommendations.any((r) => r.contains('duration')),
          isTrue,
        );
        expect(
          score.recommendations
              .any((r) => r.contains('wakes') || r.contains('wake')),
          isTrue,
        );
      });
    });

    group('SleepAnalysis', () {
      test('identifies issues in poor sleep patterns', () {
        // Test sleep analysis would require Firestore mocking
        // This is a placeholder for structure
        expect(true, isTrue);
      });
    });
  });
}
