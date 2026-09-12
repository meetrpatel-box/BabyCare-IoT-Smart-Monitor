import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/models/tip_model.dart';

void main() {
  group('TipModel', () {
    late TipModel testTip;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15);
      testTip = TipModel(
        id: 'tip1',
        title: 'Safe Sleep Practices',
        content: 'Always place baby on their back to sleep.',
        category: TipCategory.safety,
        minAgeMonths: 0,
        maxAgeMonths: 12,
        priority: TipPriority.urgent,
        tags: ['sleep', 'safety', 'SIDS'],
        sourceUrl: 'https://www.aap.org/safe-sleep',
        imageUrl: 'https://example.com/safe-sleep.jpg',
        isAiGenerated: false,
        createdAt: testDate,
        updatedAt: testDate,
      );
    });

    test('creates tip with required fields', () {
      expect(testTip.id, 'tip1');
      expect(testTip.title, 'Safe Sleep Practices');
      expect(testTip.content, 'Always place baby on their back to sleep.');
      expect(testTip.category, TipCategory.safety);
      expect(testTip.minAgeMonths, 0);
      expect(testTip.maxAgeMonths, 12);
    });

    test('creates tip with optional fields', () {
      expect(testTip.priority, TipPriority.urgent);
      expect(testTip.tags, ['sleep', 'safety', 'SIDS']);
      expect(testTip.sourceUrl, 'https://www.aap.org/safe-sleep');
      expect(testTip.imageUrl, 'https://example.com/safe-sleep.jpg');
      expect(testTip.isAiGenerated, false);
    });

    test('creates tip without optional fields', () {
      final minimalTip = TipModel(
        id: 'tip2',
        title: 'Feeding Schedule',
        content: 'Feed baby every 2-3 hours.',
        category: TipCategory.feeding,
        minAgeMonths: 0,
        maxAgeMonths: 3,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(minimalTip.priority, TipPriority.normal);
      expect(minimalTip.tags, isEmpty);
      expect(minimalTip.sourceUrl, isNull);
      expect(minimalTip.imageUrl, isNull);
      expect(minimalTip.isAiGenerated, false);
    });

    test('isRelevantForAge returns true when age is in range', () {
      expect(testTip.isRelevantForAge(0), true);
      expect(testTip.isRelevantForAge(6), true);
      expect(testTip.isRelevantForAge(12), true);
    });

    test('isRelevantForAge returns false when age is out of range', () {
      expect(testTip.isRelevantForAge(-1), false);
      expect(testTip.isRelevantForAge(13), false);
      expect(testTip.isRelevantForAge(24), false);
    });

    test('toFirestore converts to map correctly', () {
      final map = testTip.toFirestore();

      expect(map['title'], 'Safe Sleep Practices');
      expect(map['content'], 'Always place baby on their back to sleep.');
      expect(map['category'], 'safety');
      expect(map['minAgeMonths'], 0);
      expect(map['maxAgeMonths'], 12);
      expect(map['priority'], 'urgent');
      expect(map['tags'], ['sleep', 'safety', 'SIDS']);
      expect(map['sourceUrl'], 'https://www.aap.org/safe-sleep');
      expect(map['imageUrl'], 'https://example.com/safe-sleep.jpg');
      expect(map['isAiGenerated'], false);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('copyWith creates new instance with updated fields', () {
      final updated = testTip.copyWith(
        title: 'Updated Safe Sleep',
        priority: TipPriority.high,
        maxAgeMonths: 18,
      );

      expect(updated.id, testTip.id);
      expect(updated.title, 'Updated Safe Sleep');
      expect(updated.priority, TipPriority.high);
      expect(updated.maxAgeMonths, 18);
      expect(updated.content, testTip.content);
      expect(updated.category, testTip.category);
      expect(updated.minAgeMonths, testTip.minAgeMonths);
    });

    test('copyWith with no parameters returns identical values', () {
      final copied = testTip.copyWith();

      expect(copied.id, testTip.id);
      expect(copied.title, testTip.title);
      expect(copied.content, testTip.content);
      expect(copied.category, testTip.category);
      expect(copied.priority, testTip.priority);
    });

    test('equality checks id, title, and category', () {
      final tip1 = TipModel(
        id: 'tip1',
        title: 'Safe Sleep',
        content: 'Content 1',
        category: TipCategory.safety,
        minAgeMonths: 0,
        maxAgeMonths: 12,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final tip2 = TipModel(
        id: 'tip1',
        title: 'Safe Sleep',
        content: 'Content 2',
        category: TipCategory.safety,
        minAgeMonths: 0,
        maxAgeMonths: 24,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(tip1, equals(tip2));
      expect(tip1.hashCode, equals(tip2.hashCode));
    });

    test('toString returns formatted string', () {
      final string = testTip.toString();

      expect(string, contains('TipModel'));
      expect(string, contains('tip1'));
      expect(string, contains('Safe Sleep Practices'));
      expect(string, contains('safety'));
      expect(string, contains('0-12 months'));
      expect(string, contains('urgent'));
    });
  });

  group('TipCategory', () {
    test('enum values return correct string values', () {
      expect(TipCategory.sleep.value, 'sleep');
      expect(TipCategory.feeding.value, 'feeding');
      expect(TipCategory.health.value, 'health');
      expect(TipCategory.safety.value, 'safety');
      expect(TipCategory.development.value, 'development');
      expect(TipCategory.behavior.value, 'behavior');
      expect(TipCategory.care.value, 'care');
      expect(TipCategory.bonding.value, 'bonding');
      expect(TipCategory.general.value, 'general');
    });

    test('enum display names are formatted correctly', () {
      expect(TipCategory.sleep.displayName, 'Sleep');
      expect(TipCategory.feeding.displayName, 'Feeding');
      expect(TipCategory.health.displayName, 'Health');
      expect(TipCategory.safety.displayName, 'Safety');
      expect(TipCategory.development.displayName, 'Development');
      expect(TipCategory.behavior.displayName, 'Behavior');
      expect(TipCategory.care.displayName, 'Care');
      expect(TipCategory.bonding.displayName, 'Bonding');
      expect(TipCategory.general.displayName, 'General');
    });

    test('enum icons are assigned correctly', () {
      expect(TipCategory.sleep.icon, '😴');
      expect(TipCategory.feeding.icon, '🍼');
      expect(TipCategory.health.icon, '🏥');
      expect(TipCategory.safety.icon, '🛡️');
      expect(TipCategory.development.icon, '📈');
      expect(TipCategory.behavior.icon, '🧸');
      expect(TipCategory.care.icon, '🛁');
      expect(TipCategory.bonding.icon, '💝');
      expect(TipCategory.general.icon, '💡');
    });

    test('fromString converts string to correct enum', () {
      expect(TipCategoryExtension.fromString('sleep'), TipCategory.sleep);
      expect(TipCategoryExtension.fromString('feeding'), TipCategory.feeding);
      expect(TipCategoryExtension.fromString('health'), TipCategory.health);
      expect(TipCategoryExtension.fromString('safety'), TipCategory.safety);
      expect(TipCategoryExtension.fromString('development'),
          TipCategory.development);
      expect(TipCategoryExtension.fromString('behavior'), TipCategory.behavior);
      expect(TipCategoryExtension.fromString('care'), TipCategory.care);
      expect(TipCategoryExtension.fromString('bonding'), TipCategory.bonding);
      expect(TipCategoryExtension.fromString('general'), TipCategory.general);
    });

    test('fromString is case-insensitive', () {
      expect(TipCategoryExtension.fromString('SLEEP'), TipCategory.sleep);
      expect(TipCategoryExtension.fromString('Sleep'), TipCategory.sleep);
    });

    test('fromString returns general for unknown value', () {
      expect(TipCategoryExtension.fromString('unknown'), TipCategory.general);
      expect(TipCategoryExtension.fromString(''), TipCategory.general);
    });
  });

  group('TipPriority', () {
    test('enum values return correct string values', () {
      expect(TipPriority.low.value, 'low');
      expect(TipPriority.normal.value, 'normal');
      expect(TipPriority.high.value, 'high');
      expect(TipPriority.urgent.value, 'urgent');
    });

    test('enum display names are formatted correctly', () {
      expect(TipPriority.low.displayName, 'Low');
      expect(TipPriority.normal.displayName, 'Normal');
      expect(TipPriority.high.displayName, 'High');
      expect(TipPriority.urgent.displayName, 'Urgent');
    });

    test('fromString converts string to correct enum', () {
      expect(TipPriorityExtension.fromString('low'), TipPriority.low);
      expect(TipPriorityExtension.fromString('normal'), TipPriority.normal);
      expect(TipPriorityExtension.fromString('high'), TipPriority.high);
      expect(TipPriorityExtension.fromString('urgent'), TipPriority.urgent);
    });

    test('fromString is case-insensitive', () {
      expect(TipPriorityExtension.fromString('LOW'), TipPriority.low);
      expect(TipPriorityExtension.fromString('Normal'), TipPriority.normal);
    });

    test('fromString returns normal for unknown value', () {
      expect(TipPriorityExtension.fromString('unknown'), TipPriority.normal);
      expect(TipPriorityExtension.fromString(''), TipPriority.normal);
    });
  });
}
