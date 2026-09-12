import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:baby_track_flutter/models/device_model.dart';
import '../../fixtures/device_fixtures.dart';

void main() {
  group('DeviceModel', () {
    group('fromFirestore', () {
      test('creates DeviceModel from complete Firestore data', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.onlineDeviceId)
            .set(DeviceFixtures.onlineDeviceData);

        // Act
        final doc = await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.onlineDeviceId)
            .get();
        final device = DeviceModel.fromFirestore(doc);

        // Assert
        expect(device.id, DeviceFixtures.onlineDeviceId);
        expect(device.familyId, 'family_456');
        expect(device.assignedBabyId, 'baby_healthy_001');
        expect(device.firmwareVersion, '1.2.0');
        expect(device.batteryLevel, 85);
      });

      test('creates DeviceModel with offline status', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.offlineDeviceId)
            .set(DeviceFixtures.offlineDeviceData);

        // Act
        final doc = await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.offlineDeviceId)
            .get();
        final device = DeviceModel.fromFirestore(doc);

        // Assert
        expect(device.status, DeviceStatus.offline);
        expect(device.isOnline, false);
        expect(device.batteryLevel, 15);
      });

      test('creates DeviceModel in provisioning state', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.provisioningDeviceId)
            .set(DeviceFixtures.provisioningDeviceData);

        // Act
        final doc = await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.provisioningDeviceId)
            .get();
        final device = DeviceModel.fromFirestore(doc);

        // Assert
        expect(device.status, DeviceStatus.provisioning);
        expect(device.isOnline, false);
      });

      test('parses capabilities correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.onlineDeviceId)
            .set(DeviceFixtures.onlineDeviceData);

        // Act
        final doc = await fakeFirestore
            .collection('devices')
            .doc(DeviceFixtures.onlineDeviceId)
            .get();
        final device = DeviceModel.fromFirestore(doc);

        // Assert
        expect(device.capabilities, isNotNull);
        expect(device.capabilities.hasVitalSensors, true);
      });
    });

    group('toFirestore', () {
      test('converts DeviceModel to Firestore format', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          assignedBabyId: 'baby_789',
          status: DeviceStatus.online,
          capabilities: DeviceCapabilities(hasVitalSensors: true),
          firmwareVersion: '1.0.0',
          batteryLevel: 100,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 6, 15),
        );

        // Act
        final data = device.toFirestore();

        // Assert
        expect(data['name'], 'Test Pod');
        expect(data['familyId'], 'family_456');
        expect(data['assignedBabyId'], 'baby_789');
        expect(data['status'], 'online');
        expect(data['firmwareVersion'], '1.0.0');
        expect(data['batteryLevel'], 100);
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());
      });

      test('includes capabilities in Firestore format', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          capabilities: DeviceCapabilities(
            hasCamera: true,
            hasMicrophone: true,
            hasVitalSensors: true,
          ),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 6, 15),
        );

        // Act
        final data = device.toFirestore();

        // Assert
        expect(data['capabilities'], isNotNull);
        expect(data['capabilities']['hasCamera'], true);
        expect(data['capabilities']['hasMicrophone'], true);
        expect(data['capabilities']['hasVitalSensors'], true);
      });
    });

    group('isOnline', () {
      test('returns true when status is online', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          status: DeviceStatus.online,
          capabilities: DeviceCapabilities(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(device.isOnline, true);
      });

      test('returns false when status is offline', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          status: DeviceStatus.offline,
          capabilities: DeviceCapabilities(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(device.isOnline, false);
      });

      test('returns false when status is provisioning', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          status: DeviceStatus.provisioning,
          capabilities: DeviceCapabilities(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(device.isOnline, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated status', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          status: DeviceStatus.offline,
          capabilities: DeviceCapabilities(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final updatedDevice = device.copyWith(status: DeviceStatus.online);

        // Assert
        expect(updatedDevice.status, DeviceStatus.online);
        expect(updatedDevice.id, device.id);
        expect(updatedDevice.name, device.name);
      });

      test('creates copy with updated battery level', () {
        // Arrange
        final device = DeviceModel(
          id: 'device_123',
          name: 'Test Pod',
          familyId: 'family_456',
          batteryLevel: 100,
          capabilities: DeviceCapabilities(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final updatedDevice = device.copyWith(batteryLevel: 50);

        // Assert
        expect(updatedDevice.batteryLevel, 50);
      });
    });
  });

  group('DeviceStatus', () {
    test('fromString returns correct enum value', () {
      expect(DeviceStatus.fromString('online'), DeviceStatus.online);
      expect(DeviceStatus.fromString('offline'), DeviceStatus.offline);
      expect(
          DeviceStatus.fromString('provisioning'), DeviceStatus.provisioning);
      expect(DeviceStatus.fromString('error'), DeviceStatus.error);
    });

    test('fromString returns offline for invalid value', () {
      expect(DeviceStatus.fromString('InvalidValue'), DeviceStatus.offline);
      expect(DeviceStatus.fromString(null), DeviceStatus.offline);
    });
  });

  group('DeviceCapabilities', () {
    group('fromMap', () {
      test('creates DeviceCapabilities from valid map', () {
        // Act
        final capabilities = DeviceCapabilities.fromMap(
          DeviceFixtures.defaultCapabilities,
        );

        // Assert
        expect(capabilities.hasVitalSensors, true);
        expect(capabilities.hasMicrophone, true);
      });

      test('handles empty map with defaults', () {
        // Act
        final capabilities = DeviceCapabilities.fromMap({});

        // Assert
        expect(capabilities.hasCamera, false);
        expect(capabilities.hasMicrophone, false);
        expect(capabilities.hasSpeaker, false);
        expect(capabilities.hasVitalSensors, true); // Default true
        expect(capabilities.supportsVideo, false);
        expect(capabilities.supportsAudio, false);
      });
    });

    group('toMap', () {
      test('converts DeviceCapabilities to map', () {
        // Arrange
        final capabilities = DeviceCapabilities(
          hasCamera: true,
          hasMicrophone: true,
          hasSpeaker: true,
          hasVitalSensors: true,
          supportsVideo: true,
          supportsAudio: true,
        );

        // Act
        final map = capabilities.toMap();

        // Assert
        expect(map['hasCamera'], true);
        expect(map['hasMicrophone'], true);
        expect(map['hasSpeaker'], true);
        expect(map['hasVitalSensors'], true);
        expect(map['supportsVideo'], true);
        expect(map['supportsAudio'], true);
      });
    });
  });
}
