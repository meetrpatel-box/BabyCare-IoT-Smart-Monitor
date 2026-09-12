import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'dart:async';

/// Subscription state provider
class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  SubscriptionModel? _subscription;
  bool _isLoading = false;
  StreamSubscription<SubscriptionModel>? _subscriptionStream;

  SubscriptionModel? get subscription => _subscription;
  bool get isLoading => _isLoading;
  bool get hasPremium => _subscription?.tier.isPremium ?? false;
  bool get hasDevice => _subscription?.tier.hasDevice ?? false;
  bool get isBasicDevice => _subscription?.tier.isBasicDevice ?? false;
  bool get isProDevice => _subscription?.tier.isProDevice ?? false;
  SubscriptionTier get tier => _subscription?.tier ?? SubscriptionTier.free;
  String? get deviceId => _subscription?.deviceId;
  String? get deviceType => _subscription?.deviceType;
  
  // Feature access shortcuts
  bool get hasAI => _subscription?.tier.hasAI ?? false;
  bool get hasSleepAnalysis => _subscription?.tier.hasSleepAnalysis ?? false;
  bool get hasCryDetection => _subscription?.tier.hasCryDetection ?? false;
  bool get hasTemperature => _subscription?.tier.hasTemperature ?? false;
  bool get hasAdvancedAnalytics => _subscription?.tier.hasAdvancedAnalytics ?? false;

  /// Load user subscription
  Future<void> loadSubscription(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _subscription = await _subscriptionService.getUserSubscription(userId);
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      // Default to free tier on error
      _subscription = SubscriptionModel(
        userId: userId,
        tier: SubscriptionTier.free,
        isActive: true,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to subscription changes
  void subscribeToSubscription(String userId) {
    _subscriptionStream?.cancel();
    _subscriptionStream = _subscriptionService
        .streamUserSubscription(userId)
        .listen((subscription) {
      _subscription = subscription;
      notifyListeners();
    });
  }

  /// Unsubscribe from updates
  void unsubscribe() {
    _subscriptionStream?.cancel();
    _subscriptionStream = null;
  }

  /// Check if user can access feature
  Future<FeatureGateResult> canAccessFeature(
    String userId,
    String feature,
  ) async {
    return await _subscriptionService.canAccessFeature(userId, feature);
  }

  /// Check quota availability
  Future<bool> checkQuota(String userId, String resource, int current) async {
    return await _subscriptionService.checkQuota(userId, resource, current);
  }

  /// Get quota limit
  int getQuotaLimit(String resource) {
    return _subscription?.getQuotaLimit(resource) ?? 0;
  }

  /// Quick feature checks (use cached subscription)
  bool canAccessCached(String feature) {
    return _subscription?.canAccess(feature) ?? false;
  }

  bool hasQuotaCached(String resource, int current) {
    return _subscription?.hasQuota(resource, current) ?? false;
  }

  @override
  void dispose() {
    _subscriptionStream?.cancel();
    super.dispose();
  }
}
