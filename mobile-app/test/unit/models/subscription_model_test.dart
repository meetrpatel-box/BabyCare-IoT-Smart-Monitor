import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/subscription_model.dart';

void main() {
  group('SubscriptionTier', () {
    test('fromString parses valid tier values', () {
      expect(
        SubscriptionTier.fromString('free'),
        equals(SubscriptionTier.free),
      );
      expect(
        SubscriptionTier.fromString('premium_device'),
        equals(SubscriptionTier.premiumDevice),
      );
      expect(
        SubscriptionTier.fromString('premium_pro'),
        equals(SubscriptionTier.premiumPro),
      );
    });

    test('fromString returns free for invalid/null values', () {
      expect(
        SubscriptionTier.fromString(null),
        equals(SubscriptionTier.free),
      );
      expect(
        SubscriptionTier.fromString('invalid'),
        equals(SubscriptionTier.free),
      );
      expect(
        SubscriptionTier.fromString(''),
        equals(SubscriptionTier.free),
      );
    });

    test('isPremium is false for free tier', () {
      expect(SubscriptionTier.free.isPremium, isFalse);
    });

    test('isPremium is true for device and pro tiers', () {
      expect(SubscriptionTier.premiumDevice.isPremium, isTrue);
      expect(SubscriptionTier.premiumPro.isPremium, isTrue);
    });

    test('isProDevice is true only for premiumPro', () {
      expect(SubscriptionTier.free.isProDevice, isFalse);
      expect(SubscriptionTier.premiumDevice.isProDevice, isFalse);
      expect(SubscriptionTier.premiumPro.isProDevice, isTrue);
    });

    test('feature flags match tier capabilities', () {
      // Free tier
      expect(SubscriptionTier.free.hasAI, isFalse);
      expect(SubscriptionTier.free.hasTemperature, isFalse);

      // Premium Device
      expect(SubscriptionTier.premiumDevice.hasAI, isTrue);
      expect(SubscriptionTier.premiumDevice.hasSleepAnalysis, isTrue);
      expect(SubscriptionTier.premiumDevice.hasCryDetection, isTrue);
      expect(SubscriptionTier.premiumDevice.hasTemperature, isFalse);
      expect(SubscriptionTier.premiumDevice.hasAdvancedAnalytics, isFalse);

      // Premium Pro
      expect(SubscriptionTier.premiumPro.hasAI, isTrue);
      expect(SubscriptionTier.premiumPro.hasTemperature, isTrue);
      expect(SubscriptionTier.premiumPro.hasAdvancedAnalytics, isTrue);
    });

    test('value property returns correct string', () {
      expect(SubscriptionTier.free.value, equals('free'));
      expect(SubscriptionTier.premiumDevice.value, equals('premium_device'));
      expect(SubscriptionTier.premiumPro.value, equals('premium_pro'));
    });
  });

  group('SubscriptionModel', () {
    group('canAccess', () {
      test('free tier can access free features', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
        );

        expect(sub.canAccess('manual_tracking'), isTrue);
        expect(sub.canAccess('basic_charts'), isTrue);
      });

      test('free tier cannot access premium features', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
        );

        expect(sub.canAccess('ai_insights'), isFalse);
        expect(sub.canAccess('sleep_analysis'), isFalse);
        expect(sub.canAccess('cry_detection'), isFalse);
        expect(sub.canAccess('real_time_vitals'), isFalse);
        expect(sub.canAccess('body_temperature'), isFalse);
      });

      test('premiumDevice tier can access premium features', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumDevice,
          isActive: true,
        );

        expect(sub.canAccess('manual_tracking'), isTrue);
        expect(sub.canAccess('ai_insights'), isTrue);
        expect(sub.canAccess('sleep_analysis'), isTrue);
        expect(sub.canAccess('cry_detection'), isTrue);
        expect(sub.canAccess('photo_storage'), isTrue);
        expect(sub.canAccess('video_storage'), isTrue);
        expect(sub.canAccess('auto_sleep_tracking'), isTrue);
        expect(sub.canAccess('real_time_vitals'), isTrue);
      });

      test('premiumDevice tier cannot access pro-only features', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumDevice,
          isActive: true,
        );

        expect(sub.canAccess('body_temperature'), isFalse);
        expect(sub.canAccess('temperature_trends'), isFalse);
        expect(sub.canAccess('advanced_analytics'), isFalse);
        expect(sub.canAccess('health_predictions'), isFalse);
        expect(sub.canAccess('anomaly_detection'), isFalse);
      });

      test('premiumPro tier can access all features', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumPro,
          isActive: true,
        );

        expect(sub.canAccess('manual_tracking'), isTrue);
        expect(sub.canAccess('ai_insights'), isTrue);
        expect(sub.canAccess('sleep_analysis'), isTrue);
        expect(sub.canAccess('body_temperature'), isTrue);
        expect(sub.canAccess('temperature_trends'), isTrue);
        expect(sub.canAccess('advanced_analytics'), isTrue);
        expect(sub.canAccess('anomaly_detection'), isTrue);
      });

      test('unknown feature returns false', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumPro,
          isActive: true,
        );

        expect(sub.canAccess('nonexistent_feature'), isFalse);
      });
    });

    group('hasQuota', () {
      test('free tier has correct default quotas', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
        );

        expect(sub.hasQuota('maxPhotos', 50), isTrue);
        expect(sub.hasQuota('maxPhotos', 99), isTrue);
        expect(sub.hasQuota('maxPhotos', 100), isFalse); // At limit
        expect(sub.hasQuota('maxPhotos', 150), isFalse); // Over limit
        expect(sub.hasQuota('maxBabies', 0), isTrue);
        expect(sub.hasQuota('maxBabies', 1), isFalse); // At limit
        expect(sub.hasQuota('maxVideos', 0), isFalse); // 0 allowed
      });

      test('premium tier has unlimited quotas (-1)', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumDevice,
          isActive: true,
        );

        // -1 means unlimited
        expect(sub.hasQuota('maxPhotos', 999999), isTrue);
        expect(sub.hasQuota('maxAlbums', 999999), isTrue);
        expect(sub.hasQuota('maxVideos', 999999), isTrue);
        expect(sub.hasQuota('maxBabies', 2), isTrue);
        expect(sub.hasQuota('maxBabies', 3), isFalse); // Limit is 3
      });

      test('unknown resource defaults to 0 quota', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
        );

        expect(sub.hasQuota('unknownResource', 0), isFalse);
      });
    });

    group('getQuotaLimit', () {
      test('returns correct limits for free tier', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
        );

        expect(sub.getQuotaLimit('maxPhotos'), equals(100));
        expect(sub.getQuotaLimit('maxStorageMB'), equals(500));
        expect(sub.getQuotaLimit('maxBabies'), equals(1));
        expect(sub.getQuotaLimit('chartHistoryDays'), equals(1));
      });

      test('returns -1 for unlimited resources on premium', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumPro,
          isActive: true,
        );

        expect(sub.getQuotaLimit('maxPhotos'), equals(-1));
        expect(sub.getQuotaLimit('maxAlbums'), equals(-1));
        expect(sub.getQuotaLimit('chartHistoryDays'), equals(365));
      });
    });

    group('isExpired', () {
      test('returns false when no expiry date', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.free,
          isActive: true,
          expiryDate: null,
        );

        expect(sub.isExpired, isFalse);
      });

      test('returns false when expiry is in the future', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumDevice,
          isActive: true,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
        );

        expect(sub.isExpired, isFalse);
      });

      test('returns true when expiry is in the past', () {
        final sub = SubscriptionModel(
          userId: 'user-1',
          tier: SubscriptionTier.premiumDevice,
          isActive: true,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(sub.isExpired, isTrue);
      });
    });

    group('getDefaultQuotas', () {
      test('returns different quotas for each tier', () {
        final freeQuotas = SubscriptionModel.getDefaultQuotas(SubscriptionTier.free);
        final deviceQuotas = SubscriptionModel.getDefaultQuotas(SubscriptionTier.premiumDevice);
        final proQuotas = SubscriptionModel.getDefaultQuotas(SubscriptionTier.premiumPro);

        // Free < Device < Pro for storage
        expect(freeQuotas['maxStorageMB']!, lessThan(deviceQuotas['maxStorageMB']!));
        expect(deviceQuotas['maxStorageMB']!, lessThan(proQuotas['maxStorageMB']!));

        // Free < Device < Pro for babies
        expect(freeQuotas['maxBabies']!, lessThan(deviceQuotas['maxBabies']!));
        expect(deviceQuotas['maxBabies']!, lessThan(proQuotas['maxBabies']!));

        // Chart history increases with tier
        expect(freeQuotas['chartHistoryDays']!, lessThan(deviceQuotas['chartHistoryDays']!));
        expect(deviceQuotas['chartHistoryDays']!, lessThan(proQuotas['chartHistoryDays']!));
      });
    });
  });

  group('FeatureGateResult', () {
    test('allowed factory creates allowed result', () {
      final result = FeatureGateResult.allowed();

      expect(result.allowed, isTrue);
      expect(result.reason, isNull);
      expect(result.requiredTier, isNull);
    });

    test('denied factory creates denied result with reason and tier', () {
      final result = FeatureGateResult.denied(
        'Upgrade required',
        SubscriptionTier.premiumDevice,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, equals('Upgrade required'));
      expect(result.requiredTier, equals(SubscriptionTier.premiumDevice));
    });
  });
}
