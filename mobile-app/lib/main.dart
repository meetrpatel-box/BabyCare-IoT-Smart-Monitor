import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/firebase_options.dart';
import 'theme/design_tokens.dart';
import 'config/firebase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/baby_provider.dart';
import 'providers/device_provider.dart';
import 'providers/photo_provider.dart';
import 'providers/milestone_provider.dart';
import 'providers/tip_provider.dart';
import 'providers/permission_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/mqtt_provider.dart';
import 'providers/theme_provider.dart';
import 'services/video_call_service.dart';
import 'services/device_control_service.dart';
import 'services/webrtc_service.dart';
import 'services/webrtc_js_service.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/shared_preferences_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run SharedPrefsHelper in background — only needed for cry history, not auth
  SharedPrefsHelper.initialize().ignore();

  FirebaseConfig.connectToEmulators();

  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  runApp(const BabyTrackApp());
}

class BabyTrackApp extends StatefulWidget {
  const BabyTrackApp({super.key});

  @override
  State<BabyTrackApp> createState() => _BabyTrackAppState();
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignTokens.primaryTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.child_care,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'BabyTrack',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(DesignTokens.primaryTeal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyTrackAppState extends State<BabyTrackApp> {
  // Create providers once
  final _authProvider = AuthProvider();
  final _babyProvider = BabyProvider();
  final _themeProvider = ThemeProvider();
  final _deviceProvider = DeviceProvider();
  final _photoProvider = PhotoProvider();
  final _milestoneProvider = MilestoneProvider();
  final _tipProvider = TipProvider();
  final _permissionProvider = PermissionProvider();
  final _subscriptionProvider = SubscriptionProvider();
  final _videoCallService = VideoCallService();
  final _deviceControlService = DeviceControlService();
  final _deviceMqttProvider = DeviceMqttProvider();
  final _webrtcService = WebRTCService();
  final _webrtcJsService = WebRTCJsService();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Map<String, dynamic>>? _alertSub;

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create router once with the same provider instances
    _router = AppRouter.router(_authProvider, _babyProvider);

    // Set callback for when user is loaded - load babies immediately
    _authProvider.setOnUserLoaded(() {
      _loadBabiesIfNeeded();
    });

    // Also listen to auth changes
    _authProvider.addListener(_onAuthChanged);

    // Connect to MQTT broker so device/vitals features work on app start
    _deviceMqttProvider.initialize();

    // Listen to real-time IoT alerts (cry detection, etc.)
    _alertSub = _deviceMqttProvider.cryAlertStream.listen((alert) {
      _handleCryAlert(alert);
    });
  }

  void _handleCryAlert(Map<String, dynamic> alert) {
    debugPrint('🚨 [AppAlert] Incoming cry alert: $alert');
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), () {
        HapticFeedback.vibrate();
      });
    } catch (_) {}

    final deviceId = alert['deviceId'] ?? 'ESP32';
    final intensity = alert['intensity'];
    final intensityPct = intensity is num ? (intensity * 100).round() : 85;

    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 10),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.child_care_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🚨 Baby is Crying!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Detected from $deviceId ($intensityPct% intensity)',
                        style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OPEN ANALYZER',
            textColor: Colors.amberAccent,
            onPressed: () {
              _router.push('/cry-analyzer');
            },
          ),
        ),
      );
    }
  }

  void _loadBabiesIfNeeded() {
    final user = _authProvider.firestoreUser;
    final isAuthenticated = _authProvider.isAuthenticated;

    debugPrint('🔍 _loadBabiesIfNeeded called');
    debugPrint('  isAuthenticated: $isAuthenticated');
    debugPrint('  user: ${user?.email}');
    debugPrint('  familyIds: ${user?.familyIds}');
    debugPrint('  babies.isEmpty: ${_babyProvider.babies.isEmpty}');
    debugPrint('  babies.length: ${_babyProvider.babies.length}');

    // Load babies when user is authenticated and has a family
    if (isAuthenticated && user != null && user.familyIds.isNotEmpty) {
      if (_babyProvider.babies.isEmpty) {
        debugPrint('  ✅ Loading babies for family: ${user.familyIds.first}');
        _babyProvider.loadBabiesForFamily(user.familyIds.first);
      } else {
        debugPrint('  ℹ️ Babies already loaded, skipping');
      }
    } else {
      debugPrint('  ⚠️ Conditions not met for loading babies');
    }
  }

  void _onAuthChanged() {
    _loadBabiesIfNeeded();
  }

  @override
  void dispose() {
    // Remove listener
    _authProvider.removeListener(_onAuthChanged);

    // Clean up providers
    _authProvider.dispose();
    _babyProvider.dispose();
    _themeProvider.dispose();
    _deviceProvider.dispose();
    _photoProvider.dispose();
    _milestoneProvider.dispose();
    _tipProvider.dispose();
    _permissionProvider.dispose();
    _subscriptionProvider.dispose();
    _videoCallService.dispose();
    _deviceControlService.dispose();
    _deviceMqttProvider.dispose();
    _webrtcService.dispose();
    _webrtcJsService.dispose();
    _alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _babyProvider),
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider.value(value: _deviceProvider),
        ChangeNotifierProvider.value(value: _photoProvider),
        ChangeNotifierProvider.value(value: _milestoneProvider),
        ChangeNotifierProvider.value(value: _tipProvider),
        ChangeNotifierProvider.value(value: _permissionProvider),
        ChangeNotifierProvider.value(value: _subscriptionProvider),
        ChangeNotifierProvider.value(value: _videoCallService),
        ChangeNotifierProvider.value(value: _deviceControlService),
        ChangeNotifierProvider.value(value: _deviceMqttProvider),
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _webrtcJsService),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          if (authProvider.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: const _SplashScreen(),
            );
          }

          return MaterialApp.router(
            scaffoldMessengerKey: _scaffoldMessengerKey,
            title: 'BabyTrack Monitor',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
