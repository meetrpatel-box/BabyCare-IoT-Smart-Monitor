import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/baby_provider.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/onboarding/baby_onboarding_screen.dart';
import '../screens/auth/phone_entry_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/create_pin_screen.dart';
import '../screens/auth/enter_pin_screen.dart';
import '../screens/auth/biometric_setup_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/main/dashboard_screen.dart';
import '../screens/main/trends_screen.dart';
import '../screens/main/analysis_screen.dart';
import '../screens/main/goals_screen.dart';
import '../screens/main/ai_insights_screen.dart';
import '../screens/main/sleep_analysis_screen.dart';
import '../screens/main/wifi_provisioning_screen.dart';
import '../screens/main/video_call_screen.dart';
import '../screens/main/music_player_screen.dart';
import '../screens/main/smart_tools_screen.dart';
import '../screens/photos/photo_timeline_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/add_baby_screen.dart';
import '../screens/settings/family_invite_screen.dart';
import '../screens/settings/accept_invite_screen.dart';
import '../screens/settings/scan_invite_qr_screen.dart';
import '../screens/settings/appearance_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/security_screen.dart';
import '../screens/vitals/realtime_vitals_screen.dart';
import '../screens/vitals/vitals_history_screen.dart';
import '../screens/devices/device_setup_screen.dart';
import '../screens/devices/device_discovery_screen.dart';
import '../screens/cry/cry_alert_screen.dart';
import '../screens/cry/cry_consent_screen.dart';
import '../screens/cry/cry_history_screen.dart';
import '../features/smart_tools/cry_analyzer/cry_analyzer_screen.dart';
import '../widgets/main_scaffold.dart';
import '../screens/test/webrtc_js_test_screen_stub.dart'
    if (dart.library.html) '../screens/test/webrtc_js_test_screen.dart'
    as webrtc_js_test;

