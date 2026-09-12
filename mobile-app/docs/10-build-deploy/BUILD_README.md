# Quick Build Instructions

## ⚠️ Important Note
This Codespaces environment (Linux) doesn't have Android SDK or Xcode installed. 

**To build release versions, run these scripts on your local machine:**
- **Android**: Windows, macOS, or Linux with Android SDK
- **iOS**: macOS with Xcode only

## Build Scripts

### Android
```bash
# Linux/macOS
./build-android.sh

# Windows (PowerShell)
.\build-android.ps1
```

### iOS (macOS only)
```bash
./build-ios.sh
```

## Output Files

**Android:**
- App Bundle: `build/app/outputs/bundle/release/app-release.aab` (for Play Store)
- APK: `build/app/outputs/flutter-apk/app-release.apk` (for direct install)

**iOS:**
- IPA: `build/ios/ipa/baby_track_flutter.ipa`

## Full Documentation

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for:
- Complete setup instructions
- Code signing configuration
- Version management
- Distribution steps
- Troubleshooting guide

## Quick Manual Commands

**Android:**
```bash
flutter clean
flutter pub get
flutter build appbundle --release  # For Play Store
flutter build apk --release         # For direct install
```

**iOS:**
```bash
flutter clean
flutter pub get
flutter build ipa --release
```

## Before Building

1. **Update version** in `pubspec.yaml`:
   ```yaml
   version: 1.0.0+1
   ```

2. **Configure signing:**
   - Android: Set up `key.properties` (see BUILD_GUIDE.md)
   - iOS: Configure in Xcode (open `ios/Runner.xcworkspace`)

3. **Update app identifiers:**
   - Android: `android/app/build.gradle` → `applicationId`
   - iOS: Xcode → Bundle Identifier

## Need Help?

Run `flutter doctor -v` to check your development environment setup.
