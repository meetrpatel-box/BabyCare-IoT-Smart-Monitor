# Build Guide - BabyTrack Flutter App

This guide explains how to build release versions of the BabyTrack app for Android and iOS.

## Prerequisites

### For Android Builds
- Android SDK installed
- Java 17+ installed
- Environment variable `ANDROID_HOME` set to your Android SDK path
- Flutter SDK installed

### For iOS Builds
- macOS with Xcode 14+ installed
- Apple Developer account
- Valid provisioning profiles and certificates
- Flutter SDK installed

## Quick Build Commands

### Android

**Option 1: Using the build script (recommended)**
```bash
chmod +x build-android.sh
./build-android.sh
```

**Option 2: Manual commands**
```bash
# Clean previous builds
flutter clean
flutter pub get

# Build App Bundle for Google Play Store (recommended)
flutter build appbundle --release

# OR Build APK for direct installation
flutter build apk --release

# Build split APKs per ABI (smaller file sizes)
flutter build apk --split-per-abi --release
```

**Output locations:**
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Split APKs: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (and others)

### iOS

**Option 1: Using the build script (recommended)**
```bash
chmod +x build-ios.sh
./build-ios.sh
```

**Option 2: Manual commands**
```bash
# Clean previous builds
flutter clean
flutter pub get

# Build IPA for App Store/TestFlight
flutter build ipa --release

# OR build without codesigning (for local testing)
flutter build ios --release --no-codesign
```

**Output locations:**
- IPA: `build/ios/ipa/baby_track_flutter.ipa`
- Xcode Archive: `build/ios/archive/Runner.xcarchive`

## Build Configurations

### Android Signing

Before building for production, you need to set up signing:

1. **Generate a keystore:**
```bash
keytool -genkey -v -keystore ~/baby-track-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias baby-track-key
```

2. **Create `android/key.properties`:**
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=baby-track-key
storeFile=/path/to/baby-track-release-key.jks
```

3. **Update `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### iOS Code Signing

1. **Open Xcode:**
```bash
open ios/Runner.xcworkspace
```

2. **Configure signing:**
   - Select the Runner project in Xcode
   - Go to "Signing & Capabilities" tab
   - Select your Team
   - Choose appropriate provisioning profile

3. **Update bundle identifier:**
   - Change from `com.example.baby_track_flutter` to your unique bundle ID
   - Update in both Xcode and `ios/Runner/Info.plist`

## Version Management

Update version before building release:

**In `pubspec.yaml`:**
```yaml
version: 1.0.0+1  # Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

For Android, this translates to:
- `versionName`: 1.0.0
- `versionCode`: 1

For iOS:
- `CFBundleShortVersionString`: 1.0.0
- `CFBundleVersion`: 1

## Distribution

### Google Play Store (Android)
1. Build AAB: `flutter build appbundle --release`
2. Go to [Google Play Console](https://play.google.com/console)
3. Create new release
4. Upload `app-release.aab`
5. Fill in release notes and submit

### App Store (iOS)
1. Build IPA: `flutter build ipa --release`
2. Open Xcode Organizer (Xcode → Window → Organizer)
3. Select the archive
4. Click "Distribute App"
5. Choose "App Store Connect"
6. Follow the prompts to upload

### Direct Installation (Testing)

**Android APK:**
```bash
# Install on connected device
adb install build/app/outputs/flutter-apk/app-release.apk
```

**iOS (Ad Hoc/Enterprise):**
1. Build with ad-hoc provisioning profile
2. Export IPA from Xcode
3. Distribute via TestFlight or enterprise distribution

## Build Troubleshooting

### Common Android Issues

**"No Android SDK found"**
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

**"Gradle build failed"**
- Clear Gradle cache: `cd android && ./gradlew clean`
- Check Java version: `java -version` (should be 17+)

**"Execution failed for task ':app:lintVitalRelease'"**
```gradle
// In android/app/build.gradle
android {
    lintOptions {
        checkReleaseBuilds false
    }
}
```

### Common iOS Issues

**"No valid code signing certificates found"**
- Ensure you're logged into Xcode with your Apple Developer account
- Check certificates in Xcode → Preferences → Accounts

**"Provisioning profile doesn't match"**
- Update bundle identifier
- Regenerate provisioning profile in Apple Developer portal

**"Pod install failed"**
```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

## Build for Specific Environments

### Development Build
```bash
flutter build apk --debug  # Android
flutter build ios --debug  # iOS
```

### Profile Build (Performance Testing)
```bash
flutter build apk --profile  # Android
flutter build ios --profile  # iOS
```

## GitHub Actions (Automated Builds)

See `.github/workflows/build.yml` for CI/CD pipeline (if configured).

## Support

For build issues:
1. Check Flutter doctor: `flutter doctor -v`
2. Update Flutter: `flutter upgrade`
3. Clear cache: `flutter clean`
4. Rebuild dependencies: `flutter pub get`

---

**Note:** Building iOS apps requires a Mac with Xcode. Android apps can be built on Windows, macOS, or Linux.
