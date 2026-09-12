import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/models/milestone_model.dart';

void main() {
  group('MilestoneModel', () {
    late MilestoneModel testMilestone;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15);
      testMilestone = MilestoneModel(
        id: 'milestone1',
        babyId: 'baby1',
        title: 'First Smile',
        description: 'Baby smiled for the first time!',
        category: MilestoneCategory.social,
        achievedDate: testDate,
        ageInMonths: 2,
        photoUrls: ['https://example.com/photo1.jpg'],
        notes: 'Such a precious moment',
        createdAt: testDate,
        updatedAt: testDate,
      );
    });

    test('creates milestone with required fields', () {
      expect(testMilestone.id, 'milestone1');
      expect(testMilestone.babyId, 'baby1');
      expect(testMilestone.title, 'First Smile');
      expect(testMilestone.category, MilestoneCategory.social);
      expect(testMilestone.ageInMonths, 2);
    });

    test('creates milestone with optional fields', () {
      expect(testMilestone.description, 'Baby smiled for the first time!');
      expect(testMilestone.photoUrls, ['https://example.com/photo1.jpg']);
      expect(testMilestone.notes, 'Such a precious moment');
    });

    test('creates milestone without optional fields', () {
      final minimalMilestone = MilestoneModel(
        id: 'milestone2',
        babyId: 'baby1',
        title: 'Rolled Over',
        category: MilestoneCategory.physical,
        achievedDate: testDate,
        ageInMonths: 4,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(minimalMilestone.description, isNull);
      expect(minimalMilestone.photoUrls, isEmpty);
      expect(minimalMilestone.notes, isNull);
    });

    test('toFirestore converts to map correctly', () {
      final map = testMilestone.toFirestore();

      expect(map['babyId'], 'baby1');
      expect(map['title'], 'First Smile');
      expect(map['description'], 'Baby smiled for the first time!');
      expect(map['category'], 'social');
      expect(map['achievedDate'], isA<Timestamp>());
      expect(map['ageInMonths'], 2);
      expect(map['photoUrls'], ['https://example.com/photo1.jpg']);
      expect(map['notes'], 'Such a precious moment');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('copyWith creates new instance with updated fields', () {
      final updated = testMilestone.copyWith(
        title: 'First Big Smile',
        ageInMonths: 3,
      );

      expect(updated.id, testMilestone.id);
      expect(updated.title, 'First Big Smile');
      expect(updated.ageInMonths, 3);
      expect(updated.description, testMilestone.description);
      expect(updated.category, testMilestone.category);
    });

    test('copyWith with no parameters returns identical values', () {
      final copied = testMilestone.copyWith();

      expect(copied.id, testMilestone.id);
      expect(copied.title, testMilestone.title);
      expect(copied.babyId, testMilestone.babyId);
      expect(copied.category, testMilestone.category);
    });

    test('equality checks id, babyId, title, and category', () {
      final milestone1 = MilestoneModel(
        id: 'milestone1',
        babyId: 'baby1',
        title: 'First Smile',
        category: MilestoneCategory.social,
        achievedDate: testDate,
        ageInMonths: 2,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final milestone2 = MilestoneModel(
        id: 'milestone1',
        babyId: 'baby1',
        title: 'First Smile',
        category: MilestoneCategory.social,
        achievedDate: testDate.add(const Duration(days: 1)),
        ageInMonths: 3,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(milestone1, equals(milestone2));
      expect(milestone1.hashCode, equals(milestone2.hashCode));
    });

    test('toString returns formatted string', () {
      final string = testMilestone.toString();

      expect(string, contains('MilestoneModel'));
      expect(string, contains('milestone1'));
      expect(string, contains('baby1'));
      expect(string, contains('First Smile'));
      expect(string, contains('social'));
      expect(string, contains('2'));
    });
  });

  group('MilestoneCategory', () {
    test('enum values return correct string values', () {
      expect(MilestoneCategory.physical.value, 'physical');
      expect(MilestoneCategory.cognitive.value, 'cognitive');
      expect(MilestoneCategory.language.value, 'language');
      expect(MilestoneCategory.social.value, 'social');
      expect(MilestoneCategory.emotional.value, 'emotional');
      expect(MilestoneCategory.feeding.value, 'feeding');
      expect(MilestoneCategory.sleep.value, 'sleep');
      expect(MilestoneCategory.other.value, 'other');
    });

    test('enum display names are formatted correctly', () {
      expect(MilestoneCategory.physical.displayName, 'Physical');
      expect(MilestoneCategory.cognitive.displayName, 'Cognitive');
      expect(MilestoneCategory.language.displayName, 'Language');
      expect(MilestoneCategory.social.displayName, 'Social');
      expect(MilestoneCategory.emotional.displayName, 'Emotional');
      expect(MilestoneCategory.feeding.displayName, 'Feeding');
      expect(MilestoneCategory.sleep.displayName, 'Sleep');
      expect(MilestoneCategory.other.displayName, 'Other');
    });

    test('enum icons are assigned correctly', () {
      expect(MilestoneCategory.physical.icon, '🏃');
      expect(MilestoneCategory.cognitive.icon, '🧠');
      expect(MilestoneCategory.language.icon, '💬');
      expect(MilestoneCategory.social.icon, '👥');
      expect(MilestoneCategory.emotional.icon, '❤️');
      expect(MilestoneCategory.feeding.icon, '🍼');
      expect(MilestoneCategory.sleep.icon, '😴');
      expect(MilestoneCategory.other.icon, '⭐');
    });

    test('fromString converts string to correct enum', () {
      expect(
        MilestoneCategoryExtension.fromString('physical'),
        MilestoneCategory.physical,
      );
      expect(
        MilestoneCategoryExtension.fromString('cognitive'),
        MilestoneCategory.cognitive,
      );
      expect(
        MilestoneCategoryExtension.fromString('language'),
        MilestoneCategory.language,
      );
      expect(
        MilestoneCategoryExtension.fromString('social'),
        MilestoneCategory.social,
      );
      expect(
        MilestoneCategoryExtension.fromString('emotional'),
        MilestoneCategory.emotional,
      );
      expect(
        MilestoneCategoryExtension.fromString('feeding'),
        MilestoneCategory.feeding,
      );
      expect(
        MilestoneCategoryExtension.fromString('sleep'),
        MilestoneCategory.sleep,
      );
      expect(
        MilestoneCategoryExtension.fromString('other'),
        MilestoneCategory.other,
      );
    });

    test('fromString is case-insensitive', () {
      expect(
        MilestoneCategoryExtension.fromString('PHYSICAL'),
        MilestoneCategory.physical,
      );
      expect(
        MilestoneCategoryExtension.fromString('Physical'),
        MilestoneCategory.physical,
      );
    });

    test('fromString returns other for unknown value', () {
      expect(
        MilestoneCategoryExtension.fromString('unknown'),
        MilestoneCategory.other,
      );
      expect(
        MilestoneCategoryExtension.fromString(''),
        MilestoneCategory.other,
      );
    });
  });
}
