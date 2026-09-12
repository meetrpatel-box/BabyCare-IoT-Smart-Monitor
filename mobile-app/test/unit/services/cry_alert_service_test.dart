import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/cry_alert_service.dart';
import 'package:baby_track_flutter/services/cry_detection_service.dart';
import 'package:baby_track_flutter/models/cry_event_model.dart';

void main() {
  late CryAlertService alertService;
  late CryDetectionService detectionService;
  late FakeFirebaseFirestore fakeFirestore;

  const babyId = 'test-baby-1';
  const deviceId = 'pod-001';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    detectionService = CryDetectionService(firestore: fakeFirestore);
    alertService = CryAlertService(
      detectionService: detectionService,
      firestore: fakeFirestore,
    );
  });

  tearDown(() {
    alertService.dispose();
  });

  group('CryAlertService', () {
    group('handleBleDetection', () {
      test('emits Tier 1 detection alert', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(1));
        expect(alerts.first.tier, equals(AlertTier.detection));
        expect(alerts.first.babyId, equals(babyId));
        expect(alerts.first.title, equals('Baby is crying!'));
        expect(alerts.first.subtitle, contains('85%'));
        expect(alerts.first.classification, isNull);

        await sub.cancel();
      });

      test('creates event in Firestore', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final events = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .get();

        expect(events.docs, hasLength(1));
        expect(events.docs.first.data()['intensity'], equals(0.85));
      });

      test('tracks active event ID', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        expect(alertService.getActiveEventId(babyId), isNotNull);
      });

      test('debounces rapid detections for same baby', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.90,
        );

        await Future.delayed(Duration.zero);

        // Only first detection should produce an alert (2 min cooldown)
        expect(alerts, hasLength(1));

        await sub.cancel();
      });

      test('allows alerts for different babies', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: 'baby-1',
          deviceId: deviceId,
          intensity: 0.85,
        );
        await alertService.handleBleDetection(
          babyId: 'baby-2',
          deviceId: deviceId,
          intensity: 0.90,
        );

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(2));
        expect(alerts[0].babyId, equals('baby-1'));
        expect(alerts[1].babyId, equals('baby-2'));

        await sub.cancel();
      });
    });

    group('handleBleClassification', () {
      test('emits Tier 2 preliminary alert', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        // First trigger detection to set active event
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await alertService.handleBleClassification(
          babyId: babyId,
          classification: CryClassification.hungry,
          confidence: 0.72,
        );

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(2));
        expect(alerts[1].tier, equals(AlertTier.preliminary));
        expect(alerts[1].title, equals('Preliminary: Hungry'));
        expect(alerts[1].subtitle, contains('72%'));
        expect(alerts[1].classification, equals(CryClassification.hungry));

        await sub.cancel();
      });

      test('updates Firestore with edge classification', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await alertService.handleBleClassification(
          babyId: babyId,
          classification: CryClassification.hungry,
          confidence: 0.72,
        );

        final eventId = alertService.getActiveEventId(babyId)!;
        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['edgeClassification'], equals('hungry'));
        expect(doc.data()!['edgeConfidence'], equals(0.72));
      });

      test('does nothing if no active event for baby', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleClassification(
          babyId: babyId,
          classification: CryClassification.hungry,
          confidence: 0.72,
        );

        await Future.delayed(Duration.zero);

        expect(alerts, isEmpty);

        await sub.cancel();
      });
    });

    group('handleCloudClassification', () {
      test('emits Tier 3 confirmed alert with suggestion', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final eventId = alertService.getActiveEventId(babyId)!;

        await alertService.handleCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.hungry,
          confidence: 0.89,
        );

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(2));
        expect(alerts[1].tier, equals(AlertTier.confirmed));
        expect(alerts[1].title, equals('Confirmed: Hungry'));
        expect(alerts[1].subtitle, contains('89%'));
        expect(alerts[1].suggestion, isNotNull);
        expect(alerts[1].suggestion, contains('feed'));

        await sub.cancel();
      });

      test('updates Firestore with cloud classification', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final eventId = alertService.getActiveEventId(babyId)!;

        await alertService.handleCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.tired,
          confidence: 0.89,
          audioFeaturesPath: 'features/test.bin',
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['cloudClassification'], equals('tired'));
        expect(doc.data()!['cloudConfidence'], equals(0.89));
        expect(doc.data()!['classification'], equals('tired'));
        expect(doc.data()!['classificationSource'], equals('cloud'));
        expect(doc.data()!['hasAudioFeatures'], isTrue);
      });

      test('generates context-aware suggestion with sensor data', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final eventId = alertService.getActiveEventId(babyId)!;

        await alertService.handleCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.hungry,
          confidence: 0.89,
          sensorContext: const CrySensorContext(lastFeedMinutesAgo: 120),
        );

        await Future.delayed(Duration.zero);

        final confirmed = alerts.last;
        expect(confirmed.suggestion, contains('120 min'));

        await sub.cancel();
      });
    });

    group('handleCryEnded', () {
      test('emits resolved alert', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        await alertService.handleCryEnded(babyId: babyId);

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(2));
        expect(alerts[1].tier, equals(AlertTier.resolved));
        expect(alerts[1].title, equals('Crying stopped'));

        await sub.cancel();
      });

      test('clears active event ID', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );
        expect(alertService.getActiveEventId(babyId), isNotNull);

        await alertService.handleCryEnded(babyId: babyId);

        expect(alertService.getActiveEventId(babyId), isNull);
      });

      test('sets endTime in Firestore', () async {
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        // Need to get event ID before ending clears it
        final events = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .get();
        final eventId = events.docs.first.id;

        await alertService.handleCryEnded(babyId: babyId);

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()!['endTime'], isNotNull);
        expect(doc.data()!['durationSeconds'], isNotNull);
      });

      test('does nothing if no active event for baby', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleCryEnded(babyId: babyId);

        await Future.delayed(Duration.zero);

        expect(alerts, isEmpty);

        await sub.cancel();
      });
    });

    group('suggestion generation', () {
      Future<String?> getSuggestionFor(CryClassification classification,
          {CrySensorContext? context}) async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final eventId = alertService.getActiveEventId(babyId)!;

        await alertService.handleCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: classification,
          confidence: 0.9,
          sensorContext: context,
        );

        await Future.delayed(Duration.zero);
        await sub.cancel();

        return alerts.last.suggestion;
      }

      test('hungry suggestion mentions feeding', () async {
        final suggestion = await getSuggestionFor(CryClassification.hungry);
        expect(suggestion, contains('feed'));
      });

      test('tired suggestion mentions nap', () async {
        final suggestion = await getSuggestionFor(CryClassification.tired);
        expect(suggestion, contains('nap'));
      });

      test('pain suggestion mentions pediatrician', () async {
        final suggestion = await getSuggestionFor(CryClassification.pain);
        expect(suggestion, contains('pediatrician'));
      });

      test('gassy suggestion mentions tummy massage', () async {
        final suggestion = await getSuggestionFor(CryClassification.gassy);
        expect(suggestion, contains('tummy massage'));
      });

      test('overstimulated suggestion mentions quiet', () async {
        final suggestion =
            await getSuggestionFor(CryClassification.overstimulated);
        expect(suggestion, contains('quiet'));
      });

      test('colic suggestion mentions white noise', () async {
        final suggestion = await getSuggestionFor(CryClassification.colic);
        expect(suggestion, contains('white noise'));
      });

      test('discomfort with diaper context includes diaper info', () async {
        final suggestion = await getSuggestionFor(
          CryClassification.discomfort,
          context: const CrySensorContext(lastDiaperMinutesAgo: 45),
        );
        expect(suggestion, contains('45 min'));
        expect(suggestion, contains('diaper'));
      });
    });

    group('full progressive flow', () {
      test('detection → preliminary → confirmed → resolved', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        // Tier 1: Detection
        await alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: 0.85,
        );

        final eventId = alertService.getActiveEventId(babyId)!;

        // Tier 2: Preliminary
        await alertService.handleBleClassification(
          babyId: babyId,
          classification: CryClassification.hungry,
          confidence: 0.65,
        );

        // Tier 3: Confirmed
        await alertService.handleCloudClassification(
          babyId: babyId,
          eventId: eventId,
          classification: CryClassification.hungry,
          confidence: 0.92,
        );

        // Resolved
        await alertService.handleCryEnded(babyId: babyId);

        await Future.delayed(Duration.zero);

        expect(alerts, hasLength(4));
        expect(alerts[0].tier, equals(AlertTier.detection));
        expect(alerts[1].tier, equals(AlertTier.preliminary));
        expect(alerts[2].tier, equals(AlertTier.confirmed));
        expect(alerts[3].tier, equals(AlertTier.resolved));

        await sub.cancel();
      });
    });
  });

  group('AlertTier', () {
    test('has all expected values', () {
      expect(AlertTier.values, hasLength(4));
      expect(AlertTier.values,
          containsAll([AlertTier.detection, AlertTier.preliminary,
              AlertTier.confirmed, AlertTier.resolved]));
    });
  });

  group('CryAlert', () {
    test('constructor stores all fields', () {
      final now = DateTime.now();
      final alert = CryAlert(
        eventId: 'evt-1',
        babyId: 'baby-1',
        tier: AlertTier.confirmed,
        title: 'Confirmed: Hungry',
        subtitle: '89%',
        classification: CryClassification.hungry,
        confidence: 0.89,
        suggestion: 'Try feeding',
        timestamp: now,
      );

      expect(alert.eventId, equals('evt-1'));
      expect(alert.babyId, equals('baby-1'));
      expect(alert.tier, equals(AlertTier.confirmed));
      expect(alert.title, equals('Confirmed: Hungry'));
      expect(alert.subtitle, equals('89%'));
      expect(alert.classification, equals(CryClassification.hungry));
      expect(alert.confidence, equals(0.89));
      expect(alert.suggestion, equals('Try feeding'));
      expect(alert.timestamp, equals(now));
    });
  });
}
