import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_model.dart';

/// Service for checking user permissions across the app
/// Handles role-based access control for babies, devices, and families
class PermissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has permission to access a baby's data
  Future<bool> canAccessBaby(String userId, String babyId) async {
    try {
      // Get baby's familyId
      final babyDoc = await _firestore.collection('babies').doc(babyId).get();

      if (!babyDoc.exists) return false;

      final familyId = babyDoc.data()?['familyId'];
      if (familyId == null) return false;

      // Check if user is family member
      return await isFamilyMember(userId, familyId);
    } catch (e) {
      print('[PermissionService] Error checking baby access: $e');
      return false;
    }
  }

  /// Check if user can manage a specific device
  /// Returns true if user is device owner, in authorized users list, or has canManageDevices role
  Future<bool> canManageDevice(String userId, String deviceId) async {
    try {
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();

      if (!deviceDoc.exists) return false;

      final data = deviceDoc.data()!;

      // Device owner always has access
      if (data['ownerId'] == userId) return true;

      // Check authorized users list
      final authorizedUsers = List<String>.from(data['authorizedUsers'] ?? []);
      if (authorizedUsers.contains(userId)) return true;

      // Check family role
      final familyId = data['familyId'];
      if (familyId == null) return false;

      final role = await getUserRoleInFamily(userId, familyId);
      return role?.canManageDevices ?? false;
    } catch (e) {
      print('[PermissionService] Error checking device management permission: $e');
      return false;
    }
  }

  /// Check if user can edit baby data (add photos, update info, etc.)
  Future<bool> canEditBaby(String userId, String babyId) async {
    try {
      final babyDoc = await _firestore.collection('babies').doc(babyId).get();

      if (!babyDoc.exists) return false;

      final familyId = babyDoc.data()?['familyId'];
      if (familyId == null) return false;

      final role = await getUserRoleInFamily(userId, familyId);
      return role?.canEdit ?? false;
    } catch (e) {
      print('[PermissionService] Error checking baby edit permission: $e');
      return false;
    }
  }

  /// Get user's role in a specific family
  Future<FamilyRole?> getUserRoleInFamily(String userId, String familyId) async {
    try {
      final familyDoc = await _firestore.collection('families').doc(familyId).get();

      if (!familyDoc.exists) return null;

      final members = familyDoc.data()?['members'] as List<dynamic>?;
      if (members == null) return null;

      // Find member with matching userId
      final memberData = members.firstWhere(
        (m) => m['userId'] == userId,
        orElse: () => null,
      );

      if (memberData == null) return null;

      return FamilyRole.fromString(memberData['role']);
    } catch (e) {
      print('[PermissionService] Error getting user role: $e');
      return null;
    }
  }

  /// Check if user is a member of a family
  Future<bool> isFamilyMember(String userId, String familyId) async {
    final role = await getUserRoleInFamily(userId, familyId);
    return role != null;
  }

  /// Check if user can invite members to a family
  Future<bool> canInviteMembers(String userId, String familyId) async {
    final role = await getUserRoleInFamily(userId, familyId);
    return role?.canInviteMembers ?? false;
  }

  /// Check if user can manage roles in a family
  Future<bool> canManageRoles(String userId, String familyId) async {
    final role = await getUserRoleInFamily(userId, familyId);
    return role?.canManageRoles ?? false;
  }

  /// Check if user is a system admin
  Future<bool> isSystemAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return false;

      final role = userDoc.data()?['role'];
      return role == 'admin';
    } catch (e) {
      print('[PermissionService] Error checking system admin: $e');
      return false;
    }
  }

  /// Add a user to device's authorized users list
  Future<void> addAuthorizedUser(String deviceId, String userId) async {
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'authorizedUsers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('[PermissionService] Error adding authorized user: $e');
      rethrow;
    }
  }

  /// Remove a user from device's authorized users list
  Future<void> removeAuthorizedUser(String deviceId, String userId) async {
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'authorizedUsers': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print('[PermissionService] Error removing authorized user: $e');
      rethrow;
    }
  }
}
