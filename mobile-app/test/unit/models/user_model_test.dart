import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:baby_track_flutter/models/user_model.dart';
import '../../fixtures/user_fixtures.dart';

void main() {
  group('UserModel', () {
    group('fromFirestore', () {
      test('creates UserModel from complete Firestore data', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('users')
            .doc(UserFixtures.parentUserId)
            .set(UserFixtures.parentUserData);

        // Act
        final doc = await fakeFirestore
            .collection('users')
            .doc(UserFixtures.parentUserId)
            .get();
        final user = UserModel.fromFirestore(doc);

        // Assert
        expect(user.id, UserFixtures.parentUserId);
        expect(user.email, 'parent@example.com');
        expect(user.phoneNumber, '+919876543210');
        expect(user.displayName, 'Jane Doe');
        expect(user.photoUrl, 'https://example.com/jane.jpg');
      });

      test('creates UserModel with minimal data', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('users')
            .doc(UserFixtures.minimalUserId)
            .set(UserFixtures.minimalUserData);

        // Act
        final doc = await fakeFirestore
            .collection('users')
            .doc(UserFixtures.minimalUserId)
            .get();
        final user = UserModel.fromFirestore(doc);

        // Assert
        expect(user.phoneNumber, '+919999999999');
        expect(user.displayName, isNull);
        expect(user.photoUrl, isNull);
        expect(user.familyIds, isEmpty);
      });

      test('parses preferences correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        final dataWithPrefs = {
          ...UserFixtures.parentUserData,
          'preferences': {
            'notificationsEnabled': false,
            'darkModeEnabled': true,
            'temperatureUnit': 'fahrenheit',
            'language': 'hi',
            'biometricEnabled': true,
          },
        };
        await fakeFirestore
            .collection('users')
            .doc('user_with_prefs')
            .set(dataWithPrefs);

        // Act
        final doc = await fakeFirestore
            .collection('users')
            .doc('user_with_prefs')
            .get();
        final user = UserModel.fromFirestore(doc);

        // Assert
        expect(user.preferences.notificationsEnabled, false);
        expect(user.preferences.darkModeEnabled, true);
        expect(user.preferences.temperatureUnit, 'fahrenheit');
        expect(user.preferences.language, 'hi');
        expect(user.preferences.biometricEnabled, true);
      });

      test('handles familyIds array', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        final dataWithFamilies = {
          ...UserFixtures.parentUserData,
          'familyIds': ['family_1', 'family_2', 'family_3'],
        };
        await fakeFirestore
            .collection('users')
            .doc('user_with_families')
            .set(dataWithFamilies);

        // Act
        final doc = await fakeFirestore
            .collection('users')
            .doc('user_with_families')
            .get();
        final user = UserModel.fromFirestore(doc);

        // Assert
        expect(user.familyIds, hasLength(3));
        expect(user.familyIds, contains('family_1'));
        expect(user.familyIds, contains('family_2'));
        expect(user.familyIds, contains('family_3'));
      });
    });

    group('toFirestore', () {
      test('converts UserModel to Firestore format', () {
        // Arrange
        final user = UserModel(
          id: 'user_123',
          email: 'test@example.com',
          phoneNumber: '+919876543210',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: DateTime(2025, 1, 1),
          lastLoginAt: DateTime(2025, 6, 15),
          preferences: UserPreferences(),
          familyIds: ['family_1'],
        );

        // Act
        final data = user.toFirestore();

        // Assert
        expect(data['email'], 'test@example.com');
        expect(data['phoneNumber'], '+919876543210');
        expect(data['displayName'], 'Test User');
        expect(data['photoUrl'], 'https://example.com/photo.jpg');
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['lastLoginAt'], isA<Timestamp>());
        expect(data['familyIds'], ['family_1']);
        expect(data['preferences'], isA<Map<String, dynamic>>());
      });

      test('includes preferences in Firestore format', () {
        // Arrange
        final user = UserModel(
          id: 'user_123',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          preferences: UserPreferences(
            notificationsEnabled: false,
            darkModeEnabled: true,
            temperatureUnit: 'fahrenheit',
          ),
        );

        // Act
        final data = user.toFirestore();

        // Assert
        expect(data['preferences']['notificationsEnabled'], false);
        expect(data['preferences']['darkModeEnabled'], true);
        expect(data['preferences']['temperatureUnit'], 'fahrenheit');
      });
    });

    group('copyWith', () {
      test('creates copy with updated email', () {
        // Arrange
        final user = UserModel(
          id: 'user_123',
          email: 'old@example.com',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          preferences: UserPreferences(),
        );

        // Act
        final updatedUser = user.copyWith(email: 'new@example.com');

        // Assert
        expect(updatedUser.email, 'new@example.com');
        expect(updatedUser.id, user.id);
      });

      test('creates copy with updated preferences', () {
        // Arrange
        final user = UserModel(
          id: 'user_123',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          preferences: UserPreferences(darkModeEnabled: false),
        );

        final newPreferences = UserPreferences(darkModeEnabled: true);

        // Act
        final updatedUser = user.copyWith(preferences: newPreferences);

        // Assert
        expect(updatedUser.preferences.darkModeEnabled, true);
      });

      test('creates copy with updated familyIds', () {
        // Arrange
        final user = UserModel(
          id: 'user_123',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          preferences: UserPreferences(),
          familyIds: ['family_1'],
        );

        // Act
        final updatedUser = user.copyWith(
          familyIds: ['family_1', 'family_2'],
        );

        // Assert
        expect(updatedUser.familyIds, hasLength(2));
        expect(updatedUser.familyIds, contains('family_2'));
      });
    });
  });

  group('UserPreferences', () {
    group('fromMap', () {
      test('creates UserPreferences from valid map', () {
        // Act
        final prefs = UserPreferences.fromMap(UserFixtures.defaultPreferences);

        // Assert
        expect(prefs.notificationsEnabled, true);
        expect(prefs.darkModeEnabled, false);
        expect(prefs.temperatureUnit, 'celsius');
        expect(prefs.language, 'en');
      });

      test('handles empty map with defaults', () {
        // Act
        final prefs = UserPreferences.fromMap({});

        // Assert
        expect(prefs.notificationsEnabled, true);
        expect(prefs.darkModeEnabled, false);
        expect(prefs.temperatureUnit, 'celsius');
        expect(prefs.language, 'en');
        expect(prefs.biometricEnabled, false);
      });

      test('respects custom values over defaults', () {
        // Arrange
        final customPrefs = {
          'notificationsEnabled': false,
          'darkModeEnabled': true,
          'temperatureUnit': 'fahrenheit',
          'language': 'hi',
          'biometricEnabled': true,
        };

        // Act
        final prefs = UserPreferences.fromMap(customPrefs);

        // Assert
        expect(prefs.notificationsEnabled, false);
        expect(prefs.darkModeEnabled, true);
        expect(prefs.temperatureUnit, 'fahrenheit');
        expect(prefs.language, 'hi');
        expect(prefs.biometricEnabled, true);
      });
    });

    group('toMap', () {
      test('converts UserPreferences to map', () {
        // Arrange
        final prefs = UserPreferences(
          notificationsEnabled: true,
          darkModeEnabled: true,
          temperatureUnit: 'fahrenheit',
          language: 'hi',
          biometricEnabled: true,
        );

        // Act
        final map = prefs.toMap();

        // Assert
        expect(map['notificationsEnabled'], true);
        expect(map['darkModeEnabled'], true);
        expect(map['temperatureUnit'], 'fahrenheit');
        expect(map['language'], 'hi');
        expect(map['biometricEnabled'], true);
      });
    });

    group('default values', () {
      test('has sensible defaults', () {
        // Act
        final prefs = UserPreferences();

        // Assert
        expect(prefs.notificationsEnabled, true);
        expect(prefs.darkModeEnabled, false);
        expect(prefs.temperatureUnit, 'celsius');
        expect(prefs.language, 'en');
        expect(prefs.biometricEnabled, false);
      });
    });
  });
}
