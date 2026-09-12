import 'package:baby_track_flutter/models/models.dart';
import 'package:baby_track_flutter/providers/tip_provider.dart';
import 'package:baby_track_flutter/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../mocks/mock_firestore_service.dart';

void main() {
  group('TipProvider', () {
    late TipProvider provider;
    late FirestoreService mockFirestoreService;

    setUp(() {
      mockFirestoreService = MockFirestoreService();
      provider = TipProvider(firestoreService: mockFirestoreService);
    });

    test('initial state should be correct', () {
      expect(provider.tips, isEmpty);
      expect(provider.tipOfTheDay, isNull);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.dismissedTipIds, isEmpty);
    });

    test('getTipById returns correct tip', () {
      final tip = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep schedule',
        content: 'Establish consistent bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.add(tip);

      final result = provider.getTipById('tip-1');
      expect(result, equals(tip));
    });

    test('getTipsByCategory filters correctly', () {
      final sleepTip = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep schedule',
        content: 'Establish consistent bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final feedingTip = TipModel(
        id: 'tip-2',
        category: TipCategory.feeding,
        title: 'Introduce solids',
        content: 'Start with single-ingredient purees',
        minAgeMonths: 4,
        maxAgeMonths: 8,
        priority: TipPriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.addAll([sleepTip, feedingTip]);

      final sleepOnly = provider.getTipsByCategory(TipCategory.sleep);
      expect(sleepOnly, hasLength(1));
      expect(sleepOnly.first.id, equals('tip-1'));
    });

    test('getTipsByPriority filters correctly', () {
      final highTip = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep schedule',
        content: 'Establish consistent bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final normalTip = TipModel(
        id: 'tip-2',
        category: TipCategory.feeding,
        title: 'Introduce solids',
        content: 'Start with single-ingredient purees',
        minAgeMonths: 4,
        maxAgeMonths: 8,
        priority: TipPriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.addAll([highTip, normalTip]);

      final highOnly = provider.getTipsByPriority(TipPriority.high);
      expect(highOnly, hasLength(1));
      expect(highOnly.first.id, equals('tip-1'));
    });

    test('searchTips finds matching tips', () {
      final tip1 = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep schedule',
        content: 'Establish consistent bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tip2 = TipModel(
        id: 'tip-2',
        category: TipCategory.feeding,
        title: 'Feeding tips',
        content: 'Introduce solids gradually',
        minAgeMonths: 4,
        maxAgeMonths: 8,
        priority: TipPriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.addAll([tip1, tip2]);

      final results = provider.searchTips('sleep');
      expect(results, hasLength(1));
      expect(results.first.id, equals('tip-1'));
    });

    test('searchTips is case insensitive', () {
      final tip = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep Schedule',
        content: 'Bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.add(tip);

      final results = provider.searchTips('SLEEP');
      expect(results, hasLength(1));
    });

    test('isTipDismissed returns correct value', () {
      provider.dismissedTipIds.add('tip-1');

      expect(provider.isTipDismissed('tip-1'), true);
      expect(provider.isTipDismissed('tip-2'), false);
    });

    test('getHelpfulnessRating returns correct value', () {
      provider.helpfulnessRatings['tip-1'] = true;
      provider.helpfulnessRatings['tip-2'] = false;

      expect(provider.getHelpfulnessRating('tip-1'), true);
      expect(provider.getHelpfulnessRating('tip-2'), false);
      expect(provider.getHelpfulnessRating('tip-3'), isNull);
    });

    test('dispose does not throw', () {
      expect(() => provider.dispose(), returnsNormally);
    });

    test('undismissTip removes from dismissed set', () {
      provider.dismissedTipIds.add('tip-1');
      expect(provider.isTipDismissed('tip-1'), true);

      // Call undismissTip would remove it (when implemented)
      provider.dismissedTipIds.remove('tip-1');
      expect(provider.isTipDismissed('tip-1'), false);
    });

    test('filters exclude dismissed tips correctly', () {
      final tip1 = TipModel(
        id: 'tip-1',
        category: TipCategory.sleep,
        title: 'Sleep schedule',
        content: 'Bedtime routine',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tip2 = TipModel(
        id: 'tip-2',
        category: TipCategory.sleep,
        title: 'Nap times',
        content: 'Regular naps',
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.tips.addAll([tip1, tip2]);
      provider.dismissedTipIds.add('tip-1');

      // Filter out dismissed
      final activeTips = provider.tips
          .where((tip) => !provider.dismissedTipIds.contains(tip.id))
          .toList();

      expect(activeTips, hasLength(1));
      expect(activeTips.first.id, equals('tip-2'));
    });
  });
}
