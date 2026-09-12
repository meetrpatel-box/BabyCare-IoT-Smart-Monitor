import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service - Encrypted local storage for sensitive data
///
/// Used for:
/// - Auth tokens (access, refresh)
/// - User session data
/// - Biometric credentials
///
/// Platform Security:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (AES encryption)
/// - Web: localStorage (fallback, less secure)
/// - Windows: Windows Credential Store
///
/// Note: Web platform has limited secure storage support.
/// Auto-login is disabled on web for security.
class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'BabyTrackSecureStorage',
      publicKey: 'BabyTrackPublicKey',
    ),
  );

  // Storage Keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyTokenExpiry = 'token_expiry';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastLoginMethod = 'last_login_method';

  // ============================================================================
  // AUTH TOKENS
  // ============================================================================

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Save token expiry timestamp
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _storage.write(
      key: _keyTokenExpiry,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  /// Get token expiry timestamp
  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _storage.read(key: _keyTokenExpiry);
    if (expiryStr != null) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
    }
    return null;
  }

  /// Check if access token is expired
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  // ============================================================================
  // USER SESSION DATA
  // ============================================================================

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Save user email
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  /// Get user email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Save last login method (google, phone, email)
  Future<void> saveLastLoginMethod(String method) async {
    await _storage.write(key: _keyLastLoginMethod, value: method);
  }

  /// Get last login method
  Future<String?> getLastLoginMethod() async {
    return await _storage.read(key: _keyLastLoginMethod);
  }

  // ============================================================================
  // BIOMETRIC SETTINGS
  // ============================================================================

  /// Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
  }

  /// Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================

  /// Save complete session data
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    required DateTime tokenExpiry,
    String? loginMethod,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
      saveUserEmail(email),
      saveTokenExpiry(tokenExpiry),
      if (loginMethod != null) saveLastLoginMethod(loginMethod),
    ]);
  }

  /// Check if user has active session
  /// On web, always returns false to disable auto-login for security
  Future<bool> hasActiveSession() async {
    // Disable auto-login on web due to storage limitations
    if (kIsWeb) return false;

    try {
      final userId = await getUserId();
      final refreshToken = await getRefreshToken();
      return userId != null && refreshToken != null;
    } catch (e) {
      // Storage error (likely web platform issue)
      return false;
    }
  }

  /// Get session data
  /// Returns null on web to disable auto-login
  Future<SessionData?> getSession() async {
    // Disable auto-login on web due to storage limitations
    if (kIsWeb) return null;

    try {
      final userId = await getUserId();
      final email = await getUserEmail();
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      final tokenExpiry = await getTokenExpiry();
      final loginMethod = await getLastLoginMethod();

      if (userId == null || refreshToken == null) {
        return null;
      }

      return SessionData(
        userId: userId,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
        loginMethod: loginMethod,
      );
    } catch (e) {
      // Storage error (likely web platform issue)
      return null;
    }
  }

  /// Clear session (logout)
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyUserEmail),
      _storage.delete(key: _keyTokenExpiry),
      _storage.delete(key: _keyLastLoginMethod),
    ]);
  }

  /// Clear all data (complete reset)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ============================================================================
  // CUSTOM KEY-VALUE STORAGE
  // ============================================================================

  /// Write custom secure value
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read custom secure value
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete custom value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

/// Session Data Model
class SessionData {
  final String userId;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiry;
  final String? loginMethod;

  SessionData({
    required this.userId,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiry,
    this.loginMethod,
  });

  bool get hasValidToken {
    if (accessToken == null || tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  bool get needsRefresh {
    if (tokenExpiry == null) return false;
    // Refresh if token expires in less than 5 minutes
    final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
    return tokenExpiry!.isBefore(fiveMinutesFromNow);
  }
}
