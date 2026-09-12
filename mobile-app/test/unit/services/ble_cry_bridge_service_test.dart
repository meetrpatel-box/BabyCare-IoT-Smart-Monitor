import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/cry_alert_service.dart';
import 'package:baby_track_flutter/services/cry_detection_service.dart';
import 'package:baby_track_flutter/services/ble_cry_bridge_service.dart';
import 'package:baby_track_flutter/models/cry_event_model.dart';

void main() {
  late BleCryBridgeService bridgeService;
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
    bridgeService = BleCryBridgeService(
      alertService: alertService,
      firestore: fakeFirestore,
    );
  });

  tearDown(() {
    bridgeService.dispose();
    alertService.dispose();
  });

  group('BleCryBridgeService', () {
    group('initial state', () {
      test('starts in disconnected state', () {
        expect(bridgeService.connectionState,
            equals(BleBridgeConnectionState.disconnected));
        expect(bridgeService.isConnected, isFalse);
        expect(bridgeService.connectedDevice, isNull);
      });
    });

    group('connectionStateStream', () {
      test('emits state changes', () async {
        final states = <BleBridgeConnectionState>[];
        final sub = bridgeService.connectionStateStream.listen(states.add);

        // Trigger state change through Firestore fallback (which is always available)
        bridgeService.startFirestoreFallback(
          deviceId: deviceId,
          babyId: babyId,
        );

        // State should remain disconnected for Firestore fallback
        await Future.delayed(const Duration(milliseconds: 50));
        expect(bridgeService.connectionState,
            equals(BleBridgeConnectionState.disconnected));

        await sub.cancel();
      });
    });

    group('Firestore fallback — simulateDetection', () {
      test('creates detection document in Firestore', () async {
        await bridgeService.simulateDetection(
          deviceId: deviceId,
          babyId: babyId,
          intensity: 0.9,
        );

        final docs = await fakeFirestore
            .collection('devices')
            .doc(deviceId)
            .collection('cryDetections')
            .get();

        expect(docs.docs, hasLength(1));
        expect(docs.docs.first.data()['type'], equals('detection'));
        expect(docs.docs.first.data()['intensity'], equals(0.9));
        expect(docs.docs.first.data()['processed'], isFalse);
      });

      test('creates detection with sensor context', () async {
        await bridgeService.simulateDetection(
          deviceId: deviceId,
          babyId: babyId,
          intensity: 0.85,
          sensorContext: CrySensorContext(
            heartRate: 120,
            bodyTemp: 36.8,
            lastFeedMinutesAgo: 45,
          ),
        );

        final docs = await fakeFirestore
            .collection('devices')
            .doc(deviceId)
            .collection('cryDetections')
            .get();

        expect(docs.docs.first.data()['sensorContext'], isNotNull);
        expect(
            docs.docs.first.data()['sensorContext']['heartRate'], equals(120));
      });
    });

    group('Firestore fallback — simulateClassification', () {
      test('creates classification document', () async {
        await bridgeService.simulateClassification(
          deviceId: deviceId,
          classification: CryClassification.hungry,
          confidence: 0.88,
        );

        final docs = await fakeFirestore
            .collection('devices')
            .doc(deviceId)
            .collection('cryDetections')
            .get();

        expect(docs.docs, hasLength(1));
        expect(docs.docs.first.data()['type'], equals('classification'));
        expect(docs.docs.first.data()['classification'], equals('hungry'));
        expect(docs.docs.first.data()['confidence'], equals(0.88));
      });
    });

    group('Firestore fallback — simulateCryEnded', () {
      test('creates cry_ended document', () async {
        await bridgeService.simulateCryEnded(deviceId: deviceId);

        final docs = await fakeFirestore
            .collection('devices')
            .doc(deviceId)
            .collection('cryDetections')
            .get();

        expect(docs.docs, hasLength(1));
        expect(docs.docs.first.data()['type'], equals('cry_ended'));
        expect(docs.docs.first.data()['processed'], isFalse);
      });
    });

    group('Firestore fallback — listener management', () {
      test('startListening and stopListening work without errors', () {
        bridgeService.startListening(deviceId: deviceId, babyId: babyId);
        bridgeService.stopListening(deviceId);
      });

      test('startFirestoreFallback avoids duplicate subscriptions', () {
        bridgeService.startFirestoreFallback(
          deviceId: deviceId,
          babyId: babyId,
        );
        // Second call should be a no-op
        bridgeService.startFirestoreFallback(
          deviceId: deviceId,
          babyId: babyId,
        );

        // Should not throw
        bridgeService.stopListening(deviceId);
      });

      test('stopAll cancels all listeners', () {
        bridgeService.startListening(deviceId: 'pod-001', babyId: babyId);
        bridgeService.startListening(deviceId: 'pod-002', babyId: babyId);

        bridgeService.stopAll();
        // No error means success
      });
    });

    group('BLE UUIDs', () {
      test('service UUID is defined', () {
        expect(BabyTrackBleUuids.service.str,
            contains('1234'));
      });

      test('cry detection characteristic UUID is defined', () {
        expect(BabyTrackBleUuids.cryDetection.str,
            contains('1235'));
      });

      test('sensor data characteristic UUID is defined', () {
        expect(BabyTrackBleUuids.sensorData.str,
            contains('1236'));
      });

      test('device status characteristic UUID is defined', () {
        expect(BabyTrackBleUuids.deviceStatus.str,
            contains('1237'));
      });
    });

    group('Firestore fallback triggers alert pipeline', () {
      test('detection triggers Tier 1 alert via alert service', () async {
        final alerts = <CryAlert>[];
        final sub = alertService.alertStream.listen(alerts.add);

        // Start listening
        bridgeService.startFirestoreFallback(
          deviceId: deviceId,
          babyId: babyId,
        );

        // Simulate detection via Firestore
        await bridgeService.simulateDetection(
          deviceId: deviceId,
          babyId: babyId,
          intensity: 0.85,
        );

        // Wait for Firestore listener to fire
        await Future.delayed(const Duration(milliseconds: 200));

        expect(alerts, hasLength(1));
        expect(alerts.first.tier, equals(AlertTier.detection));
        expect(alerts.first.babyId, equals(babyId));

        await sub.cancel();
        bridgeService.stopListening(deviceId);
      });
    });
  });
}
