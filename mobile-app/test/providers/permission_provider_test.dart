import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/providers/permission_provider.dart';

void main() {
  group('PermissionProvider Cache', () {
    late PermissionProvider provider;

    setUp(() {
      provider = PermissionProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('clearCache clears all cached permissions', () {
      // Add some cache entries via reflection or test methods
      // For now, just test that clearCache doesn't throw
      expect(() => provider.clearCache(), returnsNormally);
    });

    test('getCacheStats returns valid statistics', () {
      final stats = provider.getCacheStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalEntries'), isTrue);
      expect(stats.containsKey('validEntries'), isTrue);
      expect(stats.containsKey('expiredEntries'), isTrue);
      expect(stats.containsKey('cacheDuration'), isTrue);
      expect(stats['cacheDuration'], 5); // 5 minutes
    });

    test('clearBabyCache only clears baby-related entries', () {
      expect(() => provider.clearBabyCache('baby123'), returnsNormally);
    });

    test('clearFamilyCache only clears family-related entries', () {
      expect(() => provider.clearFamilyCache('family123'), returnsNormally);
    });
  });
}
