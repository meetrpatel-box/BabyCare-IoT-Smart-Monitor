import 'package:flutter/material.dart';
import '../screens/activation/device_activation_screen.dart';
import '../screens/main/smart_tools_screen.dart';
import '../features/smart_tools/cry_analyzer/cry_analyzer_screen.dart';

/// App Routes - Deep link path constants
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String smartTools = '/smart-tools';
  static const String cryAnalyzer = '/cry-analyzer';

  // Device activation
  static const String deviceActivation = '/device-activation';
  static const String deviceProvisioning = '/device-provisioning';

  // Baby tracking
  static const String sleepTracking = '/sleep';
  static const String feeding = '/feeding';
  static const String diaper = '/diaper';
  static const String growth = '/growth';

  // AI features (Premium only)
  static const String aiInsights = '/ai-insights';
  static const String sleepAnalysis = '/sleep-analysis';
  static const String cryDetection = '/cry-detection';
  static const String photoAlbum = '/photos';

  // Temperature (Pro only)
  static const String temperature = '/temperature';
  static const String healthPredictions = '/health-predictions';

  // Settings
  static const String settings = '/settings';
  static const String subscription = '/subscription';
  static const String upgrade = '/upgrade';

  /// Generate route from deep link
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    // Handle deep links like: anavaya://activate?device=ANVAYA-PRO-12345
    final uri = Uri.parse(settings.name ?? '/');

    switch (uri.path) {
      case '/activate':
        return MaterialPageRoute(
          builder: (_) => const DeviceActivationScreen(),
          settings: settings,
        );
      case smartTools:
        return MaterialPageRoute(
          builder: (_) => const SmartToolsScreen(),
          settings: settings,
        );
      case cryAnalyzer:
        return MaterialPageRoute(
          builder: (_) => const CryAnalyzerScreen(),
          settings: settings,
        );

      default:
        return null;
    }
  }
}
