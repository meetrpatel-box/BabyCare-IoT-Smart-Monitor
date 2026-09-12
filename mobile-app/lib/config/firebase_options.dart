import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration options
/// Configure with your Firebase project credentials
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyACqzL1Pxb5CiQKERB1Q7Htz6QS12QGYLU',
    appId: '1:1007232493479:web:ec37b813477cc48add7882',
    messagingSenderId: '1007232493479',
    projectId: 'slumber-insights-tqv7z',
    authDomain: 'slumber-insights-tqv7z.firebaseapp.com',
    storageBucket: 'slumber-insights-tqv7z.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAeodMi7VhoeywCnVQS1ZSJmKpKePYViHw',
    appId: '1:1007232493479:android:654ed9f85a938302dd7882',
    messagingSenderId: '1007232493479',
    projectId: 'slumber-insights-tqv7z',
    storageBucket: 'slumber-insights-tqv7z.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACqzL1Pxb5CiQKERB1Q7Htz6QS12QGYLU',
    appId: '1:1007232493479:web:ec37b813477cc48add7882',
    messagingSenderId: '1007232493479',
    projectId: 'slumber-insights-tqv7z',
    storageBucket: 'slumber-insights-tqv7z.firebasestorage.app',
    iosBundleId: 'com.babytrack.mobile',
  );
}
