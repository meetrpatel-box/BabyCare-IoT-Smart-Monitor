/// User-friendly error code system for BabyTrack app
/// Replaces raw exceptions with helpful messages and recovery suggestions
class AppErrorCode {
  final String code;
  final String userMessage;
  final String technicalDetails;
  final ErrorSeverity severity;
  final List<String> suggestedActions;

  const AppErrorCode({
    required this.code,
    required this.userMessage,
    required this.technicalDetails,
    required this.severity,
    required this.suggestedActions,
  });

  // ============== DEVICE ERRORS ==============

  static const deviceOffline = AppErrorCode(
    code: 'DEVICE_OFFLINE',
    userMessage: 'Device is currently offline',
    technicalDetails: 'Device lastSeenAt > 5 minutes ago',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Check if the device is powered on',
      'Verify WiFi connection',
      'Try moving the device closer to your router',
      'Restart the device if needed',
    ],
  );

  static const weakSignal = AppErrorCode(
    code: 'WEAK_SIGNAL',
    userMessage: 'Device has weak WiFi signal',
    technicalDetails: 'WiFi RSSI < -80 dBm',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Move device closer to WiFi router',
      'Check for WiFi interference',
      'Consider using a WiFi extender',
      'Restart your router',
    ],
  );

  static const deviceNotFound = AppErrorCode(
    code: 'DEVICE_NOT_FOUND',
    userMessage: 'Device not found',
    technicalDetails: 'Device document does not exist in Firestore',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Verify the device is registered',
      'Try reloading the app',
      'Contact support if the issue persists',
    ],
  );

  static const deviceProvisioning = AppErrorCode(
    code: 'DEVICE_PROVISIONING',
    userMessage: 'Device is still being set up',
    technicalDetails: 'Device status is "provisioning"',
    severity: ErrorSeverity.info,
    suggestedActions: [
      'Please wait while setup completes',
      'This usually takes 1-2 minutes',
      'Restart setup if it takes longer than 5 minutes',
    ],
  );

  // ============== PERMISSION ERRORS ==============

  static const permissionDenied = AppErrorCode(
    code: 'PERMISSION_DENIED',
    userMessage: 'You don\'t have permission to access this',
    technicalDetails: 'Firestore permission rules denied access',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Contact the family owner to grant access',
      'Check your account permissions in Settings',
      'Sign out and sign back in',
    ],
  );

  static const notFamilyMember = AppErrorCode(
    code: 'NOT_FAMILY_MEMBER',
    userMessage: 'You\'re not a member of this family',
    technicalDetails: 'User not in family.members array',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Ask the family owner to send you an invitation',
      'Check your email for pending invitations',
      'Verify you\'re signed in with the correct account',
    ],
  );

  static const viewerRestricted = AppErrorCode(
    code: 'VIEWER_RESTRICTED',
    userMessage: 'Viewers cannot perform this action',
    technicalDetails: 'User role is "viewer" but action requires "parent" or higher',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Ask the family owner to upgrade your role',
      'Contact a parent or owner for assistance',
    ],
  );

  // ============== NETWORK ERRORS ==============

  static const networkError = AppErrorCode(
    code: 'NETWORK_ERROR',
    userMessage: 'Unable to connect to server',
    technicalDetails: 'Network request failed or timed out',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Check your internet connection',
      'Try switching between WiFi and cellular data',
      'Try again in a few moments',
      'Restart the app',
    ],
  );

  static const firestoreTimeout = AppErrorCode(
    code: 'FIRESTORE_TIMEOUT',
    userMessage: 'Request timed out',
    technicalDetails: 'Firestore query exceeded timeout limit',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Check your internet connection',
      'Retry the operation',
      'Try again with a smaller date range',
    ],
  );

  static const firestoreUnavailable = AppErrorCode(
    code: 'FIRESTORE_UNAVAILABLE',
    userMessage: 'Service temporarily unavailable',
    technicalDetails: 'Firestore returned "unavailable" error',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Please try again in a few moments',
      'Check if your internet is working',
      'The issue should resolve automatically',
    ],
  );

  // ============== VIDEO/AUDIO ERRORS ==============

  static const videoCallFailed = AppErrorCode(
    code: 'VIDEO_CALL_FAILED',
    userMessage: 'Video call couldn\'t start',
    technicalDetails: 'WebRTC connection failed',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Check if the device is online',
      'Verify your camera permissions',
      'Try restarting the app',
      'Check your internet connection',
    ],
  );

  static const cameraPermissionDenied = AppErrorCode(
    code: 'CAMERA_PERMISSION_DENIED',
    userMessage: 'Camera permission required',
    technicalDetails: 'App does not have camera permission',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Open Settings',
      'Go to App Permissions',
      'Enable Camera access for BabyTrack',
    ],
  );

  static const microphonePermissionDenied = AppErrorCode(
    code: 'MICROPHONE_PERMISSION_DENIED',
    userMessage: 'Microphone permission required',
    technicalDetails: 'App does not have microphone permission',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Open Settings',
      'Go to App Permissions',
      'Enable Microphone access for BabyTrack',
    ],
  );

  // ============== BLUETOOTH ERRORS ==============

  static const bluetoothOff = AppErrorCode(
    code: 'BLUETOOTH_OFF',
    userMessage: 'Bluetooth is turned off',
    technicalDetails: 'Bluetooth adapter is disabled',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Turn on Bluetooth in your device settings',
      'Or use the quick settings toggle',
    ],
  );

  static const bluetoothUnauthorized = AppErrorCode(
    code: 'BLUETOOTH_UNAUTHORIZED',
    userMessage: 'Bluetooth permission denied',
    technicalDetails: 'App does not have Bluetooth permission',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Open Settings',
      'Go to App Permissions',
      'Enable Bluetooth access for BabyTrack',
    ],
  );

  static const bleConnectionFailed = AppErrorCode(
    code: 'BLE_CONNECTION_FAILED',
    userMessage: 'Couldn\'t connect to device',
    technicalDetails: 'Bluetooth connection failed after 3 retries',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Make sure the device is powered on',
      'Move your phone closer to the device',
      'Restart both devices',
      'Try the setup again',
    ],
  );

  // ============== DATA ERRORS ==============

  static const babyNotFound = AppErrorCode(
    code: 'BABY_NOT_FOUND',
    userMessage: 'Baby profile not found',
    technicalDetails: 'Baby document does not exist',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Refresh the app',
      'Check if the profile was deleted',
      'Contact support if the issue persists',
    ],
  );

  static const invalidData = AppErrorCode(
    code: 'INVALID_DATA',
    userMessage: 'Invalid data provided',
    technicalDetails: 'Data validation failed',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Check that all required fields are filled',
      'Verify the data format is correct',
      'Try again with different values',
    ],
  );

  static const syncFailed = AppErrorCode(
    code: 'SYNC_FAILED',
    userMessage: 'Data sync failed',
    technicalDetails: 'Failed to sync local changes with server',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Your changes are saved locally',
      'They will sync when connection is restored',
      'Check your internet connection',
    ],
  );

  // ============== AUTH ERRORS ==============

  static const notAuthenticated = AppErrorCode(
    code: 'NOT_AUTHENTICATED',
    userMessage: 'Please sign in to continue',
    technicalDetails: 'User is not authenticated',
    severity: ErrorSeverity.error,
    suggestedActions: [
      'Sign in to your account',
      'Or create a new account if you don\'t have one',
    ],
  );

  static const sessionExpired = AppErrorCode(
    code: 'SESSION_EXPIRED',
    userMessage: 'Your session has expired',
    technicalDetails: 'Auth token expired',
    severity: ErrorSeverity.warning,
    suggestedActions: [
      'Please sign in again',
      'Your data is safe and will be restored',
    ],
  );

  // ============== ERROR MAPPING ==============

  /// Map Firebase exceptions to user-friendly error codes
  static AppErrorCode fromException(dynamic e) {
    final errorString = e.toString().toLowerCase();

    // Permission errors
    if (errorString.contains('permission-denied') ||
        errorString.contains('permission denied')) {
      return permissionDenied;
    }

    // Network errors
    if (errorString.contains('unavailable')) {
      return firestoreUnavailable;
    }
    if (errorString.contains('timeout') || errorString.contains('deadline')) {
      return firestoreTimeout;
    }
    if (errorString.contains('network') || errorString.contains('connection')) {
      return networkError;
    }

    // Auth errors
    if (errorString.contains('unauthenticated') ||
        errorString.contains('not authenticated')) {
      return notAuthenticated;
    }
    if (errorString.contains('token') && errorString.contains('expired')) {
      return sessionExpired;
    }

    // Bluetooth errors
    if (errorString.contains('bluetooth')) {
      if (errorString.contains('unauthorized') || errorString.contains('permission')) {
        return bluetoothUnauthorized;
      }
      if (errorString.contains('off') || errorString.contains('disabled')) {
        return bluetoothOff;
      }
      return bleConnectionFailed;
    }

    // Camera/Mic errors
    if (errorString.contains('camera')) {
      return cameraPermissionDenied;
    }
    if (errorString.contains('microphone') || errorString.contains('audio')) {
      return microphonePermissionDenied;
    }

    // Device errors
    if (errorString.contains('not found')) {
      if (errorString.contains('device')) {
        return deviceNotFound;
      }
      if (errorString.contains('baby')) {
        return babyNotFound;
      }
    }

    // Default unknown error
    return AppErrorCode(
      code: 'UNKNOWN_ERROR',
      userMessage: 'An unexpected error occurred',
      technicalDetails: e.toString(),
      severity: ErrorSeverity.error,
      suggestedActions: [
        'Try the operation again',
        'Restart the app if the issue persists',
        'Contact support if you continue to have problems',
      ],
    );
  }

  @override
  String toString() => '[$code] $userMessage';
}

/// Error severity levels
enum ErrorSeverity {
  info,     // Informational, no action needed
  warning,  // Warning, user should be aware
  error,    // Error, requires user action
  critical, // Critical error, app functionality affected
}

/// Custom exception that includes error code
class AppException implements Exception {
  final AppErrorCode errorCode;
  final dynamic originalException;

  AppException({
    required this.errorCode,
    this.originalException,
  });

  @override
  String toString() => errorCode.toString();
}
