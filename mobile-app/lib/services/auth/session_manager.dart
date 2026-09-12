import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../storage/secure_storage_service.dart';

/// Manages session metadata persistence and proactive token refresh.
///
/// Firebase handles auth state persistence and token refresh automatically.
/// This class provides:
/// - Additional session metadata storage (login method, last token, expiry)
/// - A 50-minute proactive refresh timer as an extra safety net
/// - Clean session cleanup on logout
///
/// It does NOT sign out from Firebase — that is AuthProvider's responsibility.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService _storage = SecureStorageService.instance;

  Timer? _refreshTimer;

  // ── Token refresh ────────────────────────────────────────────────────────────

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    // Refresh 10 minutes before the 60-minute Firebase token expiry
    _refreshTimer = Timer.periodic(const Duration(minutes: 50), (_) {
      _refreshToken().catchError((e) => debugPrint('Token refresh error: $e'));
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdToken(true);
      if (token != null) {
        await _storage.saveAccessToken(token);
        await _storage.saveTokenExpiry(
          DateTime.now().add(const Duration(hours: 1)),
        );
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }
  }

  // ── Session persistence ──────────────────────────────────────────────────────

  Future<void> saveSession({
    required User user,
    required String loginMethod,
  }) async {
    try {
      final token = await user.getIdToken();
      if (token == null) return;

      await _storage.saveSession(
        accessToken: token,
        refreshToken: user.refreshToken ?? '',
        userId: user.uid,
        email: user.email ?? '',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        loginMethod: loginMethod,
      );
    } catch (e) {
      debugPrint('Save session error: $e');
    }
  }

  /// Clears stored session metadata and stops the refresh timer.
  /// Does NOT sign out from Firebase — the caller is responsible for that.
  Future<void> clearSession() async {
    stopAutoRefresh();
    try {
      await _storage.clearSession();
    } catch (e) {
      debugPrint('Clear session error: $e');
    }
  }

  Future<SessionStatus> getSessionStatus() async {
    try {
      final hasSession = await _storage.hasActiveSession();
      if (!hasSession) return SessionStatus.noSession;

      final session = await _storage.getSession();
      if (session == null) return SessionStatus.noSession;

      if (!session.hasValidToken) return SessionStatus.expired;
      if (session.needsRefresh) return SessionStatus.needsRefresh;

      return SessionStatus.active;
    } catch (e) {
      return SessionStatus.error;
    }
  }

  void dispose() => stopAutoRefresh();
}

enum SessionStatus { noSession, active, expired, needsRefresh, error }
