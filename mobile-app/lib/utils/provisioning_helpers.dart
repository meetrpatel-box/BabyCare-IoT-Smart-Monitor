import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/wifi_provisioning_service.dart';

/// Helper utilities for WiFi provisioning
/// Provides auto-fill, error handling, and device persistence

class ProvisioningHelpers {
  static const _storage = FlutterSecureStorage();
  static const _lastDeviceKey = 'last_provisioned_device';
  static const _wifiPasswordPrefix = 'wifi_pass_';

  /// Error types for better user messaging
  static const Map<String, String> errorMessages = {
    'BLUETOOTH_OFF': 'Bluetooth is turned off.\nPlease enable it in Settings.',
    'LOCATION_PERMISSION':
        'Location permission is required for Bluetooth scanning on Android.\nPlease enable it in Settings.',
    'DEVICE_NOT_FOUND':
        'Device not found.\nMake sure it\'s powered on and within 10 feet of your phone.',
    'CONNECTION_TIMEOUT':
        'Connection timed out.\nMove your phone closer to the device and try again.',
    'WIFI_FAILED':
        'WiFi connection failed.\nCheck your password and make sure the network is 2.4GHz.',
    'NETWORK_NOT_FOUND':
        'WiFi network not found.\nMake sure you\'re within range of your router.',
    'WRONG_PASSWORD':
        'Incorrect WiFi password.\nPlease check your password and try again.',
  };

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    // Check for known error codes
    for (var entry in errorMessages.entries) {
      if (errorStr.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Setup error: ${error.toString()}';
  }

  /// Get troubleshooting hint based on current step
  static String getTroubleshootingHint(String step) {
    const hints = {
      'scan_devices':
          '💡 Tip: Make sure your device is powered on and the blue LED is flashing',
      'connect_device': '💡 Tip: Move your phone within 6 feet of the device',
      'scan_wifi': '💡 Tip: Make sure your router is on and broadcasting',
      'enter_password':
          '💡 Tip: Your WiFi must be 2.4GHz (ESP32 doesn\'t support 5GHz)',
      'provisioning': '💡 Tip: This takes 10-15 seconds, please be patient',
    };

    return hints[step] ?? '';
  }

  /// Save WiFi password securely
  static Future<void> saveWiFiPassword(String ssid, String password) async {
    try {
      await _storage.write(
        key: '$_wifiPasswordPrefix$ssid',
        value: password,
      );
      print('✅ Saved password for network: $ssid');
    } catch (e) {
      print('Failed to save WiFi password: $e');
    }
  }

  /// Get saved WiFi password
  static Future<String?> getSavedWiFiPassword(String ssid) async {
    try {
      return await _storage.read(key: '$_wifiPasswordPrefix$ssid');
    } catch (e) {
      print('Failed to read WiFi password: $e');
      return null;
    }
  }

  /// Auto-fill WiFi password with source tracking
  static Future<Map<String, dynamic>> autoFillWiFiPassword(String ssid) async {
    try {
      // Try to get saved password first
      final savedPassword = await getSavedWiFiPassword(ssid);
      if (savedPassword != null && savedPassword.isNotEmpty) {
        return {
          'password': savedPassword,
          'source': 'saved', // From secure storage
        };
      }

      return {
        'password': null,
        'source': null,
      };
    } catch (e) {
      print('Error auto-filling password: $e');
      return {
        'password': null,
        'source': null,
      };
    }
  }

  /// Save last provisioned device for quick reconnect
  static Future<void> saveLastDevice(DiscoveredDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceData = {
        'id': device.id,
        'name': device.name,
        'rssi': device.rssi,
        'lastUsed': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_lastDeviceKey, json.encode(deviceData));
      print('✅ Saved last device: ${device.name}');
    } catch (e) {
      print('Failed to save last device: $e');
    }
  }

  /// Load last provisioned device
  static Future<DiscoveredDevice?> loadLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceJson = prefs.getString(_lastDeviceKey);

      if (deviceJson != null) {
        final deviceData = json.decode(deviceJson);

        // Only return if used within last 7 days
        final sevenDaysAgo =
            DateTime.now().millisecondsSinceEpoch - (7 * 24 * 60 * 60 * 1000);

        if (deviceData['lastUsed'] > sevenDaysAgo) {
          print('✅ Loaded last device: ${deviceData['name']}');
          return DiscoveredDevice(
            id: deviceData['id'],
            name: deviceData['name'],
            rssi: deviceData['rssi'],
          );
        }
      }
    } catch (e) {
      print('Failed to load last device: $e');
    }
    return null;
  }

  /// Clear last device after successful provisioning
  static Future<void> clearLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastDeviceKey);
      print('✅ Cleared last device');
    } catch (e) {
      print('Failed to clear last device: $e');
    }
  }
}
