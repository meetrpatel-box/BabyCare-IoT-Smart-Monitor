/// Test fixtures for BabyModel
///
/// Provides sample data for testing baby-related functionality.
library baby_fixtures;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sample baby data for testing
class BabyFixtures {
  BabyFixtures._();

  /// Standard healthy baby fixture
  static Map<String, dynamic> get healthyBabyData => {
        'name': 'Emma',
        'dateOfBirth': Timestamp.fromDate(DateTime(2025, 6, 15)),
        'gender': 'female',
        'photoUrl': 'https://example.com/emma.jpg',
        'parentId': 'user_123',
        'familyId': 'family_456',
        'assignedDeviceId': 'device_789',
        'latestVitals': healthyVitalsData,
        'createdAt': Timestamp.fromDate(DateTime(2025, 6, 15, 10, 30)),
        'updatedAt': Timestamp.fromDate(DateTime(2025, 6, 20, 14, 45)),
      };

  /// Baby with no vitals data
  static Map<String, dynamic> get newBabyData => {
        'name': 'Liam',
        'dateOfBirth': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
        'gender': 'male',
        'parentId': 'user_123',
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  /// Baby with concerning vitals
  static Map<String, dynamic> get babyWithAbnormalVitalsData => {
        'name': 'Sophia',
        'dateOfBirth': Timestamp.fromDate(DateTime(2025, 8, 10)),
        'gender': 'female',
        'parentId': 'user_456',
        'latestVitals': abnormalVitalsData,
        'createdAt': Timestamp.fromDate(DateTime(2025, 8, 10)),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  /// Healthy vitals data
  static Map<String, dynamic> get healthyVitalsData => {
        'spO2': 98,
        'spO2Status': 'Normal',
        'temperature': 36.8,
        'temperatureStatus': 'Normal',
        'isCrying': false,
        'isWet': false,
        'pressureStatus': 'Optimal',
        'heartRate': 120,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

  /// Abnormal vitals data
  static Map<String, dynamic> get abnormalVitalsData => {
        'spO2': 88,
        'spO2Status': 'Low',
        'temperature': 39.2,
        'temperatureStatus': 'Fever',
        'isCrying': true,
        'isWet': true,
        'pressureStatus': 'Check',
        'heartRate': 180,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

  /// Minimal required data
  static Map<String, dynamic> get minimalBabyData => {
        'name': 'Test Baby',
        'dateOfBirth': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'gender': 'unknown',
        'parentId': 'user_test',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  /// List of multiple babies for list testing
  static List<Map<String, dynamic>> get multipleBabiesData => [
        healthyBabyData,
        newBabyData,
        babyWithAbnormalVitalsData,
      ];

  /// Baby IDs for reference
  static const String healthyBabyId = 'baby_healthy_001';
  static const String newBabyId = 'baby_new_002';
  static const String abnormalBabyId = 'baby_abnormal_003';
}
