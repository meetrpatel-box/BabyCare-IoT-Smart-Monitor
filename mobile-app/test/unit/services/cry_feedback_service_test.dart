import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/services/cry_feedback_service.dart';
import 'package:baby_track_flutter/models/cry_event_model.dart';

void main() {
  late CryFeedbackService service;
  late FakeFirebaseFirestore fakeFirestore;

  const babyId = 'test-baby-1';

  /// Helper to seed a cry event in Firestore
  Future<String> seedCryEvent({
    bool parentConfirmed = false,
    String? parentCorrectedType,
    String? classification,
    String classificationSource = 'cloud',
    DateTime? startTime,
  }) async {
    final doc = await fakeFirestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .add({
      'babyId': babyId,
      'startTime': Timestamp.fromDate(startTime ?? DateTime.now()),
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'intensity': 0.7,
      'classification': classification ?? 'hungry',
      'classificationSource': classificationSource,
      'parentConfirmed': parentConfirmed,
      if (parentCorrectedType != null)
        'parentCorrectedType': parentCorrectedType,
    });
    return doc.id;
  }

  Future<Map<String, dynamic>> readEvent(String eventId) async {
    final doc = await fakeFirestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .doc(eventId)
        .get();
    return doc.data()!;
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = CryFeedbackService(firestore: fakeFirestore);
  });

  group('CryFeedbackService', () {
    group('confirmClassification', () {
      test('sets parentConfirmed to true', () async {
        final eventId = await seedCryEvent();

        await service.confirmClassification(
          babyId: babyId,
          eventId: eventId,
        );

        final data = await readEvent(eventId);
        expect(data['parentConfirmed'], isTrue);
        expect(data['correctedAt'], isNotNull);
      });
    });

    group('correctClassification', () {
      test('sets corrected type and updates classification', () async {
        final eventId = await seedCryEvent(classification: 'hungry');

        await service.correctClassification(
          babyId: babyId,
          eventId: eventId,
          correctedType: CryClassification.tired,
        );

        final data = await readEvent(eventId);
        expect(data['parentCorrectedType'], equals('tired'));
        expect(data['parentConfirmed'], isFalse);
        expect(data['classification'], equals('tired'));
        expect(data['classificationSource'], equals('parentCorrected'));
        expect(data['correctedAt'], isNotNull);
      });
    });

    group('logResolution', () {
      test('sets resolution field', () async {
        final eventId = await seedCryEvent();

        await service.logResolution(
          babyId: babyId,
          eventId: eventId,
          resolution: CryResolution.fed,
        );

        final data = await readEvent(eventId);
        expect(data['resolution'], equals('fed'));
      });

      test('sets diaperChange resolution', () async {
        final eventId = await seedCryEvent();

        await service.logResolution(
          babyId: babyId,
          eventId: eventId,
          resolution: CryResolution.diaperChange,
        );

        final data = await readEvent(eventId);
        expect(data['resolution'], equals('diaperChange'));
      });
    });

    group('submitFeedback', () {
      test('isCorrect=true sets parentConfirmed', () async {
        final eventId = await seedCryEvent();

        await service.submitFeedback(
          babyId: babyId,
          eventId: eventId,
          isCorrect: true,
        );

        final data = await readEvent(eventId);
        expect(data['parentConfirmed'], isTrue);
        expect(data['correctedAt'], isNotNull);
      });

      test('isCorrect=false with correctedType updates classification',
          () async {
        final eventId = await seedCryEvent(classification: 'hungry');

        await service.submitFeedback(
          babyId: babyId,
          eventId: eventId,
          isCorrect: false,
          correctedType: CryClassification.pain,
          resolution: CryResolution.held,
        );

        final data = await readEvent(eventId);
        expect(data['parentCorrectedType'], equals('pain'));
        expect(data['parentConfirmed'], isFalse);
        expect(data['classification'], equals('pain'));
        expect(data['classificationSource'], equals('parentCorrected'));
        expect(data['resolution'], equals('held'));
      });

      test('isCorrect=true with resolution sets both', () async {
        final eventId = await seedCryEvent();

        await service.submitFeedback(
          babyId: babyId,
          eventId: eventId,
          isCorrect: true,
          resolution: CryResolution.fed,
        );

        final data = await readEvent(eventId);
        expect(data['parentConfirmed'], isTrue);
        expect(data['resolution'], equals('fed'));
      });
    });

    group('attemptPassiveLabel', () {
      test('feeding action labels recent cry as hungry', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 5));
        final eventId = await seedCryEvent(
          startTime: cryTime,
          parentConfirmed: false,
        );

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'feeding',
          actionTime: DateTime.now(),
        );

        expect(result, equals(eventId));

        final data = await readEvent(eventId);
        expect(data['parentCorrectedType'], equals('hungry'));
        expect(data['resolution'], equals('fed'));
        expect(data['classification'], equals('hungry'));
        expect(data['classificationSource'], equals('parentCorrected'));
      });

      test('diaper action labels recent cry as discomfort', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 3));
        await seedCryEvent(
          startTime: cryTime,
          parentConfirmed: false,
        );

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'diaper',
          actionTime: DateTime.now(),
        );

        expect(result, isNotNull);
        final data = await readEvent(result!);
        expect(data['parentCorrectedType'], equals('discomfort'));
        expect(data['resolution'], equals('diaperChange'));
      });

      test('sleep action labels recent cry as tired', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 10));
        await seedCryEvent(
          startTime: cryTime,
          parentConfirmed: false,
        );

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'sleep',
          actionTime: DateTime.now(),
        );

        expect(result, isNotNull);
        final data = await readEvent(result!);
        expect(data['parentCorrectedType'], equals('tired'));
        expect(data['resolution'], equals('sleep'));
      });

      test('returns null for unknown action type', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 3));
        await seedCryEvent(startTime: cryTime, parentConfirmed: false);

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'bath',
          actionTime: DateTime.now(),
        );

        expect(result, isNull);
      });

      test('returns null when no recent cry events exist', () async {
        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'feeding',
          actionTime: DateTime.now(),
        );

        expect(result, isNull);
      });

      test('skips events with existing parent correction', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 3));
        await seedCryEvent(
          startTime: cryTime,
          parentConfirmed: false,
          parentCorrectedType: 'pain',
        );

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'feeding',
          actionTime: DateTime.now(),
        );

        expect(result, isNull);
      });

      test('skips events already confirmed by parent', () async {
        final cryTime = DateTime.now().subtract(const Duration(minutes: 3));
        await seedCryEvent(
          startTime: cryTime,
          parentConfirmed: true,
        );

        final result = await service.attemptPassiveLabel(
          babyId: babyId,
          actionType: 'feeding',
          actionTime: DateTime.now(),
        );

        // parentConfirmed=true is filtered out by the query
        expect(result, isNull);
      });
    });

    group('getFeedbackStats', () {
      test('returns zeros when no events', () async {
        final stats = await service.getFeedbackStats(babyId);

        expect(stats.totalEvents, equals(0));
        expect(stats.confirmed, equals(0));
        expect(stats.corrected, equals(0));
        expect(stats.unlabeled, equals(0));
        expect(stats.withResolution, equals(0));
        expect(stats.feedbackRate, equals(0.0));
      });

      test('counts confirmed, corrected, unlabeled events', () async {
        // Confirmed event
        await seedCryEvent(parentConfirmed: true);
        // Corrected event
        await seedCryEvent(
            parentConfirmed: false, parentCorrectedType: 'tired');
        // Unlabeled event
        await seedCryEvent(parentConfirmed: false);

        final stats = await service.getFeedbackStats(babyId);

        expect(stats.totalEvents, equals(3));
        expect(stats.confirmed, equals(1));
        expect(stats.corrected, equals(1));
        expect(stats.unlabeled, equals(1));
        expect(stats.feedbackRate, closeTo(2 / 3, 0.01));
      });

      test('counts events with resolution', () async {
        final eventId = await seedCryEvent(parentConfirmed: true);
        await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .update({'resolution': 'fed'});

        final stats = await service.getFeedbackStats(babyId);

        expect(stats.withResolution, equals(1));
      });
    });
  });
}
