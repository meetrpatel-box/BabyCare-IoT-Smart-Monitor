import 'package:baby_track_flutter/models/models.dart';
import 'package:baby_track_flutter/providers/milestone_provider.dart';
import 'package:baby_track_flutter/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../mocks/mock_firestore_service.dart';

void main() {
  group('MilestoneProvider', () {
    late MilestoneProvider provider;
    late FirestoreService mockFirestoreService;

    setUp(() {
      mockFirestoreService = MockFirestoreService();
      provider = MilestoneProvider(firestoreService: mockFirestoreService);
    });

    test('initial state should be correct', () {
      expect(provider.milestones, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.selectedCategory, isNull);
    });

    test('getMilestoneById returns correct milestone', () async {
      final milestone = MilestoneModel(
        id: 'test-1',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'First steps',
        description: 'Walks independently',
        achievedDate: DateTime.now().subtract(const Duration(days: 7)),
        ageInMonths: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Manually add to provider's internal list for testing
      provider.milestones.add(milestone);

      final result = provider.getMilestoneById('test-1');
      expect(result, equals(milestone));
    });

    test('getMilestonesByCategory filters correctly', () {
      final physical = MilestoneModel(
        id: 'test-1',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'First steps',
        description: 'Walks independently',
        achievedDate: DateTime.now().subtract(const Duration(days: 7)),
        ageInMonths: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cognitive = MilestoneModel(
        id: 'test-2',
        babyId: 'baby-1',
        category: MilestoneCategory.cognitive,
        title: 'Object permanence',
        description: 'Understands objects exist when hidden',
        achievedDate: DateTime.now().add(const Duration(days: 30)),
        ageInMonths: 8,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.milestones.addAll([physical, cognitive]);

      final physicalOnly =
          provider.getMilestonesByCategory(MilestoneCategory.physical);
      expect(physicalOnly, hasLength(1));
      expect(physicalOnly.first.id, equals('test-1'));
    });

    test('getCompletionPercentage calculates correctly', () {
      final completed = MilestoneModel(
        id: 'test-1',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'First steps',
        description: 'Walks independently',
        achievedDate: DateTime.now().subtract(const Duration(days: 7)),
        ageInMonths: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final incomplete = MilestoneModel(
        id: 'test-2',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'Runs',
        description: 'Runs independently',
        achievedDate: DateTime.now().add(const Duration(days: 30)),
        ageInMonths: 14,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.milestones.addAll([completed, incomplete]);

      final percentage = provider.getCompletionPercentage(14);
      expect(percentage, equals(50.0)); // 1 out of 2 in age range
    });

    test('filterByCategory updates selectedCategory', () {
      provider.filterByCategory(MilestoneCategory.physical);
      expect(provider.selectedCategory, equals(MilestoneCategory.physical));

      provider.filterByCategory(null);
      expect(provider.selectedCategory, isNull);
    });

    test('completedCount returns correct count', () {
      final completed1 = MilestoneModel(
        id: 'test-1',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'First steps',
        description: 'Walks independently',
        achievedDate: DateTime.now().subtract(const Duration(days: 7)),
        ageInMonths: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final completed2 = MilestoneModel(
        id: 'test-2',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'Runs',
        description: 'Runs independently',
        achievedDate: DateTime.now().subtract(const Duration(days: 3)),
        ageInMonths: 14,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final incomplete = MilestoneModel(
        id: 'test-3',
        babyId: 'baby-1',
        category: MilestoneCategory.cognitive,
        title: 'Problem solving',
        description: 'Solves simple puzzles',
        achievedDate: DateTime.now().add(const Duration(days: 30)),
        ageInMonths: 16,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.milestones.addAll([completed1, completed2, incomplete]);

      expect(provider.completedCount, equals(2));
    });

    test('totalCount returns correct count', () {
      final milestone1 = MilestoneModel(
        id: 'test-1',
        babyId: 'baby-1',
        category: MilestoneCategory.physical,
        title: 'First steps',
        description: 'Walks independently',
        achievedDate: DateTime.now(),
        ageInMonths: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final milestone2 = MilestoneModel(
        id: 'test-2',
        babyId: 'baby-1',
        category: MilestoneCategory.cognitive,
        title: 'Object permanence',
        description: 'Understands objects exist when hidden',
        achievedDate: DateTime.now(),
        ageInMonths: 8,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.milestones.addAll([milestone1, milestone2]);

      expect(provider.totalCount, equals(2));
    });

    test('dispose cancels subscription', () {
      // Just verify it doesn't throw
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
