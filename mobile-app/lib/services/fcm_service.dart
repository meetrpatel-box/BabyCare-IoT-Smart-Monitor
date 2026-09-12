import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM Push Notification Service — manages FCM token lifecycle and
/// handles incoming push notifications for cry detection alerts.
///
/// Responsibilities:
/// 1. Request notification permissions on first launch
/// 2. Register/refresh FCM tokens in Firestore (users/{userId}.fcmTokens)
/// 3. Handle foreground, background, and terminated-state notifications
/// 4. Parse cry detection payloads and provide navigation callbacks
///
/// Cloud Functions that send notifications:
///   - onCryEventCreated: Tier 1 "Baby is crying!" (data.type = 'cry_detection')
///   - onCryClassified: Tier 3 "Confirmed: Hungry" (data.type = 'cry_classification')
class FcmService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  final StreamController<CryNotification> _notificationController =
      StreamController<CryNotification>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _currentUserId;
  String? _currentToken;

  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of parsed cry notifications (for UI consumption).
  Stream<CryNotification> get notificationStream =>
      _notificationController.stream;

  /// The current FCM token (null if not yet registered).
  String? get currentToken => _currentToken;

  // ============================================================
  // Initialization
  // ============================================================

  /// Initialize FCM: request permissions, register token, set up listeners.
  ///
  /// Call this after user authentication completes.
  Future<void> initialize({required String userId}) async {
    _currentUserId = userId;

    // 1. Request permission
    await requestPermission();

    // 2. Get and register token
    await _registerToken();

    // 3. Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _handleTokenRefresh(newToken);
    });

    // 4. Listen for foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handle notification taps (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Check if app was launched from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permission from the user.
  ///
  /// Returns the authorization status.
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // Important for baby safety alerts
    );

    return settings.authorizationStatus;
  }

  // ============================================================
  // Token Management
  // ============================================================

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || _currentUserId == null) return;

      _currentToken = token;
      await _saveTokenToFirestore(token);
    } catch (_) {
      // Token registration can fail if permissions denied
    }
  }

  void _handleTokenRefresh(String newToken) {
    final oldToken = _currentToken;
    _currentToken = newToken;

    if (_currentUserId != null) {
      // Remove old token, add new one
      if (oldToken != null) {
        _removeTokenFromFirestore(oldToken);
      }
      _saveTokenToFirestore(newToken);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    if (_currentUserId == null) return;

    await _firestore.collection('users').doc(_currentUserId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _removeTokenFromFirestore(String token) async {
    if (_currentUserId == null) return;

    await _firestore.collection('users').doc(_currentUserId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  /// Remove current token from Firestore (call on logout).
  Future<void> unregisterToken() async {
    if (_currentToken != null) {
      await _removeTokenFromFirestore(_currentToken!);
    }
    _currentToken = null;
  }

  // ============================================================
  // Message Handling
  // ============================================================

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = _parseMessage(message);
    if (notification != null) {
      _notificationController.add(notification);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final notification = _parseMessage(message);
    if (notification != null) {
      _notificationController.add(notification.copyWith(tapped: true));
    }
  }

  /// Parse a RemoteMessage into a CryNotification.
  ///
  /// Returns null if the message is not a cry-related notification.
  CryNotification? _parseMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type != 'cry_detection' && type != 'cry_classification') {
      return null;
    }

    return CryNotification(
      type: type == 'cry_detection'
          ? CryNotificationType.detection
          : CryNotificationType.classification,
      babyId: data['babyId'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      tier: data['tier'] as String? ?? 'detection',
      classification: data['classification'] as String?,
      confidence: data['confidence'] != null
          ? double.tryParse(data['confidence'] as String)
          : null,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      tapped: false,
    );
  }

  // ============================================================
  // Android Notification Channel
  // ============================================================

  /// Set up foreground notification presentation for cry alerts.
  ///
  /// Call once during app initialization (before any notifications arrive).
  /// The Android notification channel 'cry_alerts' is created automatically
  /// by FCM when the first notification with that channel ID arrives,
  /// matching the channelId sent by pushNotifications.ts Cloud Function.
  Future<void> setupAndroidChannel() async {
    await _messaging
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ============================================================
  // Topic Subscriptions
  // ============================================================

  /// Subscribe to cry alerts for a specific baby.
  Future<void> subscribeToBaby(String babyId) async {
    await _messaging.subscribeToTopic('baby_$babyId');
  }

  /// Unsubscribe from cry alerts for a specific baby.
  Future<void> unsubscribeFromBaby(String babyId) async {
    await _messaging.unsubscribeFromTopic('baby_$babyId');
  }

  /// Dispose of resources.
  void dispose() {
    _foregroundSub?.cancel();
    _notificationController.close();
  }
}

// ============================================================
// Data Classes
// ============================================================

enum CryNotificationType {
  /// Tier 1: Baby is crying (from onCryEventCreated)
  detection,

  /// Tier 3: Classification result (from onCryClassified)
  classification,
}

/// Parsed cry notification from FCM push message.
class CryNotification {
  final CryNotificationType type;
  final String babyId;
  final String eventId;
  final String tier;
  final String? classification;
  final double? confidence;
  final String title;
  final String body;

  /// Whether user tapped the notification (triggers navigation).
  final bool tapped;

  const CryNotification({
    required this.type,
    required this.babyId,
    required this.eventId,
    required this.tier,
    this.classification,
    this.confidence,
    required this.title,
    required this.body,
    this.tapped = false,
  });

  CryNotification copyWith({bool? tapped}) {
    return CryNotification(
      type: type,
      babyId: babyId,
      eventId: eventId,
      tier: tier,
      classification: classification,
      confidence: confidence,
      title: title,
      body: body,
      tapped: tapped ?? this.tapped,
    );
  }

  /// Route path for deep linking to the cry alert screen.
  String get routePath => '/cry-alert/$babyId';
}

/// Background message handler — must be a top-level function.
///
/// Register this in main.dart:
///   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handling is minimal — the notification is shown by the OS.
  // When the user taps it, onMessageOpenedApp fires and we navigate.
  //
  // If you need to do background processing (e.g., update local DB),
  // add it here. Note: this runs in a separate isolate.
}
