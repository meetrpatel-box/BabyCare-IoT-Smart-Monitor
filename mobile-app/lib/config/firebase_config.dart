import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration with emulator support
///
/// Usage:
/// - Production: flutter run
/// - Emulator: flutter run --dart-define=USE_EMULATOR=true
/// - Codespaces: flutter build web --dart-define=USE_EMULATOR=true --dart-define=CODESPACE_NAME=your-codespace-name
class FirebaseConfig {
  static const bool useEmulator = bool.fromEnvironment(
    'USE_EMULATOR',
    defaultValue: false,
  );

  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const String codespaceName = String.fromEnvironment(
    'CODESPACE_NAME',
    defaultValue: '',
  );

  /// Get the appropriate emulator host based on environment
  static String getEmulatorHost() {
    // If running in Codespaces on web, use the Codespaces URL
    if (kIsWeb && codespaceName.isNotEmpty) {
      return codespaceName;
    }
    return emulatorHost;
  }

  /// Get the Auth emulator host (for web in Codespaces, use forwarded hostname)
  static String getAuthEmulatorHost(String host) {
    if (kIsWeb && codespaceName.isNotEmpty) {
      // Return just the hostname for the forwarded port
      return '$host-9099.app.github.dev';
    }
    return host;
  }

  /// Connect to Firebase emulators for local testing
  /// Must be called AFTER Firebase.initializeApp()
  static void connectToEmulators() {
    if (!useEmulator) {
      print('🔥 Using Production Firebase');
      return;
    }

    final host = getEmulatorHost();
    final isCodespaces = kIsWeb && codespaceName.isNotEmpty;

    print('🔧 Connecting to Firebase Emulators on $host...');
    if (isCodespaces) {
      print('   Running in GitHub Codespaces');
    }

    try {
      // Firestore Emulator
      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        8080,
      );
      print('  ✅ Firestore: $host:8080');

      // Auth Emulator - special handling for Codespaces
      if (isCodespaces) {
        final authHost = getAuthEmulatorHost(host);
        // Use port 443 for HTTPS forwarded URLs in Codespaces
        FirebaseAuth.instance.useAuthEmulator(authHost, 443);
        print('  ✅ Auth: https://$authHost (HTTPS via Codespaces)');
      } else {
        FirebaseAuth.instance.useAuthEmulator(host, 9099);
        print('  ✅ Auth: $host:9099');
      }

      // Storage Emulator
      FirebaseStorage.instance.useStorageEmulator(
        host,
        9199,
      );
      print('  ✅ Storage: $host:9199');

      // Functions Emulator
      FirebaseFunctions.instance.useFunctionsEmulator(
        host,
        5001,
      );
      print('  ✅ Functions: $host:5001');

      print('✅ All emulators connected successfully!');
      print('📊 Emulator UI: http://$host:4000');
    } catch (e) {
      print('❌ Error connecting to emulators: $e');
      print('⚠️  Make sure emulators are running: firebase emulators:start');
    }
  }

  /// Check if currently using emulators
  static bool get isUsingEmulator => useEmulator;
}
