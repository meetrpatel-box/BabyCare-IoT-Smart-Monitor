/// Test fixtures for UserModel
///
/// Provides sample data for testing user-related functionality.
library user_fixtures;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sample user data for testing
class UserFixtures {
  UserFixtures._();

  /// Standard parent user fixture
  static Map<String, dynamic> get parentUserData => {
        'email': 'parent@example.com',
        'phoneNumber': '+919876543210',
        'displayName': 'Jane Doe',
        'photoUrl': 'https://example.com/jane.jpg',
        'familyId': 'family_456',
        'role': 'parent',
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 15)),
        'lastLogin': Timestamp.fromDate(DateTime.now()),
        'preferences': defaultPreferences,
      };

  /// Caregiver user fixture
  static Map<String, dynamic> get caregiverUserData => {
        'email': 'caregiver@example.com',
        'phoneNumber': '+919876543211',
        'displayName': 'Mary Smith',
        'familyId': 'family_456',
        'role': 'caregiver',
        'createdAt': Timestamp.fromDate(DateTime(2025, 2, 20)),
        'lastLogin': Timestamp.fromDate(DateTime.now()),
        'preferences': defaultPreferences,
      };

  /// User with minimal data
  static Map<String, dynamic> get minimalUserData => {
        'phoneNumber': '+919999999999',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

  /// Default user preferences
  static Map<String, dynamic> get defaultPreferences => {
        'notifications': true,
        'darkMode': false,
        'temperatureUnit': 'celsius',
        'language': 'en',
      };

  /// User with PIN enabled
  static Map<String, dynamic> get userWithPinData => {
        ...parentUserData,
        'pinEnabled': true,
        'pinHash': 'hashed_pin_value',
        'biometricEnabled': true,
      };

  /// User IDs for reference
  static const String parentUserId = 'user_parent_001';
  static const String caregiverUserId = 'user_caregiver_002';
  static const String minimalUserId = 'user_minimal_003';
}
