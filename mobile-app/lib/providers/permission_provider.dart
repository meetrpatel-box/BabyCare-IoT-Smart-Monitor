import 'package:flutter/foundation.dart';
import '../services/permission_service.dart';
import '../models/family_model.dart';

/// Provider for managing permissions with caching
/// Wraps PermissionService and provides cached permission checks to avoid redundant queries
class PermissionProvider extends ChangeNotifier {
  final PermissionService _permissionService = PermissionService();

  // Cache permissions for performance (key format: "type_id_userId")
  final Map<String, bool> _permissionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Cache duration: 5 minutes
  static const _cacheDuration = Duration(minutes: 5);

  /// Check if user can access a baby's data (with caching)
  Future<bool> canAccessBaby(String userId, String babyId) async {
    final cacheKey = 'baby_${babyId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final hasPermission = await _permissionService.canAccessBaby(userId, babyId);
    _cachePermission(cacheKey, hasPermission);
    return hasPermission;
  }

  /// Check if user can manage a device (with caching)
  Future<bool> canManageDevice(String userId, String deviceId) async {
    final cacheKey = 'device_${deviceId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final hasPermission = await _permissionService.canManageDevice(userId, deviceId);
    _cachePermission(cacheKey, hasPermission);
    return hasPermission;
  }

  /// Check if user can edit a baby (with caching)
  Future<bool> canEditBaby(String userId, String babyId) async {
    final cacheKey = 'edit_baby_${babyId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final hasPermission = await _permissionService.canEditBaby(userId, babyId);
    _cachePermission(cacheKey, hasPermission);
    return hasPermission;
  }

  /// Get user's role in a family (with caching)
  Future<FamilyRole?> getUserRoleInFamily(String userId, String familyId) async {
    // Note: Roles are not cached as bool, so we call service directly
    // Could be enhanced with a separate role cache if needed
    return await _permissionService.getUserRoleInFamily(userId, familyId);
  }

  /// Check if user is a family member (with caching)
  Future<bool> isFamilyMember(String userId, String familyId) async {
    final cacheKey = 'member_${familyId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final isMember = await _permissionService.isFamilyMember(userId, familyId);
    _cachePermission(cacheKey, isMember);
    return isMember;
  }

  /// Check if user can invite members to a family (with caching)
  Future<bool> canInviteMembers(String userId, String familyId) async {
    final cacheKey = 'invite_${familyId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final canInvite = await _permissionService.canInviteMembers(userId, familyId);
    _cachePermission(cacheKey, canInvite);
    return canInvite;
  }

  /// Check if user can manage roles in a family (with caching)
  Future<bool> canManageRoles(String userId, String familyId) async {
    final cacheKey = 'manage_roles_${familyId}_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final canManage = await _permissionService.canManageRoles(userId, familyId);
    _cachePermission(cacheKey, canManage);
    return canManage;
  }

  /// Check if user is a system admin (with caching)
  Future<bool> isSystemAdmin(String userId) async {
    final cacheKey = 'admin_$userId';

    if (_isCacheValid(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final isAdmin = await _permissionService.isSystemAdmin(userId);
    _cachePermission(cacheKey, isAdmin);
    return isAdmin;
  }

  /// Add a user to device's authorized users list
  Future<void> addAuthorizedUser(String deviceId, String userId) async {
    await _permissionService.addAuthorizedUser(deviceId, userId);
    // Clear cache for this device
    _clearDeviceCache(deviceId);
    notifyListeners();
  }

  /// Remove a user from device's authorized users list
  Future<void> removeAuthorizedUser(String deviceId, String userId) async {
    await _permissionService.removeAuthorizedUser(deviceId, userId);
    // Clear cache for this device
    _clearDeviceCache(deviceId);
    notifyListeners();
  }

  /// Check if cache entry is valid (not expired)
  bool _isCacheValid(String cacheKey) {
    if (!_permissionCache.containsKey(cacheKey)) return false;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    return age < _cacheDuration;
  }

  /// Cache a permission result with timestamp
  void _cachePermission(String cacheKey, bool value) {
    _permissionCache[cacheKey] = value;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clear all cache entries for a specific device
  void _clearDeviceCache(String deviceId) {
    _permissionCache.removeWhere((key, _) => key.startsWith('device_$deviceId'));
    _cacheTimestamps.removeWhere((key, _) => key.startsWith('device_$deviceId'));
  }

  /// Clear all cache entries for a specific baby
  void clearBabyCache(String babyId) {
    _permissionCache.removeWhere((key, _) => key.contains('baby_$babyId'));
    _cacheTimestamps.removeWhere((key, _) => key.contains('baby_$babyId'));
    notifyListeners();
  }

  /// Clear all cache entries for a specific family
  void clearFamilyCache(String familyId) {
    _permissionCache.removeWhere((key, _) => key.contains(familyId));
    _cacheTimestamps.removeWhere((key, _) => key.contains(familyId));
    notifyListeners();
  }

  /// Clear entire permission cache (call after role changes, user switches, etc.)
  void clearCache() {
    _permissionCache.clear();
    _cacheTimestamps.clear();
    notifyListeners();
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;

    for (final key in _permissionCache.keys) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null) {
        final age = now.difference(timestamp);
        if (age < _cacheDuration) {
          validEntries++;
        } else {
          expiredEntries++;
        }
      }
    }

    return {
      'totalEntries': _permissionCache.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'cacheDuration': _cacheDuration.inMinutes,
    };
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
