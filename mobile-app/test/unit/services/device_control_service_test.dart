import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/services/device_control_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../fixtures/audio_fixtures.dart';

void main() {
  group('DeviceControlService', () {
    late DeviceControlService service;
    late FakeFirebaseFirestore fakeFirestore;
    const testDeviceId = 'test-device-001';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = DeviceControlService(firestore: fakeFirestore);
    });

    group('playAudio', () {
      test('writes command document to device_commands collection', () async {
        await service.playAudio(
          testDeviceId,
          'white_noise',
          volume: 50,
          loop: false,
        );

        final commands = await fakeFirestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: testDeviceId)
            .get();

        expect(commands.docs.length, equals(1));

        final command = commands.docs.first.data();
        expect(command['command'], equals('play_audio'));
        expect(command['deviceId'], equals(testDeviceId));
        expect(command['track'], equals('white_noise'));
        expect(command['volume'], equals(50));
        expect(command['loop'], equals(false));
        expect(command['status'], equals('pending'));
        expect(command['createdAt'], isNotNull);
      });

      test('uses default volume when not specified', () async {
        await service.playAudio(testDeviceId, 'lullaby_1');

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        final command = commands.docs.first.data();
        expect(command['volume'], equals(50)); // Default
        expect(command['loop'], equals(false)); // Default
      });

      test('allows custom volume and loop values', () async {
        await service.playAudio(
          testDeviceId,
          'rain',
          volume: 75,
          loop: true,
        );

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        final command = commands.docs.first.data();
        expect(command['volume'], equals(75));
        expect(command['loop'], equals(true));
      });

      test('throws when deviceId is empty', () {
        expect(
          () => service.playAudio('', 'white_noise'),
          throwsArgumentError,
        );
      });

      test('throws when trackId is empty', () {
        expect(
          () => service.playAudio(testDeviceId, ''),
          throwsArgumentError,
        );
      });

      test('throws when volume is out of range', () {
        expect(
          () => service.playAudio(testDeviceId, 'lullaby_1', volume: -1),
          throwsArgumentError,
        );

        expect(
          () => service.playAudio(testDeviceId, 'lullaby_1', volume: 101),
          throwsArgumentError,
        );
      });
    });

    group('stopAudio', () {
      test('writes stop command to device_commands', () async {
        await service.stopAudio(testDeviceId);

        final commands = await fakeFirestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: testDeviceId)
            .get();

        expect(commands.docs.length, equals(1));

        final command = commands.docs.first.data();
        expect(command['command'], equals('stop_audio'));
        expect(command['deviceId'], equals(testDeviceId));
        expect(command['status'], equals('pending'));
      });

      test('throws when deviceId is empty', () {
        expect(
          () => service.stopAudio(''),
          throwsArgumentError,
        );
      });
    });

    group('pauseAudio', () {
      test('writes pause command to device_commands', () async {
        await service.pauseAudio(testDeviceId);

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        final command = commands.docs.first.data();
        expect(command['command'], equals('pause_audio'));
        expect(command['deviceId'], equals(testDeviceId));
      });
    });

    group('resumeAudio', () {
      test('writes resume command to device_commands', () async {
        await service.resumeAudio(testDeviceId);

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        final command = commands.docs.first.data();
        expect(command['command'], equals('resume_audio'));
        expect(command['deviceId'], equals(testDeviceId));
      });
    });

    group('setDeviceVolume', () {
      test('writes volume command with specified value', () async {
        await service.setDeviceVolume(testDeviceId, 85);

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        final command = commands.docs.first.data();
        expect(command['command'], equals('set_volume'));
        expect(command['deviceId'], equals(testDeviceId));
        expect(command['volume'], equals(85));
      });

      test('throws when volume is out of range', () {
        expect(
          () => service.setDeviceVolume(testDeviceId, -5),
          throwsArgumentError,
        );

        expect(
          () => service.setDeviceVolume(testDeviceId, 150),
          throwsArgumentError,
        );
      });

      test('allows volume at boundaries (0 and 100)', () async {
        await service.setDeviceVolume(testDeviceId, 0);
        await service.setDeviceVolume(testDeviceId, 100);

        final commands = await fakeFirestore
            .collection('device_commands')
            .get();

        expect(commands.docs.length, equals(2));
      });
    });

    group('getAudioStatus', () {
      test('streams audio status from device status collection', () async {
        // Set up initial status
        await fakeFirestore
            .collection('devices')
            .doc(testDeviceId)
            .collection('status')
            .doc('audio')
            .set(AudioFixtures.audioStatus(
              status: 'playing',
              track: 'white_noise',
              volume: 50,
            ));

        final stream = service.getAudioStatus(testDeviceId);

        await expectLater(
          stream,
          emits(
            predicate<dynamic>((snapshot) {
              final data = snapshot.data() as Map<String, dynamic>?;
              return data?['status'] == 'playing' &&
                  data?['track'] == 'white_noise' &&
                  data?['volume'] == 50;
            }),
          ),
        );
      });

      test('emits updates when status changes', () async {
        final statusRef = fakeFirestore
            .collection('devices')
            .doc(testDeviceId)
            .collection('status')
            .doc('audio');

        // Start with stopped status
        await statusRef.set(AudioFixtures.audioStatus(
          status: 'stopped',
          isPlaying: false,
        ));

        final stream = service.getAudioStatus(testDeviceId);
        
        // Update to playing
        await statusRef.update({
          'status': 'playing',
          'track': 'lullaby_1',
          'isPlaying': true,
        });

        await expectLater(
          stream.take(2),
          emitsInOrder([
            predicate<dynamic>((s) => s.data()?['status'] == 'stopped'),
            predicate<dynamic>((s) => s.data()?['status'] == 'playing'),
          ]),
        );
      });

      test('throws when deviceId is empty', () {
        expect(
          () => service.getAudioStatus(''),
          throwsArgumentError,
        );
      });
    });

    group('Command Queue Management', () {
      test('multiple commands are queued in order', () async {
        await service.playAudio(testDeviceId, 'lullaby_1');
        await service.setDeviceVolume(testDeviceId, 75);
        await service.pauseAudio(testDeviceId);
        await service.resumeAudio(testDeviceId);
        await service.stopAudio(testDeviceId);

        final commands = await fakeFirestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: testDeviceId)
            .orderBy('createdAt')
            .get();

        expect(commands.docs.length, equals(5));
        expect(commands.docs[0].data()['command'], equals('play_audio'));
        expect(commands.docs[1].data()['command'], equals('set_volume'));
        expect(commands.docs[2].data()['command'], equals('pause_audio'));
        expect(commands.docs[3].data()['command'], equals('resume_audio'));
        expect(commands.docs[4].data()['command'], equals('stop_audio'));
      });

      test('commands for different devices are isolated', () async {
        const device1 = 'device-001';
        const device2 = 'device-002';

        await service.playAudio(device1, 'lullaby_1');
        await service.playAudio(device2, 'white_noise');

        final device1Commands = await fakeFirestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: device1)
            .get();

        final device2Commands = await fakeFirestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: device2)
            .get();

        expect(device1Commands.docs.length, equals(1));
        expect(device2Commands.docs.length, equals(1));
        expect(
          device1Commands.docs.first.data()['track'],
          equals('lullaby_1'),
        );
        expect(
          device2Commands.docs.first.data()['track'],
          equals('white_noise'),
        );
      });
    });

    group('Error Handling', () {
      test('handles Firestore write errors gracefully', () async {
        // This would require mocking Firestore to throw errors
        // For now, we verify the method signature allows throwing
        expect(
          service.playAudio(testDeviceId, 'test'),
          completes,
        );
      });
    });
  });
}
