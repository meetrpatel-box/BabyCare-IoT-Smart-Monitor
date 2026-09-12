import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/error_codes.dart';

/// Service for automatic retry with exponential backoff
/// Wraps Firestore operations to handle transient failures gracefully
class AutoReconnectService {
  static const maxRetries = 3;
  static const retryDelays = [
    Duration(seconds: 2),  // 1st retry after 2s
    Duration(seconds: 5),  // 2nd retry after 5s
    Duration(seconds: 10), // 3rd retry after 10s
  ];

  /// Execute a Firestore operation with automatic retries
  /// Throws AppException with user-friendly error after max retries
  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          // Max retries exceeded, throw user-friendly error
          final errorCode = AppErrorCode.fromException(e);
          debugPrint('[AutoReconnect] Max retries exceeded for $context: $errorCode');
          throw AppException(
            errorCode: errorCode,
            originalException: e,
          );
        }

        // Log retry attempt
        final delay = retryDelays[attempts - 1];
        debugPrint(
          '[AutoReconnect] Retry attempt $attempts/$maxRetries for $context after ${delay.inSeconds}s',
        );

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    throw Exception('Max retries exceeded'); // Should never reach here
  }

  /// Execute with retry and callback for retry events
  Future<T> withRetryAndCallback<T>(
    Future<T> Function() operation, {
    required Function(int attempt, int maxAttempts) onRetry,
    String? context,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          final errorCode = AppErrorCode.fromException(e);
          throw AppException(
            errorCode: errorCode,
            originalException: e,
          );
        }

        // Notify caller of retry
        onRetry(attempts, maxRetries);

        final delay = retryDelays[attempts - 1];
        debugPrint(
          '[AutoReconnect] Retry $attempts/$maxRetries for $context after ${delay.inSeconds}s',
        );

        await Future.delayed(delay);
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Execute with custom retry strategy
  Future<T> withCustomRetry<T>(
    Future<T> Function() operation, {
    required List<Duration> customDelays,
    String? context,
  }) async {
    int attempts = 0;
    final maxAttempts = customDelays.length + 1;

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxAttempts) {
          final errorCode = AppErrorCode.fromException(e);
          throw AppException(
            errorCode: errorCode,
            originalException: e,
          );
        }

        final delay = customDelays[attempts - 1];
        debugPrint('[AutoReconnect] Custom retry $attempts/$maxAttempts after ${delay.inSeconds}s');

        await Future.delayed(delay);
      }
    }

    throw Exception('Max retries exceeded');
  }
}
