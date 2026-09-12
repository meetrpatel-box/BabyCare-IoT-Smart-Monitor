import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/cry_detection_service.dart';
import 'package:baby_track_flutter/models/cry_event_model.dart';

void main() {
  group('CryDetectionService', () {
    late CryDetectionService service;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = CryDetectionService(firestore: fakeFirestore);
    });

    group('classifyCryPattern (heuristic fallback)', () {
      test('short high-intensity cry classified as pain', () {
        final result = service.classifyCryPattern(
          durationSeconds: 20,
          intensity: 0.9,
          timeOfDay: DateTime(2024, 1, 1, 14, 0),
        );
        expect(result, equals(CryClassification.pain));
      });

      test('long moderate-intensity cry classified as tired', () {
        final result = service.classifyCryPattern(
          durationSeconds: 150,
          intensity: 0.4,
          timeOfDay: DateTime(2024, 1, 1, 18, 0),
        );
        expect(result, equals(CryClassification.tired));
      });

      test('nighttime high-intensity cry classified as discomfort', () {
        final result = service.classifyCryPattern(
          durationSeconds: 60,
          intensity: 0.8,
          timeOfDay: DateTime(2024, 1, 1, 23, 0),
        );
        expect(result, equals(CryClassification.discomfort));
      });

      test('early morning high-intensity cry classified as discomfort', () {
        final result = service.classifyCryPattern(
          durationSeconds: 60,
          intensity: 0.8,
          timeOfDay: DateTime(2024, 1, 1, 3, 0),
        );
        expect(result, equals(CryClassification.discomfort));
      });

      test('short burst classified as attention', () {
        final result = service.classifyCryPattern(
          durationSeconds: 45,
          intensity: 0.7,
          timeOfDay: DateTime(2024, 1, 1, 10, 0),
        );
        expect(result, equals(CryClassification.attention));
      });

      test('moderate duration and intensity classified as hungry', () {
        final result = service.classifyCryPattern(
          durationSeconds: 90,
          intensity: 0.6,
          timeOfDay: DateTime(2024, 1, 1, 12, 0),
        );
        expect(result, equals(CryClassification.hungry));
      });

      test('low-intensity long cry returns unknown', () {
        final result = service.classifyCryPattern(
          durationSeconds: 90,
          intensity: 0.3,
          timeOfDay: DateTime(2024, 1, 1, 10, 0),
        );
        expect(result, equals(CryClassification.unknown));
      });

      test('boundary: 29s at high intensity is pain', () {
        final result = service.classifyCryPattern(
          durationSeconds: 29,
          intensity: 0.85,
          timeOfDay: DateTime(2024, 1, 1, 12, 0),
        );
        expect(result, equals(CryClassification.pain));
      });

      test('boundary: 30s at high intensity is NOT pain', () {
        final result = service.classifyCryPattern(
          durationSeconds: 30,
          intensity: 0.85,
          timeOfDay: DateTime(2024, 1, 1, 12, 0),
        );
        expect(result, equals(CryClassification.attention));
      });

      test('daytime short low-intensity cry returns unknown', () {
        final result = service.classifyCryPattern(
          durationSeconds: 15,
          intensity: 0.2,
          timeOfDay: DateTime(2024, 1, 1, 14, 0),
        );
        expect(result, equals(CryClassification.unknown));
      });
    });

    group('progressive event lifecycle', () {
      const babyId = 'test-baby-1';
      const deviceId = 'pod-001';

      test('createFromEdgeDetection creates event in Firestore', () async {
        final eventId = await service.createFromEdgeDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        expect(eventId, isNotEmpty);

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['babyId'], equals(babyId));
        expect(doc.data()!['deviceId'], equals(deviceId));
        expect(doc.data()!['intensity'], equals(0.85));
        expect(doc.data()!['classificationSource'], equals('edge'));
      });

      test('updateWithEdgeClassification updates event', () async {
        final eventId = await service.createFromEdgeDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await service.updateWithEdgeClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.hungry,
          confidence: 0.72,
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['edgeClassification'], equals('hungry'));
        expect(doc.data()!['edgeConfidence'], equals(0.72));
        expect(doc.data()!['classification'], equals('hungry'));
        expect(doc.data()!['classificationSource'], equals('edge'));
      });

      test('updateWithCloudClassification overrides edge result', () async {
        final eventId = await service.createFromEdgeDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await service.updateWithEdgeClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.hungry,
          confidence: 0.72,
        );

        await service.updateWithCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.tired,
          confidence: 0.89,
          audioFeaturesPath: 'cry_features/test-baby-1/evt1.bin',
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['cloudClassification'], equals('tired'));
        expect(doc.data()!['cloudConfidence'], equals(0.89));
        // Cloud overrides edge
        expect(doc.data()!['classification'], equals('tired'));
        expect(doc.data()!['classificationSource'], equals('cloud'));
        expect(doc.data()!['hasAudioFeatures'], isTrue);
      });

      test('endCryEvent sets endTime and duration', () async {
        final eventId = await service.createFromEdgeDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final endTime = DateTime.now().add(const Duration(seconds: 45));
        await service.endCryEvent(
          babyId: babyId,
          eventId: eventId,
          endTime: endTime,
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['endTime'], isNotNull);
        expect(doc.data()!['durationSeconds'], isNotNull);
      });
    });

    group('logManualCryEvent', () {
      test('creates event with heuristic source', () async {
        final now = DateTime.now();
        final eventId = await service.logManualCryEvent(
          babyId: 'baby-1',
          startTime: now,
          endTime: now.add(const Duration(minutes: 2)),
          classification: CryClassification.hungry,
          intensity: 0.7,
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc('baby-1')
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['classification'], equals('hungry'));
        expect(doc.data()!['classificationSource'], equals('heuristic'));
        expect(doc.data()!['durationSeconds'], equals(120));
      });
    });
  });

  group('CryEvent model', () {
    test('CryClassification.fromString parses all types', () {
      expect(CryClassification.fromString('hungry'), CryClassification.hungry);
      expect(CryClassification.fromString('tired'), CryClassification.tired);
      expect(CryClassification.fromString('pain'), CryClassification.pain);
      expect(CryClassification.fromString('gassy'), CryClassification.gassy);
      expect(CryClassification.fromString('colic'), CryClassification.colic);
      expect(CryClassification.fromString(null), CryClassification.unknown);
      expect(CryClassification.fromString('bogus'), CryClassification.unknown);
    });

    test('CryDataConsent.fromString parses all levels', () {
      expect(CryDataConsent.fromString('featuresOnly'),
          CryDataConsent.featuresOnly);
      expect(CryDataConsent.fromString('fullAudio'), CryDataConsent.fullAudio);
      expect(CryDataConsent.fromString('none'), CryDataConsent.none);
      expect(CryDataConsent.fromString(null), CryDataConsent.featuresOnly);
    });

    test('CryResolution.fromString parses all types', () {
      expect(CryResolution.fromString('fed'), CryResolution.fed);
      expect(
          CryResolution.fromString('diaperChange'), CryResolution.diaperChange);
      expect(CryResolution.fromString('rocked'), CryResolution.rocked);
      expect(CryResolution.fromString(null), CryResolution.other);
    });

    test('groundTruthLabel returns parentCorrectedType first', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        cloudClassification: CryClassification.hungry,
        parentConfirmed: true,
        parentCorrectedType: CryClassification.tired,
      );
      expect(event.groundTruthLabel, CryClassification.tired);
    });

    test('groundTruthLabel returns confirmed cloud classification', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        cloudClassification: CryClassification.hungry,
        parentConfirmed: true,
      );
      expect(event.groundTruthLabel, CryClassification.hungry);
    });

    test('groundTruthLabel returns null when no feedback', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        cloudClassification: CryClassification.hungry,
        parentConfirmed: false,
      );
      expect(event.groundTruthLabel, isNull);
      expect(event.hasGroundTruth, isFalse);
    });

    test('isExportReady checks all conditions', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        parentConfirmed: true,
        cloudClassification: CryClassification.hungry,
        hasAudioFeatures: true,
        exportedToTraining: false,
        dataConsent: CryDataConsent.featuresOnly,
      );
      expect(event.isExportReady, isTrue);
    });

    test('isExportReady false when already exported', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        parentConfirmed: true,
        cloudClassification: CryClassification.hungry,
        hasAudioFeatures: true,
        exportedToTraining: true,
        dataConsent: CryDataConsent.featuresOnly,
      );
      expect(event.isExportReady, isFalse);
    });

    test('isExportReady false when consent is none', () {
      final event = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        parentConfirmed: true,
        cloudClassification: CryClassification.hungry,
        hasAudioFeatures: true,
        exportedToTraining: false,
        dataConsent: CryDataConsent.none,
      );
      expect(event.isExportReady, isFalse);
    });

    test('CrySensorContext.timeOfDayLabel returns correct labels', () {
      expect(CrySensorContext.timeOfDayLabel(DateTime(2024, 1, 1, 8, 0)),
          'morning');
      expect(CrySensorContext.timeOfDayLabel(DateTime(2024, 1, 1, 14, 0)),
          'afternoon');
      expect(CrySensorContext.timeOfDayLabel(DateTime(2024, 1, 1, 19, 0)),
          'evening');
      expect(CrySensorContext.timeOfDayLabel(DateTime(2024, 1, 1, 3, 0)),
          'night');
    });

    test('toFirestore and fromFirestore round-trip', () {
      final now = DateTime.now();
      // Truncate to seconds for Timestamp round-trip
      final truncated = DateTime.fromMillisecondsSinceEpoch(
          (now.millisecondsSinceEpoch ~/ 1000) * 1000);
      final original = CryEvent(
        id: 'test-id',
        babyId: 'baby-1',
        deviceId: 'pod-001',
        startTime: truncated,
        intensity: 0.85,
        createdAt: truncated,
        edgeClassification: CryClassification.hungry,
        edgeConfidence: 0.72,
        classification: CryClassification.hungry,
        classificationSource: ClassificationSource.edge,
        dataConsent: CryDataConsent.fullAudio,
        sensorContext: const CrySensorContext(
          heartRate: 142,
          bodyTemp: 37.1,
          timeOfDay: 'night',
        ),
      );

      final map = original.toFirestore();

      expect(map['babyId'], 'baby-1');
      expect(map['deviceId'], 'pod-001');
      expect(map['edgeClassification'], 'hungry');
      expect(map['edgeConfidence'], 0.72);
      expect(map['classificationSource'], 'edge');
      expect(map['dataConsent'], 'fullAudio');
      expect((map['sensorContext'] as Map)['heartRate'], 142);
    });

    test('copyWith preserves unmodified fields', () {
      final original = CryEvent(
        id: '1',
        babyId: 'baby-1',
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        intensity: 0.85,
        classification: CryClassification.hungry,
      );

      final modified = original.copyWith(
        classification: CryClassification.tired,
        cloudConfidence: 0.91,
      );

      expect(modified.babyId, original.babyId);
      expect(modified.intensity, original.intensity);
      expect(modified.classification, CryClassification.tired);
      expect(modified.cloudConfidence, 0.91);
    });
  });
}
