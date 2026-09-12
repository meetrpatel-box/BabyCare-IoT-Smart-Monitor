import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/baby_model.dart';

/// Service for caching data locally for offline access
/// Allows basic app usage when network is unavailable
class OfflineCacheService {
  static const String _keyPrefix = 'offline_cache_';
  static const Duration cacheValidity = Duration(hours: 24);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ============== BABY DATA CACHING ==============

  /// Cache baby data for offline access
  Future<void> cacheBaby(BabyModel baby) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}baby_${baby.id}';
      final timestampKey = '${key}_timestamp';

      final babyJson = jsonEncode(baby.toFirestore());
      await prefs.setString(key, babyJson);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[OfflineCache] Cached baby: ${baby.name}');
    } catch (e) {
      debugPrint('[OfflineCache] Error caching baby: $e');
    }
  }

  /// Get cached baby if available and not stale
  Future<BabyModel?> getCachedBaby(String babyId) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}baby_$babyId';
      final timestampKey = '${key}_timestamp';

      final cachedData = prefs.getString(key);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is still valid
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
      if (cacheAge > cacheValidity.inMilliseconds) {
        debugPrint('[OfflineCache] Cache expired for baby $babyId');
        return null;
      }

      // Parse cached data
      final Map<String, dynamic> babyData = jsonDecode(cachedData);
      // Note: You'll need to implement fromMap in BabyModel or handle parsing
      debugPrint('[OfflineCache  Retrieved cached baby: $babyId');
      return null; // Return parsed BabyModel once fromMap is implemented
    } catch (e) {
      debugPrint('[OfflineCache] Error retrieving cached baby: $e');
      return null;
    }
  }

  /// Cache list of babies
  Future<void> cacheBabies(List<BabyModel> babies) async {
    for (final baby in babies) {
      await cacheBaby(baby);
    }
  }

  // ============== VITALS CACHING ==============

  /// Cache latest vitals for offline display
  Future<void> cacheLatestVitals(String babyId, Map<String, dynamic> vitals) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}vitals_$babyId';
      final timestampKey = '${key}_timestamp';

      await prefs.setString(key, jsonEncode(vitals));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[OfflineCache] Cached vitals for baby: $babyId');
    } catch (e) {
      debugPrint('[OfflineCache] Error caching vitals: $e');
    }
  }

  /// Get cached vitals
  Future<Map<String, dynamic>?> getCachedVitals(String babyId) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}vitals_$babyId';
      final timestampKey = '${key}_timestamp';

      final cachedData = prefs.getString(key);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) return null;

      // Vitals cache valid for 1 hour
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
      if (cacheAge > const Duration(hours: 1).inMilliseconds) {
        return null;
      }

      return jsonDecode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[OfflineCache] Error retrieving cached vitals: $e');
      return null;
    }
  }

  // ============== DEVICE DATA CACHING ==============

  /// Cache device list
  Future<void> cacheDevices(List<Map<String, dynamic>> devices) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}devices';
      final timestampKey = '${key}_timestamp';

      await prefs.setString(key, jsonEncode(devices));
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[OfflineCache] Cached ${devices.length} devices');
    } catch (e) {
      debugPrint('[OfflineCache] Error caching devices: $e');
    }
  }

  /// Get cached devices
  Future<List<Map<String, dynamic>>?> getCachedDevices() async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}devices';
      final timestampKey = '${key}_timestamp';

      final cachedData = prefs.getString(key);
      final cachedTimestamp = prefs.getInt(timestampKey);

      if (cachedData == null || cachedTimestamp == null) return null;

      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
      if (cacheAge > cacheValidity.inMilliseconds) {
        return null;
      }

      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[OfflineCache] Error retrieving cached devices: $e');
      return null;
    }
  }

  // ============== OFFLINE COMMAND QUEUE ==============

  /// Queue a command to be sent when online
  Future<void> queueCommand(Map<String, dynamic> command) async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}command_queue';

      final existingQueue = prefs.getString(key);
      final List<dynamic> queue = existingQueue != null
          ? jsonDecode(existingQueue)
          : [];

      queue.add({
        ...command,
        'queuedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await prefs.setString(key, jsonEncode(queue));
      debugPrint('[OfflineCache] Queued command: ${command['type']}');
    } catch (e) {
      debugPrint('[OfflineCache] Error queuing command: $e');
    }
  }

  /// Get queued commands
  Future<List<Map<String, dynamic>>> getQueuedCommands() async {
    try {
      final prefs = await _prefs;
      final key = '${_keyPrefix}command_queue';

      final queueData = prefs.getString(key);
      if (queueData == null) return [];

      final List<dynamic> decoded = jsonDecode(queueData);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[OfflineCache] Error retrieving command queue: $e');
      return [];
    }
  }

  /// Clear command queue (after successful sync)
  Future<void> clearCommandQueue() async {
    try {
      final prefs = await _prefs;
      await prefs.remove('${_keyPrefix}command_queue');
      debugPrint('[OfflineCache] Cleared command queue');
    } catch (e) {
      debugPrint('[OfflineCache] Error clearing command queue: $e');
    }
  }

  // ============== CACHE MANAGEMENT ==============

  /// Check if device is in offline mode
  Future<bool> isOfflineMode() async {
    // Could be enhanced to check actual connectivity
    // For now, check if we have recent cached data
    final prefs = await _prefs;
    return prefs.getBool('${_keyPrefix}offline_mode') ?? false;
  }

  /// Set offline mode
  Future<void> setOfflineMode(bool offline) async {
    final prefs = await _prefs;
    await prefs.setBool('${_keyPrefix}offline_mode', offline);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));

      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('[OfflineCache] Cleared all cached data');
    } catch (e) {
      debugPrint('[OfflineCache] Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));

      int totalItems = 0;
      int expiredItems = 0;
      int validItems = 0;

      for (final key in keys) {
        if (key.endsWith('_timestamp')) continue;

        totalItems++;
        final timestamp = prefs.getInt('${key}_timestamp');

        if (timestamp != null) {
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (age > cacheValidity.inMilliseconds) {
            expiredItems++;
          } else {
            validItems++;
          }
        }
      }

      return {
        'totalItems': totalItems,
        'validItems': validItems,
        'expiredItems': expiredItems,
        'cacheValidityHours': cacheValidity.inHours,
      };
    } catch (e) {
      debugPrint('[OfflineCache] Error getting cache stats: $e');
      return {};
    }
  }
}
