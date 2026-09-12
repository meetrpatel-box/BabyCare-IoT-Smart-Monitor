import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/mqtt_feature_upload_service.dart';

void main() {
  late MqttFeatureUploadService service;
  late FakeFirebaseFirestore fakeFirestore;

  const babyId = 'test-baby-1';
  const eventId = 'event-001';
  const deviceId = 'pod-001';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = MqttFeatureUploadService(firestore: fakeFirestore);
  });

  tearDown(() {
    service.dispose();
  });

  group('MqttFeatureUploadService', () {
    group('initial state', () {
      test('starts in disconnected state', () {
        expect(service.connectionState, equals(MqttServiceConnectionState.disconnected));
        expect(service.isConnected, isFalse);
      });
    });

    group('connectionStateStream', () {
      test('emits state changes', () async {
        final states = <MqttServiceConnectionState>[];
        final sub = service.connectionStateStream.listen(states.add);

        // Attempt to connect without a broker — will fail and emit states
        await service.connect(
          brokerHost: 'nonexistent.example.com',
          port: 1883,
          clientId: 'test-client',
        );

        // Give time for state changes
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have emitted at least connecting state
        expect(states, isNotEmpty);
        expect(states.first, equals(MqttServiceConnectionState.connecting));

        await sub.cancel();
      });
    });

    group('Firestore fallback — uploadInlineFeatures', () {
      test('writes features to cry event document', () async {
        // Create the event doc first
        await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .set({
          'babyId': babyId,
          'startTime': DateTime.now().toIso8601String(),
          'hasAudioFeatures': false,
        });

        final features = MqttFeatureUploadService.generateMockFeatures();

        await service.uploadInlineFeatures(
          babyId: babyId,
          eventId: eventId,
          features: features,
        );

        // Verify the document was updated
        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()?['hasAudioFeatures'], isTrue);
        expect(doc.data()?['audioFeatures'], isNotNull);
        expect(doc.data()?['audioFeatures']['mfcc'], isNotNull);
        expect(doc.data()?['audioFeatures']['melSpectrogram'], isNotNull);
      });
    });

    group('Firestore fallback — uploadFeatures', () {
      test('falls back to Firestore when MQTT is disconnected', () async {
        // Create the event doc first
        await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .set({
          'babyId': babyId,
          'hasAudioFeatures': false,
        });

        final features = MqttFeatureUploadService.generateMockFeatures();

        // Since we're not connected, it should fall back to Firestore
        final usedMqtt = await service.uploadFeatures(
          deviceId: deviceId,
          babyId: babyId,
          eventId: eventId,
          features: features,
        );

        expect(usedMqtt, isFalse); // Used Firestore fallback

        // Verify Firestore was updated
        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()?['hasAudioFeatures'], isTrue);
        expect(doc.data()?['audioFeatures'], isNotNull);
      });

      test('includes sensorContext in Firestore fallback', () async {
        await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .set({'babyId': babyId, 'hasAudioFeatures': false});

        final features = MqttFeatureUploadService.generateMockFeatures();
        final sensorContext = {
          'heartRate': 120,
          'bodyTemp': 36.8,
          'lastFeedMinutesAgo': 45,
        };

        await service.uploadFeatures(
          deviceId: deviceId,
          babyId: babyId,
          eventId: eventId,
          features: features,
          sensorContext: sensorContext,
        );

        final doc = await fakeFirestore
            .collection('babies')
            .doc(babyId)
            .collection('cryEvents')
            .doc(eventId)
            .get();

        expect(doc.data()?['sensorContext'], isNotNull);
        expect(doc.data()?['sensorContext']['heartRate'], equals(120));
      });
    });

    group('uploadToQueue', () {
      test('creates a queue document', () async {
        final features = MqttFeatureUploadService.generateMockFeatures();

        final queueId = await service.uploadToQueue(
          deviceId: deviceId,
          babyId: babyId,
          eventId: eventId,
          features: features,
        );

        expect(queueId, isNotEmpty);

        final doc = await fakeFirestore
            .collection('featureUploadQueue')
            .doc(queueId)
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()?['deviceId'], equals(deviceId));
        expect(doc.data()?['babyId'], equals(babyId));
        expect(doc.data()?['eventId'], equals(eventId));
        expect(doc.data()?['status'], equals('pending'));
        expect(doc.data()?['transportUsed'], equals('firestore'));
      });

      test('includes sensorContext when provided', () async {
        final features = MqttFeatureUploadService.generateMockFeatures();

        final queueId = await service.uploadToQueue(
          deviceId: deviceId,
          babyId: babyId,
          eventId: eventId,
          features: features,
          sensorContext: {'bodyTemp': 37.0},
        );

        final doc = await fakeFirestore
            .collection('featureUploadQueue')
            .doc(queueId)
            .get();

        expect(doc.data()?['sensorContext'], isNotNull);
        expect(doc.data()?['sensorContext']['bodyTemp'], equals(37.0));
      });
    });

    group('getUploadStatus', () {
      test('returns status of a queued item', () async {
        final docRef = await fakeFirestore.collection('featureUploadQueue').add({
          'status': 'processing',
        });

        final status = await service.getUploadStatus(docRef.id);
        expect(status, equals('processing'));
      });

      test('returns not_found for missing queue item', () async {
        final status = await service.getUploadStatus('nonexistent-id');
        expect(status, equals('not_found'));
      });
    });

    group('generateMockFeatures', () {
      test('generates valid feature structure', () {
        final features = MqttFeatureUploadService.generateMockFeatures();

        expect(features['mfcc'], isNotNull);
        expect(features['melSpectrogram'], isNotNull);
        expect(features['rmsEnergy'], isNotNull);
        expect(features['zeroCrossingRate'], isNotNull);
        expect(features['spectralCentroid'], isNotNull);
        expect(features['f0'], isNotNull);
        expect(features['durationSeconds'], equals(5.0));
        expect(features['sampleRate'], equals(16000));
      });

      test('generates correct dimensions', () {
        final features = MqttFeatureUploadService.generateMockFeatures(
          numFrames: 100,
        );

        final mfcc = features['mfcc'] as List;
        expect(mfcc, hasLength(100));
        expect((mfcc[0] as List), hasLength(13)); // 13 MFCC coefficients

        final mel = features['melSpectrogram'] as List;
        expect(mel, hasLength(100));
        expect((mel[0] as List), hasLength(64)); // 64 mel bands

        expect((features['rmsEnergy'] as List), hasLength(100));
        expect((features['f0'] as List), hasLength(100));
      });

      test('generates custom duration and sample rate', () {
        final features = MqttFeatureUploadService.generateMockFeatures(
          durationSeconds: 10.0,
          sampleRate: 22050,
        );

        expect(features['durationSeconds'], equals(10.0));
        expect(features['sampleRate'], equals(22050));
      });
    });

    group('device commands when disconnected', () {
      test('sendDeviceCommand returns false when not connected', () async {
        final sent = await service.sendDeviceCommand(
          deviceId: deviceId,
          command: 'startRecording',
        );

        expect(sent, isFalse);
      });

      test('uploadRawAudio returns false when not connected', () async {
        final sent = await service.uploadRawAudio(
          deviceId: deviceId,
          babyId: babyId,
          eventId: eventId,
          audioData: Uint8List.fromList([1, 2, 3, 4]),
        );

        expect(sent, isFalse);
      });
    });

    group('subscription management', () {
      test('can subscribe and unsubscribe without errors when disconnected', () {
        // Should not throw even when not connected
        service.subscribeToDevice(deviceId, (topic, payload) {});
        service.unsubscribeFromDevice(deviceId);
      });
    });
  });
}
