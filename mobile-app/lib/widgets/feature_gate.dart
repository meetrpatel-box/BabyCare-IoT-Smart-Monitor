import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_colors.dart';

/// Feature Gate Widget
/// Wraps features and shows upgrade prompt if user lacks access
class FeatureGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? fallback;
  final bool showUpgradePrompt;

  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final canAccess = subscriptionProvider.canAccessCached(feature);

    if (canAccess) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (!showUpgradePrompt) {
      return const SizedBox.shrink();
    }

    return _UpgradePromptWidget(feature: feature);
  }
}

/// Upgrade prompt overlay
class _UpgradePromptWidget extends StatelessWidget {
  final String feature;

  const _UpgradePromptWidget({required this.feature});

  @override
  Widget build(BuildContext context) {
    final requiredTier = _getRequiredTier(feature);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getTierIcon(requiredTier),
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _getTierTitle(requiredTier),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getUpgradeMessage(feature, requiredTier),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.foregroundSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Navigate to upgrade screen
              Navigator.of(context).pushNamed('/upgrade', arguments: requiredTier);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _getUpgradeButtonText(requiredTier),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTierIcon(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premiumPro:
        return Icons.thermostat;
      case SubscriptionTier.premiumDevice:
        return Icons.sensors;
      default:
        return Icons.lock;
    }
  }

  String _getTierTitle(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premiumPro:
        return 'Anavaya Pro Required';
      case SubscriptionTier.premiumDevice:
        return 'Anavaya Device Required';
      default:
        return 'Upgrade Required';
    }
  }

  SubscriptionTier _getRequiredTier(String feature) {
    const proOnlyFeatures = {
      'body_temperature',
      'temperature_trends',
      'advanced_analytics',
      'health_predictions',
      'anomaly_detection',
    };

    if (proOnlyFeatures.contains(feature)) {
      return SubscriptionTier.premiumPro;
    }
    
    // All other premium features require at least basic device
    return SubscriptionTier.premiumDevice;
  }

  String _getUpgradeMessage(String feature, SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premiumPro:
        return 'Get Anavaya Pro with body temperature monitoring, advanced analytics, and health predictions.';
      case SubscriptionTier.premiumDevice:
        return 'Get Anavaya with AI-powered sleep analysis, cry detection, automatic tracking, and real-time vitals.';
      default:
        return 'Upgrade to unlock this feature.';
    }
  }

  String _getUpgradeButtonText(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premiumPro:
        return 'Get Anavaya Pro';
      case SubscriptionTier.premiumDevice:
        return 'Get Anavaya Device';
      default:
        return 'Upgrade Now';
    }
  }
}

/// Quota Gate Widget
/// Shows upgrade prompt when quota is exceeded
class QuotaGate extends StatelessWidget {
  final String resource;
  final int current;
  final Widget child;
  final VoidCallback? onQuotaExceeded;

  const QuotaGate({
    super.key,
    required this.resource,
    required this.current,
    required this.child,
    this.onQuotaExceeded,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final hasQuota = subscriptionProvider.hasQuotaCached(resource, current);

    if (hasQuota) {
      return child;
    }

    return _QuotaExceededWidget(
      resource: resource,
      limit: subscriptionProvider.getQuotaLimit(resource),
      onUpgrade: onQuotaExceeded,
    );
  }
}

/// Quota exceeded prompt
class _QuotaExceededWidget extends StatelessWidget {
  final String resource;
  final int limit;
  final VoidCallback? onUpgrade;

  const _QuotaExceededWidget({
    required this.resource,
    required this.limit,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            'Quota Limit Reached',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve reached your limit of $limit ${_getResourceName(resource)}. Get an Anavaya device for unlimited access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.foregroundSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onUpgrade ??
                () {
                  Navigator.of(context).pushNamed('/upgrade');
                },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Get Anavaya Device'),
          ),
        ],
      ),
    );
  }

  String _getResourceName(String resource) {
    switch (resource) {
      case 'maxPhotos':
        return 'photos';
      case 'maxBabies':
        return 'babies';
      case 'maxAlbums':
        return 'albums';
      case 'maxVideos':
        return 'videos';
      default:
        return resource;
    }
  }
}
