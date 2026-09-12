/// Test fixtures for DeviceModel
///
/// Provides sample data for testing device/IoT-related functionality.
library device_fixtures;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sample device data for testing
class DeviceFixtures {
  DeviceFixtures._();

  /// Online, healthy device fixture
  static Map<String, dynamic> get onlineDeviceData => {
        'deviceId': 'ANVAYA-POD-001',
        'familyId': 'family_456',
        'assignedBabyId': 'baby_healthy_001',
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'firmwareVersion': '1.2.0',
        'status': 'online',
        'connectionType': 'wifi',
        'wifiSsid': 'HomeNetwork',
        'signalStrength': -45,
        'batteryLevel': 85,
        'lastSeen': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(seconds: 30))),
        'lastVitalsUpdate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(seconds: 30))),
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 10)),
        'capabilities': defaultCapabilities,
      };

  /// Offline device fixture
  static Map<String, dynamic> get offlineDeviceData => {
        'deviceId': 'ANVAYA-POD-002',
        'familyId': 'family_456',
        'macAddress': 'AA:BB:CC:DD:EE:00',
        'firmwareVersion': '1.1.0',
        'status': 'offline',
        'batteryLevel': 15,
        'lastSeen': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 2))),
        'createdAt': Timestamp.fromDate(DateTime(2025, 2, 15)),
        'capabilities': defaultCapabilities,
      };

  /// Device in provisioning state
  static Map<String, dynamic> get provisioningDeviceData => {
        'deviceId': 'ANVAYA-POD-003',
        'macAddress': 'AA:BB:CC:DD:EE:11',
        'firmwareVersion': '1.2.0',
        'status': 'provisioning',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'capabilities': defaultCapabilities,
      };

  /// Device with low battery
  static Map<String, dynamic> get lowBatteryDeviceData => {
        ...onlineDeviceData,
        'deviceId': 'ANVAYA-POD-004',
        'batteryLevel': 5,
        'status': 'low_battery',
      };

  /// Default device capabilities
  static Map<String, dynamic> get defaultCapabilities => {
        'hasSpO2': true,
        'hasTemperature': true,
        'hasHeartRate': true,
        'hasCryDetection': true,
        'hasWetnessDetection': true,
        'hasPressureMapping': true,
        'hasCamera': false,
        'hasMicrophone': true,
        'hasNightVision': false,
      };

  /// Device IDs for reference
  static const String onlineDeviceId = 'device_online_001';
  static const String offlineDeviceId = 'device_offline_002';
  static const String provisioningDeviceId = 'device_provisioning_003';
}
