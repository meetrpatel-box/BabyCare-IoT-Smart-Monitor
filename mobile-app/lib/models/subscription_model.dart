import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription tier enum
enum SubscriptionTier {
  free('free', 'Free', null, 0, 0),
  premiumDevice('premium_device', 'Premium + Anavaya', 'anavaya_device', 199, 12.99),
  premiumPro('premium_pro', 'Premium + Anavaya Pro', 'anavaya_pro', 299, 17.99);

  final String value;
  final String displayName;
  final String? deviceType;
  final double devicePrice; // One-time hardware cost
  final double monthlyPrice; // Recurring subscription

  const SubscriptionTier(
    this.value,
    this.displayName,
    this.deviceType,
    this.devicePrice,
    this.monthlyPrice,
  );

  static SubscriptionTier fromString(String? value) {
    return SubscriptionTier.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SubscriptionTier.free,
    );
  }

  bool get isPremium => this != SubscriptionTier.free;
  bool get hasDevice => deviceType != null;
  bool get isBasicDevice => deviceType == 'anavaya_device';
  bool get isProDevice => deviceType == 'anavaya_pro';
  
  // Feature flags based on tier
  bool get hasAI => isPremium;
  bool get hasSleepAnalysis => isPremium;
  bool get hasCryDetection => isPremium;
  bool get hasPhotoVideo => isPremium;
  bool get hasAutoDetection => hasDevice;
  bool get hasTemperature => isProDevice;
  bool get hasAdvancedAnalytics => isProDevice;
}

/// Subscription model
class SubscriptionModel {
  final String userId;
  final SubscriptionTier tier;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final bool isActive;
  final String? revenueCatCustomerId;
  final String? deviceId; // Anavaya device ID (if has device)
  final String? deviceType; // anavaya_device or anavaya_pro
  final Map<String, int> quotas; // Resource limits

  SubscriptionModel({
    required this.userId,
    required this.tier,
    this.startDate,
    this.expiryDate,
    required this.isActive,
    this.revenueCatCustomerId,
    this.deviceId,
    this.deviceType,
    Map<String, int>? quotas,
  }) : quotas = quotas ?? getDefaultQuotas(tier);

  static Map<String, int> getDefaultQuotas(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return {
          'maxPhotos': 100,
          'maxStorageMB': 500, // 500 MB
          'maxBabies': 1,
          'maxAlbums': 5,
          'maxVideos': 0,
          'chartHistoryDays': 1, // Only 24h charts
        };
      case SubscriptionTier.premiumDevice:
        return {
          'maxPhotos': -1, // Unlimited
          'maxStorageMB': 20480, // 20 GB
          'maxBabies': 3,
          'maxAlbums': -1, // Unlimited
          'maxVideos': -1, // Unlimited with device
          'chartHistoryDays': 90, // 90 days history
        };
      case SubscriptionTier.premiumPro:
        return {
          'maxPhotos': -1, // Unlimited
          'maxStorageMB': 51200, // 50 GB
          'maxBabies': 5,
          'maxAlbums': -1, // Unlimited
          'maxVideos': -1, // Unlimited
          'chartHistoryDays': 365, // 1 year history
        };
    }
  }

  bool get hasPremium => tier.isPremium;
  bool get hasDevice => tier.hasDevice;
  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      userId: doc.id,
      tier: SubscriptionTier.fromString(data['tier']),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      revenueCatCustomerId: data['revenueCatCustomerId'],
      deviceId: data['deviceId'],
      deviceType: data['deviceType'],
      quotas: Map<String, int>.from(data['quotas'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tier': tier.value,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'revenueCatCustomerId': revenueCatCustomerId,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'quotas': quotas,
    };
  }

  /// Check if user can access a feature
  bool canAccess(String feature) {
    switch (feature) {
      // Free features (everyone)
      case 'manual_tracking':
      case 'basic_charts':
        return true;

      // Premium + Device features (both Anavaya & Pro)
      case 'ai_insights':
      case 'sleep_analysis':
      case 'cry_detection':
      case 'photo_storage':
      case 'video_storage':
      case 'auto_sleep_tracking':
      case 'real_time_vitals':
      case 'movement_alerts':
      case 'predictions':
      case 'advanced_charts':
        return tier.isPremium;

      // Pro-only features (Anavaya Pro)
      case 'body_temperature':
      case 'temperature_trends':
      case 'advanced_analytics':
      case 'health_predictions':
      case 'anomaly_detection':
        return tier.isProDevice;

      default:
        return false;
    }
  }

  /// Check if user has remaining quota
  bool hasQuota(String resource, int current) {
    final limit = quotas[resource] ?? 0;
    if (limit == -1) return true; // Unlimited
    return current < limit;
  }

  /// Get quota limit for resource
  int getQuotaLimit(String resource) {
    return quotas[resource] ?? 0;
  }
}

/// Feature gate result
class FeatureGateResult {
  final bool allowed;
  final String? reason;
  final SubscriptionTier? requiredTier;

  FeatureGateResult({
    required this.allowed,
    this.reason,
    this.requiredTier,
  });

  factory FeatureGateResult.allowed() {
    return FeatureGateResult(allowed: true);
  }

  factory FeatureGateResult.denied(String reason, SubscriptionTier requiredTier) {
    return FeatureGateResult(
      allowed: false,
      reason: reason,
      requiredTier: requiredTier,
    );
  }
}
