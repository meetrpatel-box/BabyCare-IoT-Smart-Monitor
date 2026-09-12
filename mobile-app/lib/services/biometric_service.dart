import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart' as local_auth;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biometric authentication service
/// Ported from React Native biometricService.ts
class BiometricService {
  static final local_auth.LocalAuthentication _localAuth =
      local_auth.LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const _biometricEnabledKey = 'biometric_enabled';

  /// Check if biometric authentication is available
  static Future<BiometricAvailability> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return BiometricAvailability(
          isAvailable: false,
          biometricType: BiometricType.none,
          reason: 'Device does not support biometric authentication',
        );
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        return BiometricAvailability(
          isAvailable: false,
          biometricType: BiometricType.none,
          reason: 'Biometric authentication not available',
        );
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return BiometricAvailability(
          isAvailable: false,
          biometricType: BiometricType.none,
          reason: 'No biometrics enrolled on device',
        );
      }

      // Determine biometric type
      BiometricType biometricType = BiometricType.fingerprint;
      if (availableBiometrics.contains(local_auth.BiometricType.face)) {
        biometricType = BiometricType.faceId;
      } else if (availableBiometrics.contains(local_auth.BiometricType.iris)) {
        biometricType = BiometricType.iris;
      }

      return BiometricAvailability(
        isAvailable: true,
        biometricType: biometricType,
      );
    } on PlatformException catch (e) {
      return BiometricAvailability(
        isAvailable: false,
        biometricType: BiometricType.none,
        reason: e.message ?? 'Unknown error checking biometrics',
      );
    }
  }

  /// Authenticate with biometrics
  static Future<BiometricResult> authenticate({
    String reason = 'Authenticate to access BabyTrack',
  }) async {
    try {
      final availability = await isBiometricAvailable();
      if (!availability.isAvailable) {
        return BiometricResult(
          success: false,
          error: availability.reason ?? 'Biometric not available',
        );
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const local_auth.AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return BiometricResult(success: didAuthenticate);
    } on PlatformException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'NotEnrolled':
          errorMessage = 'No biometrics enrolled on this device';
          break;
        case 'LockedOut':
          errorMessage = 'Biometric authentication is locked. Try again later';
          break;
        case 'PermanentlyLockedOut':
          errorMessage =
              'Biometric authentication is permanently locked. Use PIN instead';
          break;
        case 'PasscodeNotSet':
          errorMessage = 'Device passcode not set';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }
      return BiometricResult(success: false, error: errorMessage);
    }
  }

  /// Check if biometric login is enabled for user
  static Future<bool> isBiometricEnabled(String userId) async {
    final value = await _storage.read(key: '$_biometricEnabledKey:$userId');
    return value == 'true';
  }

  /// Enable/disable biometric login for user
  static Future<void> setBiometricEnabled(String userId, bool enabled) async {
    await _storage.write(
      key: '$_biometricEnabledKey:$userId',
      value: enabled.toString(),
    );
  }

  /// Get biometric type display name
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.faceId:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.none:
        return 'None';
    }
  }
}

/// Biometric availability result
class BiometricAvailability {
  final bool isAvailable;
  final BiometricType biometricType;
  final String? reason;

  BiometricAvailability({
    required this.isAvailable,
    required this.biometricType,
    this.reason,
  });
}

/// Biometric authentication result
class BiometricResult {
  final bool success;
  final String? error;

  BiometricResult({required this.success, this.error});
}

/// Biometric type enum
enum BiometricType {
  faceId,
  fingerprint,
  iris,
  none,
}
