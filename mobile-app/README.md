# BabyTrack Flutter

Flutter port of the BabyTrack Monitor mobile application.

## 📚 Documentation

**All documentation has been organized into a hierarchical structure:**

📖 **[View Full Documentation →](docs/README.md)**

| Level | Description | Start Here |
|-------|-------------|------------|
| 1. Overview | Product vision, strategy | [Product Vision](docs/01-overview/1.1-product-vision.md) |
| 2. Architecture | System design, data models | [Architecture Overview](docs/02-architecture/2.1-architecture-overview.md) |
| 3. Specifications | Domain-specific specs | [Device Lifecycle](docs/03-specifications/device/3.1.1-device-lifecycle.md) |
| 5. Operations | Testing, monitoring | [Testing Strategy](docs/05-operations/5.1-testing-strategy.md) |
| 6. Project | Roadmap, status, gaps | [Gap Analysis](docs/06-project/6.3-gap-analysis.md) |

## Overview

BabyTrack Monitor is a Flutter mobile application for real-time monitoring of baby health and vitals through IoT devices. This is a port of the original React Native (Expo) application.

## Tech Stack

- **Flutter** 3.x
- **Dart** 3.2+
- **Firebase** (Firestore + Auth)
- **Provider** for state management
- **go_router** for navigation
- **flutter_blue_plus** for BLE device provisioning

## Project Structure

```
lib/
├── config/           # Firebase and app configuration
├── models/           # Data models (User, Baby, Device, etc.)
├── services/         # Firebase and business logic services
├── providers/        # State management (ChangeNotifier)
├── screens/          # UI screens
│   ├── auth/         # Authentication screens
│   ├── main/         # Main app screens
│   └── settings/     # Settings screens
├── widgets/          # Reusable UI components
├── theme/            # Colors, spacing, theming
├── navigation/       # Router configuration
└── utils/            # Utility functions
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2.0 or later
- Dart 3.2.0 or later
- Firebase CLI (for configuration)
- Android Studio / Xcode (for device deployment)

### Installation

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Configure Firebase:
   ```bash
   flutterfire configure
   ```
   This will generate `lib/config/firebase_options.dart` with your project credentials.

3. Run the app:
   ```bash
   flutter run
   ```

### Building

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## Features

### Authentication
- Phone number authentication with OTP
- Email/password authentication
- PIN-based local authentication
- Biometric authentication (Face ID / Fingerprint)

### Dashboard
- Real-time vital signs monitoring
- Heart rate, SpO2, temperature display
- Sleep summary
- Quick actions

### Trends & Analysis
- Historical data charts
- Sleep pattern analysis
- AI-powered health insights

### Device Management
- BLE device provisioning
- WiFi configuration
- Device status monitoring

### Settings
- Baby profile management
- User profile
- App preferences
- Security settings

## Firebase Collections

- `users` - User profiles
- `families` - Family groups
- `babies` - Baby profiles with embedded vitals
- `devices` - IoT device records
- `aiInsights` - AI-generated insights

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `provider` | State management |
| `go_router` | Navigation |
| `flutter_blue_plus` | Bluetooth LE |
| `local_auth` | Biometrics |
| `flutter_secure_storage` | Secure storage |
| `fl_chart` | Data visualization |

## Migration from React Native

This Flutter app is ported from the React Native (Expo) version with the following mappings:

| React Native | Flutter |
|--------------|---------|
| Context API | Provider |
| React Navigation | go_router |
| AsyncStorage | shared_preferences |
| expo-secure-store | flutter_secure_storage |
| react-native-ble-manager | flutter_blue_plus |
| expo-local-authentication | local_auth |
| react-native-chart-kit | fl_chart |

## License

Proprietary - All rights reserved.
