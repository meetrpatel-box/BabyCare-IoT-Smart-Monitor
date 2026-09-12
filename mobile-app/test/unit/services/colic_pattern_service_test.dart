import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/services/colic_pattern_service.dart';
import 'package:baby_track_flutter/models/colic_pattern_model.dart';

void main() {
  group('ColicPatternService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ColicPatternService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ColicPatternService(firestore: fakeFirestore);
    });

    Future<void> _addColicPattern(
      String babyId,
      String docId,
      Map<String, dynamic> data,
    ) async {
      await fakeFirestore
          .collection('babies')
          .doc(babyId)
          .collection('colicPatterns')
          .doc(docId)
          .set(data);
    }

    group('getLatestAnalysis', () {
      test('returns null when no patterns exist', () async {
        final result = await service.getLatestAnalysis('baby-1');
        expect(result, isNull);
      });

      test('returns the latest analysis by analyzedAt', () async {
        await _addColicPattern('baby-1', '2026-02-18', {
          'babyId': 'baby-1',
          'analysisDate': '2026-02-18',
          'riskLevel': 'mild',
          'riskScore': 20,
          'currentStreak': 1,
          'longestStreak': 1,
          'wesselWeeksCount': 0,
          'dailyAnalysis': [],
          'weeklySummaries': [],
          'suggestions': ['Monitor patterns.'],
          'analyzedAt': Timestamp.fromDate(DateTime(2026, 2, 18)),
        });

        await _addColicPattern('baby-1', '2026-02-19', {
          'babyId': 'baby-1',
          'analysisDate': '2026-02-19',
          'riskLevel': 'moderate',
          'riskScore': 45,
          'currentStreak': 2,
          'longestStreak': 3,
          'wesselWeeksCount': 1,
          'dailyAnalysis': [],
          'weeklySummaries': [],
          'suggestions': ['See pediatrician.'],
          'analyzedAt': Timestamp.fromDate(DateTime(2026, 2, 19)),
        });

        final result = await service.getLatestAnalysis('baby-1');
        expect(result, isNotNull);
        expect(result!.analysisDate, '2026-02-19');
        expect(result.riskLevel, ColicRiskLevel.moderate);
        expect(result.riskScore, 45);
      });
    });

    group('getAnalysisHistory', () {
      test('returns empty list when no patterns exist', () async {
        final history = await service.getAnalysisHistory('baby-1');
        expect(history, isEmpty);
      });

      test('returns analysis history in descending order', () async {
        for (int i = 15; i <= 19; i++) {
          await _addColicPattern('baby-1', '2026-02-$i', {
            'babyId': 'baby-1',
            'analysisDate': '2026-02-$i',
            'riskLevel': 'none',
            'riskScore': 0,
            'currentStreak': 0,
            'longestStreak': 0,
            'wesselWeeksCount': 0,
            'dailyAnalysis': [],
            'weeklySummaries': [],
            'suggestions': [],
            'analyzedAt': Timestamp.fromDate(DateTime(2026, 2, i)),
          });
        }

        final history = await service.getAnalysisHistory('baby-1', limit: 3);
        expect(history.length, 3);
        // Should be most recent first
        expect(history[0].analysisDate, '2026-02-19');
        expect(history[1].analysisDate, '2026-02-18');
        expect(history[2].analysisDate, '2026-02-17');
      });
    });

    group('streamLatestAnalysis', () {
      test('emits null when no patterns exist', () async {
        final stream = service.streamLatestAnalysis('baby-1');
        final result = await stream.first;
        expect(result, isNull);
      });

      test('emits latest pattern when data exists', () async {
        await _addColicPattern('baby-1', '2026-02-19', {
          'babyId': 'baby-1',
          'analysisDate': '2026-02-19',
          'riskLevel': 'mild',
          'riskScore': 15,
          'currentStreak': 0,
          'longestStreak': 0,
          'wesselWeeksCount': 0,
          'dailyAnalysis': [],
          'weeklySummaries': [],
          'suggestions': [],
          'analyzedAt': Timestamp.fromDate(DateTime(2026, 2, 19)),
        });

        final stream = service.streamLatestAnalysis('baby-1');
        final result = await stream.first;
        expect(result, isNotNull);
        expect(result!.riskLevel, ColicRiskLevel.mild);
      });
    });

    group('getQuickRiskLevel', () {
      test('returns none when baby does not exist', () async {
        final risk = await service.getQuickRiskLevel('nonexistent');
        expect(risk, ColicRiskLevel.none);
      });

      test('returns none when no latestVitals', () async {
        await fakeFirestore.collection('babies').doc('baby-1').set({
          'name': 'Test Baby',
        });

        final risk = await service.getQuickRiskLevel('baby-1');
        expect(risk, ColicRiskLevel.none);
      });

      test('returns risk level from latestVitals', () async {
        await fakeFirestore.collection('babies').doc('baby-1').set({
          'name': 'Test Baby',
          'latestVitals': {
            'colicRiskLevel': 'moderate',
            'colicRiskScore': 45,
          },
        });

        final risk = await service.getQuickRiskLevel('baby-1');
        expect(risk, ColicRiskLevel.moderate);
      });
    });
  });
}
