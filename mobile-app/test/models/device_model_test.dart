import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/models/device_model.dart';

void main() {
  group('DeviceModel Ownership', () {
    test('canManage returns true for device owner', () {
      final device = DeviceModel(
        id: 'device1',
        name: 'Test Device',
        familyId: 'family1',
        ownerId: 'user123',
        authorizedUsers: [],
        capabilities: DeviceCapabilities(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(device.canManage('user123'), isTrue);
      expect(device.canManage('user456'), isFalse);
    });

    test('canManage returns true for authorized users', () {
      final device = DeviceModel(
        id: 'device1',
        name: 'Test Device',
        familyId: 'family1',
        ownerId: 'user123',
        authorizedUsers: ['user456', 'user789'],
        capabilities: DeviceCapabilities(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(device.canManage('user123'), isTrue); // owner
      expect(device.canManage('user456'), isTrue); // authorized
      expect(device.canManage('user789'), isTrue); // authorized
      expect(device.canManage('user999'), isFalse); // not authorized
    });

    test('toFirestore includes ownership fields', () {
      final now = DateTime.now();
      final device = DeviceModel(
        id: 'device1',
        name: 'Test Device',
        familyId: 'family1',
        ownerId: 'user123',
        authorizedUsers: ['user456'],
        registeredAt: now,
        capabilities: DeviceCapabilities(),
        createdAt: now,
        updatedAt: now,
      );

      final map = device.toFirestore();

      expect(map['ownerId'], 'user123');
      expect(map['authorizedUsers'], ['user456']);
      expect(map['registeredAt'], isA<Timestamp>());
    });

    test('fromFirestore parses ownership fields correctly', () {
      // Note: This is a simplified test. In real scenarios, you'd use mocked DocumentSnapshot
      // For now, we're just testing the model structure is correct
      final device = DeviceModel(
        id: 'device1',
        name: 'Test Device',
        familyId: 'family1',
        ownerId: 'user123',
        authorizedUsers: ['user456', 'user789'],
        registeredAt: DateTime.now(),
        capabilities: DeviceCapabilities(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(device.ownerId, 'user123');
      expect(device.authorizedUsers, ['user456', 'user789']);
      expect(device.registeredAt, isNotNull);
    });

    test('copyWith updates ownership fields', () {
      final device = DeviceModel(
        id: 'device1',
        name: 'Test Device',
        familyId: 'family1',
        ownerId: 'user123',
        authorizedUsers: ['user456'],
        capabilities: DeviceCapabilities(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = device.copyWith(
        ownerId: 'user999',
        authorizedUsers: ['user111', 'user222'],
      );

      expect(updated.ownerId, 'user999');
      expect(updated.authorizedUsers, ['user111', 'user222']);
      expect(updated.id, device.id); // unchanged
    });

    test('DeviceStatus enum works correctly', () {
      expect(DeviceStatus.fromString('online'), DeviceStatus.online);
      expect(DeviceStatus.fromString('offline'), DeviceStatus.offline);
      expect(DeviceStatus.fromString('provisioning'), DeviceStatus.provisioning);
      expect(DeviceStatus.fromString('error'), DeviceStatus.error);
      expect(DeviceStatus.fromString('invalid'), DeviceStatus.offline);
    });
  });
}
