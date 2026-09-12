import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/family_model.dart';

void main() {
  group('FamilyRole Permissions', () {
    test('Owner has all permissions', () {
      const role = FamilyRole.owner;

      expect(role.canEdit, isTrue);
      expect(role.canManageDevices, isTrue);
      expect(role.canInviteMembers, isTrue);
      expect(role.canViewSensitiveData, isTrue);
      expect(role.canDeleteData, isTrue);
      expect(role.canManageRoles, isTrue);
      expect(role.isSystemAdmin, isFalse);
    });

    test('Parent has edit and device management permissions', () {
      const role = FamilyRole.parent;

      expect(role.canEdit, isTrue);
      expect(role.canManageDevices, isTrue);
      expect(role.canInviteMembers, isFalse);
      expect(role.canViewSensitiveData, isTrue);
      expect(role.canDeleteData, isFalse);
      expect(role.canManageRoles, isFalse);
      expect(role.isSystemAdmin, isFalse);
    });

    test('Caregiver has limited permissions', () {
      const role = FamilyRole.caregiver;

      expect(role.canEdit, isFalse);
      expect(role.canManageDevices, isFalse);
      expect(role.canInviteMembers, isFalse);
      expect(role.canViewSensitiveData, isTrue);
      expect(role.canDeleteData, isFalse);
      expect(role.canManageRoles, isFalse);
      expect(role.isSystemAdmin, isFalse);
    });

    test('Viewer has minimal permissions', () {
      const role = FamilyRole.viewer;

      expect(role.canEdit, isFalse);
      expect(role.canManageDevices, isFalse);
      expect(role.canInviteMembers, isFalse);
      expect(role.canViewSensitiveData, isFalse);
      expect(role.canDeleteData, isFalse);
      expect(role.canManageRoles, isFalse);
      expect(role.isSystemAdmin, isFalse);
    });

    test('Admin has all permissions including system admin', () {
      const role = FamilyRole.admin;

      expect(role.canEdit, isTrue);
      expect(role.canManageDevices, isTrue);
      expect(role.canInviteMembers, isTrue);
      expect(role.canViewSensitiveData, isTrue);
      expect(role.canDeleteData, isTrue);
      expect(role.canManageRoles, isTrue);
      expect(role.isSystemAdmin, isTrue);
      expect(role.canAccessAllFamilies, isTrue);
      expect(role.canModifyBilling, isTrue);
    });

    test('FamilyRole.fromString handles valid roles', () {
      expect(FamilyRole.fromString('owner'), FamilyRole.owner);
      expect(FamilyRole.fromString('parent'), FamilyRole.parent);
      expect(FamilyRole.fromString('caregiver'), FamilyRole.caregiver);
      expect(FamilyRole.fromString('viewer'), FamilyRole.viewer);
      expect(FamilyRole.fromString('admin'), FamilyRole.admin);
    });

    test('FamilyRole.fromString defaults to viewer for invalid input', () {
      expect(FamilyRole.fromString('invalid'), FamilyRole.viewer);
      expect(FamilyRole.fromString(null), FamilyRole.viewer);
      expect(FamilyRole.fromString(''), FamilyRole.viewer);
    });
  });
}