/// App navigation router using go_router
/// Ported from React Native navigation structure
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static const bool _bypassAuth = false;

  static GoRouter router(AuthProvider authProvider, BabyProvider babyProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/welcome',
      refreshListenable: Listenable.merge([authProvider, babyProvider]),
      redirect: (context, state) {
        if (_bypassAuth) return null; // skip all auth guards

        final isLoading = authProvider.isLoading;
        final isAuthenticated = authProvider.isAuthenticated;
        final requiresPinEntry = authProvider.requiresPinEntry;
        final currentUser = authProvider.currentUser;
        final hasBabies = babyProvider.hasBabies;
        final babiesLoading = babyProvider.isLoading;

        final location = state.matchedLocation;

        debugPrint('🔀 Router redirect - location: $location');
        debugPrint('  isLoading: $isLoading, babiesLoading: $babiesLoading');
        debugPrint(
            '  isAuthenticated: $isAuthenticated, currentUser: ${currentUser?.email}');
        debugPrint(
            '  hasBabies: $hasBabies (${babyProvider.babies.length} babies)');
        debugPrint('  requiresPinEntry: $requiresPinEntry');

        // ── OTP flow: router drives navigation so no widget needs to be mounted ──
        // If OTP is pending and user is not yet on the OTP screen, go there now.
        final pendingOtp = authProvider.pendingVerificationId;
        if (pendingOtp != null &&
            pendingOtp.isNotEmpty &&
            location != '/auth/otp') {
          debugPrint('  🔀 Redirecting to /auth/otp (OTP pending)');
          return '/auth/otp';
        }
        // If user is on the OTP screen (verifying OTP / waiting for code), never redirect away.
        if (location == '/auth/otp') {
          debugPrint('  ✅ On OTP screen — no redirect');
          return null;
        }

        // Still loading auth or baby state - allow navigation to continue
        if (isLoading || babiesLoading) {
          debugPrint('  ⏳ Still loading, allowing navigation');
          return null;
        }

        // Auth routes — only the login/signup entry screens, NOT post-login setup screens
        // (create-pin and biometric-setup are post-login flows, not auth entry points)
        final isAuthRoute = location == '/auth/login' ||
            location == '/auth/signup' ||
            location == '/auth/phone' ||
            location == '/welcome';

        // PIN entry route
        final isPinRoute = location == '/enter-pin';

        // Onboarding route
        final isOnboardingRoute = location == '/onboarding';

        // Main app routes (inside ShellRoute)
        final isMainRoute = location == '/dashboard' ||
            location == '/trends' ||
            location == '/analysis' ||
            location == '/goals' ||
            location == '/settings' ||
            location.startsWith('/settings/');

        // No user logged in
        if (currentUser == null) {
          // Redirect to welcome if trying to access protected routes
          if (isMainRoute || isPinRoute) {
            return '/welcome';
          }
          return null;
        }

        // User logged in but needs PIN entry
        if (requiresPinEntry && !isPinRoute) {
          if (isMainRoute || isAuthRoute) {
            return '/enter-pin';
          }
        }

        // User is fully authenticated
        if (isAuthenticated) {
          // Check if user needs onboarding (no babies)
          if (!hasBabies && !isOnboardingRoute) {
            // Redirect to onboarding if trying to access main app without babies
            if (isMainRoute || isAuthRoute || isPinRoute) {
              debugPrint('  🔀 Redirecting to /onboarding (no babies)');
              return '/onboarding';
            }
          }

          // User has babies - redirect from auth/onboarding to dashboard
          if (hasBabies && (isAuthRoute || isPinRoute || isOnboardingRoute)) {
            debugPrint(
                '  🔀 Redirecting to /dashboard (has babies: ${babyProvider.babies.length})');
            return '/dashboard';
          }
        }

        debugPrint('  ✅ No redirect needed');
        return null;
      },
      routes: [
        // Welcome / Landing
        GoRoute(
          path: '/welcome',
          name: 'welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),

        // Baby Onboarding
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const BabyOnboardingScreen(),
        ),

        // Auth Routes
        GoRoute(
          path: '/auth/phone',
          name: 'phoneEntry',
          builder: (context, state) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: '/auth/otp',
          name: 'otp',
          builder: (context, state) {
            final authProvider = context.read<AuthProvider>();
            final extra = state.extra as Map<String, dynamic>?;
            // Phone number from route extra OR from AuthProvider (navigate-via-router flow)
            final phoneNumber =
                (extra?['phoneNumber'] as String?)?.isNotEmpty == true
                    ? extra!['phoneNumber'] as String
                    : authProvider.pendingPhoneNumber ?? '';
            final verificationId =
                (extra?['verificationId'] as String?)?.isNotEmpty == true
                    ? extra!['verificationId'] as String
                    : authProvider.pendingVerificationId ?? '';
            return OTPScreen(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            );
          },
        ),
        GoRoute(
          path: '/auth/create-pin',
          name: 'createPin',
          builder: (context, state) => const CreatePINScreen(),
        ),
        GoRoute(
          path: '/auth/biometric-setup',
          name: 'biometricSetup',
          builder: (context, state) => const BiometricSetupScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/signup',
          name: 'signup',
          builder: (context, state) => const SignupScreen(),
        ),

        // PIN Entry (after login)
        GoRoute(
          path: '/enter-pin',
          name: 'enterPin',
          builder: (context, state) => const EnterPINScreen(),
        ),

        // Main App Shell with Bottom Navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/trends',
              name: 'trends',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TrendsScreen(),
              ),
            ),
            GoRoute(
              path: '/analysis',
              name: 'analysis',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AnalysisScreen(),
              ),
            ),
            GoRoute(
              path: '/goals',
              name: 'goals',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: GoalsScreen(),
              ),
            ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'profile',
                  name: 'profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
                GoRoute(
                  path: 'add-baby',
                  name: 'addBaby',
                  builder: (context, state) => const AddBabyScreen(),
                ),
                GoRoute(
                  path: 'invite-family',
                  name: 'inviteFamily',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return FamilyInviteScreen(
                      familyId: extra?['familyId'] ?? '',
                      familyName: extra?['familyName'] ?? 'Family',
                    );
                  },
                ),
                GoRoute(
                  path: 'appearance',
                  name: 'appearance',
                  builder: (context, state) => const AppearanceScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  name: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'security',
                  name: 'security',
                  builder: (context, state) => const SecurityScreen(),
                ),
              ],
            ),
          ],
        ),

        // Vitals Route (can be modal or in shell)
        GoRoute(
          path: '/vitals/:babyId',
          name: 'vitals',
          builder: (context, state) {
            final babyId = state.pathParameters['babyId']!;
            return RealTimeVitalsScreen(babyId: babyId);
          },
        ),

        // Vitals History Route
        GoRoute(
          path: '/vitals-history',
          name: 'vitalsHistory',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const VitalsHistoryScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),

        // Device Setup Route
        GoRoute(
          path: '/device-setup',
          name: 'device-setup',
          builder: (context, state) => const DeviceSetupScreen(),
        ),

        // Device Discovery (MQTT scan)
        GoRoute(
          path: '/device-discovery',
          name: 'device-discovery',
          builder: (context, state) => const DeviceDiscoveryScreen(),
        ),

        // Accept Family Invite Route
        GoRoute(
          path: '/accept-invite/:inviteId',
          name: 'acceptInvite',
          builder: (context, state) {
            final inviteId = state.pathParameters['inviteId']!;
            return AcceptInviteScreen(inviteId: inviteId);
          },
        ),

        // Scan QR Code Route
        GoRoute(
          path: '/scan-invite-qr',
          name: 'scanInviteQR',
          builder: (context, state) => const ScanInviteQRScreen(),
        ),

        // Modal Routes (outside shell)
        GoRoute(
          path: '/smart-tools',
          name: 'smartTools',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SmartToolsScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        GoRoute(
          path: '/ai-insights',
          name: 'aiInsights',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const AIInsightsScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        GoRoute(
          path: '/sleep-analysis',
          name: 'sleepAnalysis',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SleepAnalysisScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        GoRoute(
          path: '/wifi-provisioning',
          name: 'wifiProvisioning',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const WiFiProvisioningScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        // Test Route - WebRTC JS Interop Test (Web only)
        if (kIsWeb)
          GoRoute(
            path: '/test/webrtc-js',
            name: 'webrtcJsTest',
            builder: (context, state) => webrtc_js_test.WebRTCJsTestScreen(),
          ),
        GoRoute(
          path: '/video-call',
          name: 'videoCall',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const VideoCallScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        GoRoute(
          path: '/music-player',
          name: 'musicPlayer',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const MusicPlayerScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),

        // Cry Alert Screen (modal slide-up)
        GoRoute(
          path: '/cry-analyzer',
          name: 'cryAnalyzer',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const CryAnalyzerScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
        GoRoute(
          path: '/cry-alert/:babyId',
          name: 'cryAlert',
          pageBuilder: (context, state) {
            final babyId = state.pathParameters['babyId'] ?? '';
            final extra = state.extra as Map<String, dynamic>?;
            return CustomTransitionPage(
              child: CryAlertScreen(
                babyId: babyId,
                babyName: extra?['babyName'] ?? 'Baby',
              ),
              transitionsBuilder: _slideUpTransition,
            );
          },
        ),

        // Cry History Screen
        GoRoute(
          path: '/cry-history/:babyId',
          name: 'cryHistory',
          pageBuilder: (context, state) {
            final babyId = state.pathParameters['babyId'] ?? '';
            final extra = state.extra as Map<String, dynamic>?;
            return CustomTransitionPage(
              child: CryHistoryScreen(
                babyId: babyId,
                babyName: extra?['babyName'] ?? 'Baby',
              ),
              transitionsBuilder: _slideUpTransition,
            );
          },
        ),

        // Cry Data Consent Screen
        GoRoute(
          path: '/cry-consent',
          name: 'cryConsent',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return CustomTransitionPage(
              child: CryConsentScreen(
                userId: extra?['userId'] ?? '',
              ),
              transitionsBuilder: _slideUpTransition,
            );
          },
        ),

        // Photo Routes
        GoRoute(
          path: '/photos/:babyId',
          name: 'photoTimeline',
          pageBuilder: (context, state) {
            final babyId = state.pathParameters['babyId'] ?? '';
            return CustomTransitionPage(
              child: PhotoTimelineScreen(babyId: babyId),
              transitionsBuilder: _slideUpTransition,
            );
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.matchedLocation}'),
        ),
      ),
    );
  }

  /// Slide up transition for modal screens
  static Widget _slideUpTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: child,
    );
  }
}

