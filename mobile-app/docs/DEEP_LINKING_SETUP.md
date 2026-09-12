# 🔗 Deep Linking Setup for Device Activation

## Overview
Configure deep links to allow email activation links to open the app directly.

---

## 📱 Deep Link Format

### Activation Link
```
https://anavaya.app/activate?device=ANVAYA-PRO-12345
```

### What Happens
1. Customer clicks link in activation email
2. If app installed → Opens app to activation screen
3. If app not installed → Redirects to App Store/Google Play

---

## ⚙️ Android Configuration

### File: `android/app/src/main/AndroidManifest.xml`

Add inside `<activity>` tag:

```xml
<activity
    android:name=".MainActivity"
    ...>
    
    <!-- Existing intent filters -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- Deep link intent filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <!-- HTTP links -->
        <data
            android:scheme="https"
            android:host="anavaya.app"
            android:pathPrefix="/activate" />
        
        <!-- Custom scheme -->
        <data
            android:scheme="anavaya"
            android:host="activate" />
    </intent-filter>
</activity>
```

---

## 🍎 iOS Configuration

### File: `ios/Runner/Info.plist`

Add before `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.anavaya.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>anavaya</string>
        </array>
    </dict>
</array>

<key>FlutterDeepLinkingEnabled</key>
<true/>
```

### File: `ios/Runner/Runner.entitlements`

Create if doesn't exist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:anavaya.app</string>
    </array>
</dict>
</plist>
```

---

## 🌐 Web Configuration (Universal Links)

### File: `public/.well-known/apple-app-site-association`

Host at `https://anavaya.app/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.anavaya.app",
        "paths": [
          "/activate",
          "/activate/*"
        ]
      }
    ]
  }
}
```

### File: `public/.well-known/assetlinks.json`

Host at `https://anavaya.app/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.anavaya.app",
      "sha256_cert_fingerprints": [
        "YOUR_SHA256_FINGERPRINT"
      ]
    }
  }
]
```

---

## 🎯 Flutter Code Integration

### Update: `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'navigation/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  
  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }
  
  void _handleIncomingLinks() {
    // Handle links when app is already open
    _appLinks.uriLinkStream.listen((uri) {
      _navigateToDeepLink(uri);
    });
    
    // Handle initial link when app is launched
    _appLinks.getInitialAppLink().then((uri) {
      if (uri != null) {
        _navigateToDeepLink(uri);
      }
    });
  }
  
  void _navigateToDeepLink(Uri uri) {
    if (uri.path == '/activate') {
      final deviceId = uri.queryParameters['device'];
      // Navigate to activation screen
      // (Implement with your router)
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anavaya',
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.home,
    );
  }
}
```

---

## 📦 Add Package to pubspec.yaml

```yaml
dependencies:
  app_links: ^6.3.2  # Deep linking
```

Run:
```bash
flutter pub get
```

---

## 🧪 Testing Deep Links

### Android Testing
```bash
# Test HTTP link
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://anavaya.app/activate?device=ANVAYA-PRO-12345" \
  com.anavaya.app

# Test custom scheme
adb shell am start -W -a android.intent.action.VIEW \
  -d "anavaya://activate?device=ANVAYA-PRO-12345" \
  com.anavaya.app
```

### iOS Testing
```bash
# In iOS Simulator
xcrun simctl openurl booted "https://anavaya.app/activate?device=ANVAYA-PRO-12345"

# Or custom scheme
xcrun simctl openurl booted "anavaya://activate?device=ANVAYA-PRO-12345"
```

### Manual Testing
1. Send email to yourself with activation link
2. Open email on phone
3. Tap link
4. Verify app opens to activation screen

---

## ✅ Verification Checklist

- [ ] AndroidManifest.xml updated with intent filter
- [ ] Info.plist updated with URL types
- [ ] Runner.entitlements created with associated domains
- [ ] `app_links` package added to pubspec.yaml
- [ ] Deep link handler in main.dart
- [ ] Tested on Android device
- [ ] Tested on iOS device
- [ ] Verified universal links work (https://anavaya.app/activate)
- [ ] Verified custom scheme works (anavaya://activate)

---

**Last Updated**: February 9, 2026
