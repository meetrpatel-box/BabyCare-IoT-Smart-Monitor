import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';

/// Subscription & Feature Gate Service
/// Manages subscription tiers and feature access control
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user's subscription
  Future<SubscriptionModel> getUserSubscription(String userId) async {
    final doc = await _firestore.collection('subscriptions').doc(userId).get();

    if (!doc.exists) {
      // Create default free subscription
      final freeSub = SubscriptionModel(
        userId: userId,
        tier: SubscriptionTier.free,
        startDate: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('subscriptions')
          .doc(userId)
          .set(freeSub.toFirestore());

      return freeSub;
    }

    return SubscriptionModel.fromFirestore(doc);
  }

  /// Stream subscription changes
  Stream<SubscriptionModel> streamUserSubscription(String userId) {
    return _firestore
        .collection('subscriptions')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return SubscriptionModel(
          userId: userId,
          tier: SubscriptionTier.free,
          isActive: true,
        );
      }
      return SubscriptionModel.fromFirestore(doc);
    });
  }

  /// Update subscription (used during device activation or purchase)
  Future<void> updateSubscription({
    required String userId,
    required SubscriptionTier tier,
    String? deviceId,
    String? deviceType,
    String? revenueCatCustomerId,
  }) async {
    final now = DateTime.now();
    final expiryDate = tier == SubscriptionTier.free
        ? null
        : now.add(const Duration(days: 30)); // Monthly subscription

    await _firestore.collection('subscriptions').doc(userId).set({
      'userId': userId,
      'tier': tier.value,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'startDate': Timestamp.fromDate(now),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'isActive': true,
      'revenueCatCustomerId': revenueCatCustomerId,
      'quotas': SubscriptionModel.getDefaultQuotas(tier),
    }, SetOptions(merge: true));
  }

  /// Check if user can access a feature
  Future<FeatureGateResult> canAccessFeature(
    String userId,
    String feature,
  ) async {
    final subscription = await getUserSubscription(userId);

    // Check if subscription is active
    if (!subscription.isActive) {
      return FeatureGateResult.denied(
        'Your subscription has expired',
        SubscriptionTier.premiumDevice,
      );
    }

    if (subscription.isExpired) {
      return FeatureGateResult.denied(
        'Your subscription has expired',
        SubscriptionTier.premiumDevice,
      );
    }

    // Check feature access
    if (!subscription.canAccess(feature)) {
      final requiredTier = _getRequiredTier(feature);
      return FeatureGateResult.denied(
        _getUpgradeMessage(feature, requiredTier),
        requiredTier,
      );
    }

    return FeatureGateResult.allowed();
  }

  /// Link device to subscription
  Future<void> linkDevice(String userId, String deviceId, String deviceType) async {
    // Determine tier based on device type
    SubscriptionTier newTier;
    if (deviceType == 'anavaya_device') {
      newTier = SubscriptionTier.premiumDevice;
    } else if (deviceType == 'anavaya_pro') {
      newTier = SubscriptionTier.premiumPro;
    } else {
      throw Exception('Unknown device type: $deviceType. Expected: anavaya_device or anavaya_pro');
    }

    await _firestore.collection('subscriptions').doc(userId).update({
      'deviceId': deviceId,
      'deviceType': deviceType,
      'tier': newTier.value,
      'quotas': SubscriptionModel.getDefaultQuotas(newTier),
    });
  }

  /// Unlink device (user sold/returned device)
  Future<void> unlinkDevice(String userId) async {
    // Without device, downgrade to free tier
    await _firestore.collection('subscriptions').doc(userId).update({
      'deviceId': null,
      'deviceType': null,
      'tier': SubscriptionTier.free.value,
      'quotas': SubscriptionModel.getDefaultQuotas(SubscriptionTier.free),
    });
  }

  /// Upgrade from Anavaya Basic to Anavaya Pro
  Future<void> upgradeToProDevice(String userId, String newDeviceId) async {
    await _firestore.collection('subscriptions').doc(userId).update({
      'deviceId': newDeviceId,
      'deviceType': 'anavaya_pro',
      'tier': SubscriptionTier.premiumPro.value,
      'quotas': SubscriptionModel.getDefaultQuotas(SubscriptionTier.premiumPro),
    });
  }

  /// Check quota limit
  Future<bool> checkQuota(
    String userId,
    String resource,
    int current,
  ) async {
    final subscription = await getUserSubscription(userId);
    return subscription.hasQuota(resource, current);
  }

  /// Get upgrade message for feature
  String _getUpgradeMessage(String feature, SubscriptionTier requiredTier) {
    switch (requiredTier) {
      case SubscriptionTier.premiumPro:
        return 'This feature requires Anavaya Pro with body temperature monitoring and advanced analytics. Upgrade your device to unlock.';
      case SubscriptionTier.premiumDevice:
        return 'This feature requires an Anavaya device. Get automatic sleep tracking, AI insights, cry detection, and real-time vitals.';
      default:
        return 'This feature is not available on your current plan.';
    }
  }

  /// Get required tier for feature
  SubscriptionTier _getRequiredTier(String feature) {
    const proOnlyFeatures = {
      'body_temperature',
      'temperature_trends',
      'advanced_analytics',
      'health_predictions',
      'anomaly_detection',
    };

    const premiumDeviceFeatures = {
      'ai_insights',
      'sleep_analysis',
      'cry_detection',
      'photo_storage',
      'video_storage',
      'auto_sleep_tracking',
      'real_time_vitals',
      'movement_alerts',
      'predictions',
      'advanced_charts',
    };

    if (proOnlyFeatures.contains(feature)) {
      return SubscriptionTier.premiumPro;
    } else if (premiumDeviceFeatures.contains(feature)) {
      return SubscriptionTier.premiumDevice;
    }

    return SubscriptionTier.free;
  }
}