/// Route names for easy navigation
class Routes {
  Routes._();

  // Auth
  static const welcome = 'welcome';
  static const phoneEntry = 'phoneEntry';
  static const otp = 'otp';
  static const createPin = 'createPin';
  static const enterPin = 'enterPin';
  static const biometricSetup = 'biometricSetup';
  static const login = 'login';
  static const signup = 'signup';

  // Main
  static const dashboard = 'dashboard';
  static const trends = 'trends';
  static const analysis = 'analysis';
  static const goals = 'goals';
  static const settings = 'settings';

  // Settings sub-routes
  static const profile = 'profile';
  static const addBaby = 'addBaby';

  // Settings sub-routes
  static const inviteFamily = 'inviteFamily';

  // Modals
  static const aiInsights = 'aiInsights';
  static const smartTools = 'smartTools';
  static const sleepAnalysis = 'sleepAnalysis';
  static const wifiProvisioning = 'wifiProvisioning';
  static const videoCall = 'videoCall';
  static const musicPlayer = 'musicPlayer';

  // Vitals
  static const vitals = 'vitals';
  static const vitalsHistory = 'vitalsHistory';

  // Devices
  static const deviceSetup = 'device-setup';

  // Cry Detection
  static const cryAlert = 'cryAlert';
  static const cryAnalyzer = 'cryAnalyzer';
  static const cryHistory = 'cryHistory';
  static const cryConsent = 'cryConsent';

  // Photos
  static const photoTimeline = 'photoTimeline';

  // Family
  static const acceptInvite = 'acceptInvite';
  static const scanInviteQR = 'scanInviteQR';
}
