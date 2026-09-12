import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../lib/services/permission_service.dart';
import '../../lib/models/family_model.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PermissionService permissionService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    permissionService = PermissionService(firestore: fakeFirestore);
  });

  group('Device Permission Checks', () {
    test('Owner can manage their device', () async {
      const ownerId = 'owner-123';
      const deviceId = 'device-456';

      // Create device with owner
      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId],
        'familyId': 'family-789',
      });

      final canManage = await permissionService.canManageDevice(ownerId, deviceId);

      expect(canManage, true);
    });

    test('Authorized user can manage device', () async {
      const ownerId = 'owner-123';
      const authorizedUserId = 'user-456';
      const deviceId = 'device-789';

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId, authorizedUserId],
        'familyId': 'family-789',
      });

      final canManage = await permissionService.canManageDevice(authorizedUserId, deviceId);

      expect(canManage, true);
    });

    test('Unauthorized user cannot manage device', () async {
      const ownerId = 'owner-123';
      const unauthorizedUserId = 'stranger-456';
      const deviceId = 'device-789';

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId],
        'familyId': 'family-789',
      });

      final canManage = await permissionService.canManageDevice(unauthorizedUserId, deviceId);

      expect(canManage, false);
    });

    test('Family admin can manage any family device', () async {
      const adminId = 'admin-123';
      const ownerId = 'owner-456';
      const deviceId = 'device-789';
      const familyId = 'family-123';

      // Create family with admin
      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': ownerId,
        'members': [
          {'userId': ownerId, 'role': 'owner'},
          {'userId': adminId, 'role': 'admin'},
        ],
      });

      // Create device
      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId],
        'familyId': familyId,
      });

      final canManage = await permissionService.canManageDevice(adminId, deviceId);

      expect(canManage, true);
    });

    test('Family owner can manage any family device', () async {
      const ownerId = 'owner-123';
      const deviceOwnerId = 'device-owner-456';
      const deviceId = 'device-789';
      const familyId = 'family-123';

      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': ownerId,
        'members': [
          {'userId': ownerId, 'role': 'owner'},
          {'userId': deviceOwnerId, 'role': 'parent'},
        ],
      });

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': deviceOwnerId,
        'authorizedUsers': [deviceOwnerId],
        'familyId': familyId,
      });

      final canManage = await permissionService.canManageDevice(ownerId, deviceId);

      expect(canManage, true);
    });
  });

  group('Baby Access Permissions', () {
    test('Family member can access baby', () async {
      const userId = 'user-123';
      const babyId = 'baby-456';
      const familyId = 'family-789';

      // Create family
      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': 'owner-123',
        'members': [
          {'userId': 'owner-123', 'role': 'owner'},
          {'userId': userId, 'role': 'parent'},
        ],
      });

      // Create baby
      await fakeFirestore.collection('babies').doc(babyId).set({
        'name': 'Test Baby',
        'familyId': familyId,
      });

      final canAccess = await permissionService.canAccessBaby(userId, babyId);

      expect(canAccess, true);
    });

    test('Non-family member cannot access baby', () async {
      const strangerId = 'stranger-123';
      const babyId = 'baby-456';
      const familyId = 'family-789';

      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': 'owner-123',
        'members': [
          {'userId': 'owner-123', 'role': 'owner'},
        ],
      });

      await fakeFirestore.collection('babies').doc(babyId).set({
        'name': 'Test Baby',
        'familyId': familyId,
      });

      final canAccess = await permissionService.canAccessBaby(strangerId, babyId);

      expect(canAccess, false);
    });
  });

  group('Role-Based Permissions', () {
    test('Viewer cannot access sensitive data', () {
      final viewerRole = FamilyRole.viewer;

      expect(viewerRole.canViewSensitiveData, false);
      expect(viewerRole.canManageDevices, false);
      expect(viewerRole.canDeleteData, false);
    });

    test('Caregiver can access sensitive data but not delete', () {
      final caregiverRole = FamilyRole.caregiver;

      expect(caregiverRole.canViewSensitiveData, true);
      expect(caregiverRole.canManageDevices, true);
      expect(caregiverRole.canDeleteData, false);
    });

    test('Parent has full access except role management', () {
      final parentRole = FamilyRole.parent;

      expect(parentRole.canViewSensitiveData, true);
      expect(parentRole.canManageDevices, true);
      expect(parentRole.canAddMembers, true);
      expect(parentRole.canManageRoles, false);
    });

    test('Owner has all family permissions', () {
      final ownerRole = FamilyRole.owner;

      expect(ownerRole.canViewSensitiveData, true);
      expect(ownerRole.canManageDevices, true);
      expect(ownerRole.canAddMembers, true);
      expect(ownerRole.canManageRoles, true);
      expect(ownerRole.canDeleteData, true);
    });

    test('Admin has system-wide permissions', () {
      final adminRole = FamilyRole.admin;

      expect(adminRole.isSystemAdmin, true);
      expect(adminRole.canAccessAllFamilies, true);
      expect(adminRole.canModifyBilling, true);
      expect(adminRole.canManageRoles, true);
    });
  });

  group('User Role Lookup', () {
    test('Returns correct role for family member', () async {
      const userId = 'user-123';
      const familyId = 'family-456';

      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': 'owner-123',
        'members': [
          {'userId': 'owner-123', 'role': 'owner'},
          {'userId': userId, 'role': 'caregiver'},
        ],
      });

      final role = await permissionService.getUserRoleInFamily(userId, familyId);

      expect(role, FamilyRole.caregiver);
    });

    test('Returns null for non-family member', () async {
      const strangerId = 'stranger-123';
      const familyId = 'family-456';

      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': 'owner-123',
        'members': [
          {'userId': 'owner-123', 'role': 'owner'},
        ],
      });

      final role = await permissionService.getUserRoleInFamily(strangerId, familyId);

      expect(role, isNull);
    });
  });

  group('Authorization Management', () {
    test('Owner can add authorized user to device', () async {
      const ownerId = 'owner-123';
      const newUserId = 'user-456';
      const deviceId = 'device-789';

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId],
        'familyId': 'family-123',
      });

      await permissionService.addAuthorizedUser(deviceId, newUserId);

      final deviceDoc = await fakeFirestore.collection('devices').doc(deviceId).get();
      final authorizedUsers = deviceDoc.data()?['authorizedUsers'] as List;

      expect(authorizedUsers, contains(newUserId));
      expect(authorizedUsers.length, 2);
    });

    test('Can remove authorized user from device', () async {
      const ownerId = 'owner-123';
      const userToRemove = 'user-456';
      const deviceId = 'device-789';

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId, userToRemove],
        'familyId': 'family-123',
      });

      await permissionService.removeAuthorizedUser(deviceId, userToRemove);

      final deviceDoc = await fakeFirestore.collection('devices').doc(deviceId).get();
      final authorizedUsers = deviceDoc.data()?['authorizedUsers'] as List;

      expect(authorizedUsers, isNot(contains(userToRemove)));
      expect(authorizedUsers.length, 1);
    });

    test('Cannot remove device owner from authorized users', () async {
      const ownerId = 'owner-123';
      const deviceId = 'device-789';

      await fakeFirestore.collection('devices').doc(deviceId).set({
        'name': 'Test Device',
        'ownerId': ownerId,
        'authorizedUsers': [ownerId],
        'familyId': 'family-123',
      });

      expect(
        () => permissionService.removeAuthorizedUser(deviceId, ownerId),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Multi-Device Permission Scenarios', () {
    test('User can manage only their assigned devices', () async {
      const user1 = 'user-1';
      const user2 = 'user-2';
      const familyId = 'family-123';

      // Create family with both users
      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': user1,
        'members': [
          {'userId': user1, 'role': 'parent'},
          {'userId': user2, 'role': 'parent'},
        ],
      });

      // Create device 1 (user 1's device)
      await fakeFirestore.collection('devices').doc('device-1').set({
        'name': 'Device 1',
        'ownerId': user1,
        'authorizedUsers': [user1],
        'familyId': familyId,
      });

      // Create device 2 (user 2's device)
      await fakeFirestore.collection('devices').doc('device-2').set({
        'name': 'Device 2',
        'ownerId': user2,
        'authorizedUsers': [user2],
        'familyId': familyId,
      });

      // User 1 can manage device 1
      expect(await permissionService.canManageDevice(user1, 'device-1'), true);

      // User 1 CANNOT manage device 2 (different owner, not authorized)
      expect(await permissionService.canManageDevice(user1, 'device-2'), false);

      // User 2 can manage device 2
      expect(await permissionService.canManageDevice(user2, 'device-2'), true);

      // User 2 CANNOT manage device 1
      expect(await permissionService.canManageDevice(user2, 'device-1'), false);
    });

    test('Family owner can manage all devices in family', () async {
      const ownerId = 'owner-123';
      const user1 = 'user-1';
      const user2 = 'user-2';
      const familyId = 'family-123';

      await fakeFirestore.collection('families').doc(familyId).set({
        'name': 'Test Family',
        'ownerId': ownerId,
        'members': [
          {'userId': ownerId, 'role': 'owner'},
          {'userId': user1, 'role': 'parent'},
          {'userId': user2, 'role': 'parent'},
        ],
      });

      // Create multiple devices
      await fakeFirestore.collection('devices').doc('device-1').set({
        'name': 'Device 1',
        'ownerId': user1,
        'authorizedUsers': [user1],
        'familyId': familyId,
      });

      await fakeFirestore.collection('devices').doc('device-2').set({
        'name': 'Device 2',
        'ownerId': user2,
        'authorizedUsers': [user2],
        'familyId': familyId,
      });

      // Family owner can manage ALL devices
      expect(await permissionService.canManageDevice(ownerId, 'device-1'), true);
      expect(await permissionService.canManageDevice(ownerId, 'device-2'), true);
    });
  });
}
