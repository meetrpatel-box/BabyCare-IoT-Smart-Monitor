import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:baby_track_flutter/models/baby_model.dart';
import '../../fixtures/baby_fixtures.dart';

void main() {
  group('BabyModel', () {
    group('fromFirestore', () {
      test('creates BabyModel from complete Firestore data', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.healthyBabyId)
            .set(BabyFixtures.healthyBabyData);

        // Act
        final doc = await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.healthyBabyId)
            .get();
        final baby = BabyModel.fromFirestore(doc);

        // Assert
        expect(baby.id, BabyFixtures.healthyBabyId);
        expect(baby.name, 'Emma');
        expect(baby.gender, 'female');
        expect(baby.photoUrl, 'https://example.com/emma.jpg');
        expect(baby.parentId, 'user_123');
        expect(baby.familyId, 'family_456');
        expect(baby.assignedDeviceId, 'device_789');
      });

      test('creates BabyModel with minimal data', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('babies')
            .doc('minimal_baby')
            .set(BabyFixtures.minimalBabyData);

        // Act
        final doc =
            await fakeFirestore.collection('babies').doc('minimal_baby').get();
        final baby = BabyModel.fromFirestore(doc);

        // Assert
        expect(baby.name, 'Test Baby');
        expect(baby.gender, 'unknown');
        expect(baby.photoUrl, isNull);
        expect(baby.familyId, isNull);
        expect(baby.assignedDeviceId, isNull);
        expect(baby.latestVitals, isNull);
      });

      test('parses latestVitals correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.healthyBabyId)
            .set(BabyFixtures.healthyBabyData);

        // Act
        final doc = await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.healthyBabyId)
            .get();
        final baby = BabyModel.fromFirestore(doc);

        // Assert
        expect(baby.latestVitals, isNotNull);
        expect(baby.latestVitals!.spO2, 98);
        expect(baby.latestVitals!.spO2Status, VitalStatus.normal);
        expect(baby.latestVitals!.temperature, 36.8);
        expect(baby.latestVitals!.temperatureStatus, TemperatureStatus.normal);
        expect(baby.latestVitals!.heartRate, 120);
        expect(baby.latestVitals!.isCrying, false);
        expect(baby.latestVitals!.isWet, false);
      });

      test('handles abnormal vitals correctly', () async {
        // Arrange
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.abnormalBabyId)
            .set(BabyFixtures.babyWithAbnormalVitalsData);

        // Act
        final doc = await fakeFirestore
            .collection('babies')
            .doc(BabyFixtures.abnormalBabyId)
            .get();
        final baby = BabyModel.fromFirestore(doc);

        // Assert
        expect(baby.latestVitals, isNotNull);
        expect(baby.latestVitals!.spO2, 88);
        expect(baby.latestVitals!.spO2Status, VitalStatus.low);
        expect(baby.latestVitals!.temperature, 39.2);
        expect(baby.latestVitals!.temperatureStatus, TemperatureStatus.fever);
        expect(baby.latestVitals!.isCrying, true);
        expect(baby.latestVitals!.isWet, true);
      });
    });

    group('toFirestore', () {
      test('converts BabyModel to Firestore format', () {
        // Arrange
        final baby = BabyModel(
          id: 'test_id',
          name: 'Test Baby',
          dateOfBirth: DateTime(2025, 6, 15),
          gender: 'female',
          photoUrl: 'https://example.com/photo.jpg',
          parentId: 'parent_123',
          familyId: 'family_456',
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 6, 20),
        );

        // Act
        final data = baby.toFirestore();

        // Assert
        expect(data['name'], 'Test Baby');
        expect(data['gender'], 'female');
        expect(data['photoUrl'], 'https://example.com/photo.jpg');
        expect(data['parentId'], 'parent_123');
        expect(data['familyId'], 'family_456');
        expect(data['dateOfBirth'], isA<Timestamp>());
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());
      });

      test('includes latestVitals in Firestore format', () {
        // Arrange
        final vitals = LatestVitals(
          spO2: 98,
          spO2Status: VitalStatus.normal,
          temperature: 36.8,
          temperatureStatus: TemperatureStatus.normal,
          heartRate: 120,
          isCrying: false,
          isWet: false,
        );
        final baby = BabyModel(
          id: 'test_id',
          name: 'Test Baby',
          dateOfBirth: DateTime(2025, 6, 15),
          gender: 'female',
          parentId: 'parent_123',
          latestVitals: vitals,
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 6, 20),
        );

        // Act
        final data = baby.toFirestore();

        // Assert
        expect(data['latestVitals'], isNotNull);
        expect(data['latestVitals']['spO2'], 98);
        expect(data['latestVitals']['temperature'], 36.8);
        expect(data['latestVitals']['heartRate'], 120);
      });
    });

    group('ageInMonths', () {
      test('calculates age correctly for baby born months ago', () {
        // Arrange
        final baby = BabyModel(
          id: 'test',
          name: 'Test',
          dateOfBirth: DateTime.now().subtract(const Duration(days: 90)),
          gender: 'female',
          parentId: 'parent_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final ageInMonths = baby.ageInMonths;

        // Assert
        expect(ageInMonths, greaterThanOrEqualTo(2));
        expect(ageInMonths, lessThanOrEqualTo(4));
      });

      test('returns 0 for newborn baby', () {
        // Arrange
        final baby = BabyModel(
          id: 'test',
          name: 'Newborn',
          dateOfBirth: DateTime.now().subtract(const Duration(days: 10)),
          gender: 'male',
          parentId: 'parent_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final ageInMonths = baby.ageInMonths;

        // Assert
        expect(ageInMonths, 0);
      });
    });

    group('ageDisplay', () {
      test('shows days for baby less than 1 month old', () {
        // Arrange
        final baby = BabyModel(
          id: 'test',
          name: 'Newborn',
          dateOfBirth: DateTime.now().subtract(const Duration(days: 15)),
          gender: 'male',
          parentId: 'parent_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final ageDisplay = baby.ageDisplay;

        // Assert
        expect(ageDisplay, contains('days'));
      });

      test('shows months for baby 1-11 months old', () {
        // Arrange
        final baby = BabyModel(
          id: 'test',
          name: 'Infant',
          dateOfBirth: DateTime.now().subtract(const Duration(days: 180)),
          gender: 'female',
          parentId: 'parent_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final ageDisplay = baby.ageDisplay;

        // Assert
        expect(ageDisplay, contains('months'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated name', () {
        // Arrange
        final baby = BabyModel(
          id: 'test_id',
          name: 'Original Name',
          dateOfBirth: DateTime(2025, 6, 15),
          gender: 'female',
          parentId: 'parent_123',
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 6, 20),
        );

        // Act
        final updatedBaby = baby.copyWith(name: 'New Name');

        // Assert
        expect(updatedBaby.name, 'New Name');
        expect(updatedBaby.id, baby.id);
        expect(updatedBaby.gender, baby.gender);
        expect(updatedBaby.parentId, baby.parentId);
      });

      test('creates copy with new vitals', () {
        // Arrange
        final baby = BabyModel(
          id: 'test_id',
          name: 'Test Baby',
          dateOfBirth: DateTime(2025, 6, 15),
          gender: 'female',
          parentId: 'parent_123',
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 6, 20),
        );

        final newVitals = LatestVitals(
          spO2: 99,
          heartRate: 115,
        );

        // Act
        final updatedBaby = baby.copyWith(latestVitals: newVitals);

        // Assert
        expect(updatedBaby.latestVitals, isNotNull);
        expect(updatedBaby.latestVitals!.spO2, 99);
        expect(updatedBaby.latestVitals!.heartRate, 115);
      });
    });
  });

  group('LatestVitals', () {
    group('fromMap', () {
      test('creates LatestVitals from valid map', () {
        // Act
        final vitals = LatestVitals.fromMap(BabyFixtures.healthyVitalsData);

        // Assert
        expect(vitals.spO2, 98);
        expect(vitals.spO2Status, VitalStatus.normal);
        expect(vitals.temperature, 36.8);
        expect(vitals.temperatureStatus, TemperatureStatus.normal);
        expect(vitals.heartRate, 120);
        expect(vitals.isCrying, false);
        expect(vitals.isWet, false);
        expect(vitals.pressureStatus, PressureStatus.optimal);
      });

      test('handles empty map with defaults', () {
        // Act
        final vitals = LatestVitals.fromMap({});

        // Assert
        expect(vitals.spO2, isNull);
        expect(vitals.spO2Status, VitalStatus.unknown);
        expect(vitals.temperature, isNull);
        expect(vitals.isCrying, false);
        expect(vitals.isWet, false);
      });
    });

    group('toMap', () {
      test('converts LatestVitals to map', () {
        // Arrange
        final vitals = LatestVitals(
          spO2: 98,
          spO2Status: VitalStatus.normal,
          temperature: 36.8,
          temperatureStatus: TemperatureStatus.normal,
          heartRate: 120,
        );

        // Act
        final map = vitals.toMap();

        // Assert
        expect(map['spO2'], 98);
        expect(map['spO2Status'], 'Normal');
        expect(map['temperature'], 36.8);
        expect(map['temperatureStatus'], 'Normal');
        expect(map['heartRate'], 120);
      });
    });
  });

  group('VitalStatus', () {
    test('fromString returns correct enum value', () {
      expect(VitalStatus.fromString('Normal'), VitalStatus.normal);
      expect(VitalStatus.fromString('Low'), VitalStatus.low);
      expect(VitalStatus.fromString('Critical'), VitalStatus.critical);
      expect(VitalStatus.fromString('Unknown'), VitalStatus.unknown);
    });

    test('fromString returns unknown for invalid value', () {
      expect(VitalStatus.fromString('InvalidValue'), VitalStatus.unknown);
      expect(VitalStatus.fromString(null), VitalStatus.unknown);
    });
  });

  group('TemperatureStatus', () {
    test('fromString returns correct enum value', () {
      expect(TemperatureStatus.fromString('Normal'), TemperatureStatus.normal);
      expect(TemperatureStatus.fromString('Slightly Elevated'),
          TemperatureStatus.slightlyElevated);
      expect(TemperatureStatus.fromString('Fever'), TemperatureStatus.fever);
    });

    test('fromString returns normal for invalid value', () {
      expect(TemperatureStatus.fromString('InvalidValue'),
          TemperatureStatus.normal);
      expect(TemperatureStatus.fromString(null), TemperatureStatus.normal);
    });
  });

  group('PressureStatus', () {
    test('fromString returns correct enum value', () {
      expect(PressureStatus.fromString('Optimal'), PressureStatus.optimal);
      expect(PressureStatus.fromString('Check'), PressureStatus.check);
      expect(PressureStatus.fromString('Unknown'), PressureStatus.unknown);
    });

    test('fromString returns unknown for invalid value', () {
      expect(PressureStatus.fromString('InvalidValue'), PressureStatus.unknown);
      expect(PressureStatus.fromString(null), PressureStatus.unknown);
    });
  });
}
