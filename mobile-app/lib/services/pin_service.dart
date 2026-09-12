import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN authentication service
/// Ported from React Native pinService.ts
class PinService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'user_pin_hash';
  static const _failedAttemptsKey = 'pin_failed_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until';
  static const _maxFailedAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 5);

  /// Hash PIN with SHA256 and user ID as salt
  static String _hashPin(String pin, String userId) {
    final bytes = utf8.encode('$pin:$userId');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Store PIN (hashed)
  static Future<void> storePin(String pin, String userId) async {
    final hash = _hashPin(pin, userId);
    await _storage.write(key: '$_pinKey:$userId', value: hash);
    // Reset failed attempts on new PIN
    await _storage.delete(key: '$_failedAttemptsKey:$userId');
    await _storage.delete(key: '$_lockoutUntilKey:$userId');
  }

  /// Verify PIN
  static Future<PinVerificationResult> verifyPin(
    String pin,
    String userId,
  ) async {
    // Check if locked out
    final lockoutResult = await _checkLockout(userId);
    if (lockoutResult != null) {
      return lockoutResult;
    }

    final storedHash = await _storage.read(key: '$_pinKey:$userId');
    if (storedHash == null) {
      return PinVerificationResult(
        success: false,
        error: 'No PIN set up',
      );
    }

    final inputHash = _hashPin(pin, userId);
    final isValid = storedHash == inputHash;

    if (isValid) {
      // Reset failed attempts on success
      await _storage.delete(key: '$_failedAttemptsKey:$userId');
      await _storage.delete(key: '$_lockoutUntilKey:$userId');
      return PinVerificationResult(success: true);
    } else {
      // Increment failed attempts
      final failedAttempts = await _incrementFailedAttempts(userId);
      final remainingAttempts = _maxFailedAttempts - failedAttempts;

      if (remainingAttempts <= 0) {
        // Set lockout
        final lockoutUntil = DateTime.now().add(_lockoutDuration);
        await _storage.write(
          key: '$_lockoutUntilKey:$userId',
          value: lockoutUntil.toIso8601String(),
        );
        return PinVerificationResult(
          success: false,
          error: 'Too many failed attempts. Try again in 5 minutes.',
          isLockedOut: true,
          lockoutUntil: lockoutUntil,
        );
      }

      return PinVerificationResult(
        success: false,
        error: 'Incorrect PIN. $remainingAttempts attempts remaining.',
        remainingAttempts: remainingAttempts,
      );
    }
  }

  /// Check if PIN is set up
  static Future<bool> hasPinSetup(String userId) async {
    final storedHash = await _storage.read(key: '$_pinKey:$userId');
    return storedHash != null;
  }

  /// Clear PIN
  static Future<void> clearPin(String userId) async {
    await _storage.delete(key: '$_pinKey:$userId');
    await _storage.delete(key: '$_failedAttemptsKey:$userId');
    await _storage.delete(key: '$_lockoutUntilKey:$userId');
  }

  /// Check lockout status
  static Future<PinVerificationResult?> _checkLockout(String userId) async {
    final lockoutStr = await _storage.read(key: '$_lockoutUntilKey:$userId');
    if (lockoutStr == null) return null;

    final lockoutUntil = DateTime.parse(lockoutStr);
    if (DateTime.now().isBefore(lockoutUntil)) {
      return PinVerificationResult(
        success: false,
        error: 'Account locked. Try again later.',
        isLockedOut: true,
        lockoutUntil: lockoutUntil,
      );
    }

    // Lockout expired, clear it
    await _storage.delete(key: '$_lockoutUntilKey:$userId');
    await _storage.delete(key: '$_failedAttemptsKey:$userId');
    return null;
  }

  /// Increment failed attempts counter
  static Future<int> _incrementFailedAttempts(String userId) async {
    final attemptsStr = await _storage.read(key: '$_failedAttemptsKey:$userId');
    final attempts = (attemptsStr != null ? int.parse(attemptsStr) : 0) + 1;
    await _storage.write(
      key: '$_failedAttemptsKey:$userId',
      value: attempts.toString(),
    );
    return attempts;
  }

  /// Get remaining lockout time
  static Future<Duration?> getRemainingLockoutTime(String userId) async {
    final lockoutStr = await _storage.read(key: '$_lockoutUntilKey:$userId');
    if (lockoutStr == null) return null;

    final lockoutUntil = DateTime.parse(lockoutStr);
    if (DateTime.now().isBefore(lockoutUntil)) {
      return lockoutUntil.difference(DateTime.now());
    }
    return null;
  }
}

/// Result of PIN verification
class PinVerificationResult {
  final bool success;
  final String? error;
  final int? remainingAttempts;
  final bool isLockedOut;
  final DateTime? lockoutUntil;

  PinVerificationResult({
    required this.success,
    this.error,
    this.remainingAttempts,
    this.isLockedOut = false,
    this.lockoutUntil,
  });
}
