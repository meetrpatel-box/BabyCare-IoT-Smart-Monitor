# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BabyTrack Monitor Flutter app - Real-time baby health monitoring application with ESP32 IoT devices.

**Tech Stack**: Flutter 3.x, Dart 3.2+, Firebase (Firestore + Auth), Provider state management, go_router navigation

**Location**: `/workspaces/BabyCareApp/baby_track_flutter/`

## Recent Changes (Feb 2026)

### Family Invitation Feature ✅ COMPLETE
**Date**: February 5, 2026

**What Was Built**:
- **FamilyInviteScreen** (`lib/screens/settings/family_invite_screen.dart`) - 534 lines
  - 3 invitation methods: Email, QR Code, Invite Code
  - Email tab: Validation + FamilyService.inviteMember() integration
  - QR Code tab: QrImageView with shareable invite link
  - Invite Code tab: 8-character code with copy-to-clipboard
- **Settings Integration**: "Invite Family Member" button in settings screen
- **Navigation**: Route added at `/settings/invite-family`
- **Dependencies**: `qr_flutter: ^4.1.0` package
- **Testing**: Integration Test 7 (Family Member Invitation) PASSING
- **Baby Onboarding**: 3-step wizard for first-time users
- **Critical Bug Fix**: Baby-to-family linking via `linkBabyToFamily()`

**Backend Complete**:
- ✅ FamilyService with inviteMember() and acceptInvite()
- ✅ Multi-user family sharing (validated by automated integration tests)
- ✅ familyInvites collection with 7-day expiry
- ✅ Baby accessible by all family members via family.babyIds

**Missing (Next Steps)**:
- ❌ AcceptInviteScreen for recipients
- ❌ Deep linking for invite URLs
- ❌ Email sending via Cloud Functions
- ❌ Invite code entry screen

**Testing Guide**: [FAMILY_INVITATION_TESTING.md](/workspaces/BabyCareApp/FAMILY_INVITATION_TESTING.md)

---

## 📚 Documentation

All documentation is organized in the `docs/` folder with hierarchical structure:

| Level | Documents |
|-------|-----------|
| **1. Overview** | [Product Vision](docs/01-overview/1.1-product-vision.md), [Retention Strategy](docs/01-overview/1.2-retention-strategy.md), [Design Guidelines](docs/01-overview/1.3-design-guidelines.md) |
| **2. Architecture** | [Architecture Overview](docs/02-architecture/2.1-architecture-overview.md), [Data Architecture](docs/02-architecture/2.2-data-architecture.md) |
| **3. Specifications** | [Device Lifecycle](docs/03-specifications/device/3.1.1-device-lifecycle.md) |
| **5. Operations** | [Testing Strategy](docs/05-operations/5.1-testing-strategy.md), [Error Monitoring](docs/05-operations/5.2-error-monitoring.md) |
| **6. Project** | [Roadmap](docs/06-project/6.1-development-roadmap.md), [Status](docs/06-project/6.2-implementation-status.md), [Gap Analysis](docs/06-project/6.3-gap-analysis.md) |

**Start here**: [docs/README.md](docs/README.md)

## Common Commands

### Development (Devcontainer / Linux)
```bash
cd /workspaces/BabyCareApp/baby_track_flutter

# Install dependencies
flutter pub get

# Run on web (Chrome)
flutter run -d chrome

# Run on web (Edge if available)
flutter run -d edge

# Hot reload (while running)
# Press 'r' in terminal

# Hot restart (while running)
# Press 'R' in terminal

# Clear build cache and rebuild
flutter clean && flutter pub get && flutter run -d chrome
```

### Development (Windows Local)
```bash
cd baby_track_flutter

# Install dependencies
flutter pub get

# Run on web (Edge browser)
flutter run -d edge

# Run on web (Chrome - if available)
flutter run -d chrome

# Run on Windows desktop
flutter run -d windows

# Hot reload (while running)
# Press 'r' in terminal

# Hot restart (while running)
# Press 'R' in terminal

# Clear build cache and rebuild
flutter clean && flutter pub get && flutter run -d edge
```

### Using Saved Flutter Path (Windows)
Flutter is installed at: `R:\dev\flutter\bin\flutter.bat`

Quick run script: `run-web.bat` (double-click or run from terminal)

### Building
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web
flutter build web --release

# Windows Desktop (local only)
flutter build windows --release
```

### Code Analysis
```bash
flutter analyze --no-fatal-infos
```

### Testing
```bash
flutter test                    # All tests
flutter test test/unit/         # Unit tests only
flutter test --coverage         # With coverage report
```

## Architecture

### Navigation Structure (go_router)
- **AppRouter** (`lib/navigation/app_router.dart`) - Root router with auth redirects
- Auth flow auto-redirects based on:
  - `isLoading` - Still loading auth state
  - `isAuthenticated` - Fully authenticated (no PIN needed)
  - `requiresPinEntry` - User logged in but needs PIN entry
  - `currentUser` - Firebase User object

Routes:
- `/welcome` - Landing screen
- `/auth/*` - Login, signup, phone entry, OTP, PIN setup
- `/enter-pin` - PIN entry after login (if enabled)
- `/dashboard`, `/trends`, `/analysis`, `/goals`, `/settings` - Main app (ShellRoute with bottom nav)
- Modal routes: `/ai-insights`, `/sleep-analysis`, `/wifi-provisioning`, `/video-call`

### State Management (Provider)
Core providers in `lib/providers/`:
- **AuthProvider** - Authentication state, auto-login, session management
  - Listens to `FirebaseAuth.authStateChanges`
  - Handles PIN entry requirement
  - Manages Firestore user data
  - **Auto-login**: Attempts on app start via `SessionManager`

- **BabyProvider** - Baby profiles, vitals, real-time updates
  - Selected baby context
  - Firestore subscriptions for live data
  - Sleep sessions, vital logs

### Service Layer
All Firebase and business logic in `lib/services/`:

**Authentication**:
- `auth_service.dart` - Firebase Auth wrapper
- `auth/session_manager.dart` - **Auto-login, token refresh, session persistence**
- `storage/secure_storage_service.dart` - **Encrypted token storage** (Keychain/AES)
- `pin_service.dart` - PIN authentication
- `biometric_service.dart` - Face ID / Fingerprint
- `phone_auth_service.dart` - Phone OTP flow

**Data**:
- `firestore_service.dart` - Database CRUD operations
- `baby_service.dart` - Baby profile management
- `device_service.dart` - IoT device management
- `family_service.dart` - Family sharing and invitations (inviteMember, acceptInvite)
- `ai_insights_service.dart` - AI-generated insights

**Features**:
- `wifi_provisioning_service.dart` - BLE device setup
- `video_call_service.dart` - Video streaming
- `music_service.dart` - Audio playback

### Theme System (Design Tokens)
**IMPORTANT**: Always use `DesignTokens` - never hardcode colors/spacing.

Location: `lib/theme/design_tokens.dart`

```dart
import '../../theme/design_tokens.dart';

// Backgrounds
backgroundColor: DesignTokens.backgroundWarm,  // #FDFBF7 (ALL screens use this)
surfaceColor: DesignTokens.surfaceWhite,       // #FFFFFF (cards, modals)

// Colors
color: DesignTokens.primaryTeal,               // #33CCB2
color: DesignTokens.statusHealthy,             // #22C55E (green)
color: DesignTokens.statusSleeping,            // #4338CA (soft indigo)

// Spacing
padding: EdgeInsets.all(DesignTokens.spaceLg), // 16px
margin: EdgeInsets.only(top: DesignTokens.spaceXl), // 24px

// Typography
fontSize: DesignTokens.fontSizeXl,             // 18px
fontWeight: DesignTokens.fontWeightSemiBold,   // w600

// Border Radius
borderRadius: BorderRadius.circular(DesignTokens.radiusMd), // 12px

// Shadows
boxShadow: [DesignTokens.shadowMd],
```

Other theme files:
- `app_theme.dart` - Global ThemeData (uses DesignTokens)
- `app_animations.dart` - Animation constants (400ms standard, easeOutCubic)
- `app_colors.dart`, `app_spacing.dart` - Legacy (use DesignTokens instead)

### Navigation Safety
**IMPORTANT**: Always use `SmartBackButton` - prevents "Nothing to pop" errors.

```dart
import '../../widgets/common/smart_back_button.dart';

// In AppBar
appBar: AppBar(
  leading: const SmartBackButton(fallbackRoute: '/welcome'),
),

// For modals
appBar: AppBar(
  leading: const SmartCloseButton(), // X icon
),
```

## Firebase Integration

### Collections Structure
- `users` - User profiles with preferences
- `families` - Multi-user family sharing (owner/parent/caregiver/viewer roles)
- `babies` - Baby profiles with embedded `latestVitals`
  - Subcollections: `sleepSessions`, `vitalLogs`, `cryEvents`, `wetnessEvents`, `pressureMaps`
- `devices` - IoT pod devices with status and capabilities
- `aiInsights` - AI-generated health insights per baby

### Configuration
Firebase config: `lib/config/firebase_options.dart`
- Generated via `flutterfire configure`
- Shares same backend as React Native app (`../BabyTrackMobile/`)

### Auth State Flow
```
App Launch
    │
    ├─ SessionManager.initialize() (auto-login attempt)
    │   ├─ Check SecureStorage for saved session
    │   ├─ Validate token, refresh if needed
    │   └─ Silent re-auth via Firebase
    │
    ├─ AuthProvider listens to authStateChanges
    │   ├─ User exists? Check PIN requirement
    │   ├─ Save session for next auto-login
    │   └─ Navigate to dashboard or PIN entry
    │
    └─ Router redirect logic
        ├─ No user → /welcome
        ├─ Needs PIN → /enter-pin
        └─ Authenticated → /dashboard
```

## Auto-Login System

**Files**:
- `lib/services/auth/session_manager.dart` - Core auto-login logic
- `lib/services/storage/secure_storage_service.dart` - Encrypted storage

**How it works**:
1. On successful login → Session saved (access token, refresh token, user ID)
2. On app restart → `SessionManager.initialize()` checks for session
3. If valid session → Auto-login (no login screen shown)
4. Token auto-refreshes every 50 minutes (Firebase tokens expire in 60 min)
5. On logout → `clearSession()` disables auto-login

**Platform Security**:
- iOS: Keychain
- Android: EncryptedSharedPreferences (AES)
- Web: Web Crypto API

## Design Guidelines

**Core Philosophy**: "A sleep-deprived parent at 3am, holding a baby with one hand, should see their baby's vitals in under 3 seconds."

**Standards**: Apple's simplicity, Nokia's reliability, F1's speed.

### Child Psychology + UX Principles
Reference: [Design Guidelines](docs/01-overview/1.3-design-guidelines.md)

**Key Rules**:
- **Colors**: Soft, calming (no bright/harsh colors)
  - Teal for actions (trust)
  - Green for healthy (reassurance)
  - Soft indigo for sleep (peace)
  - Soft red only for critical (not alarming)

- **Animations**: 300-500ms, easeOutCubic (calm, controlled)
  - Standard: 400ms
  - No bounce curves (inappropriate for baby monitoring)

- **Language**: Non-alarming
  - ✅ "Check on baby"
  - ❌ "DANGER", "CRITICAL", "ABNORMAL"

- **Data Transparency**: Always show context
  - "Live via Cloud • Updated 30s ago"
  - "All vitals within healthy range"
  - Never just raw numbers without interpretation

- **Design Mantra**: "This isn't a fitness tracker. This is someone's baby. Design accordingly."

### Screen Consistency Checklist
Every screen must have:
- `backgroundColor: DesignTokens.backgroundWarm` (warm off-white)
- `SmartBackButton` or `SmartCloseButton` in AppBar
- Loading state (skeleton or CircularProgressIndicator)
- Error state (friendly message + retry button)
- Empty state (helpful message + action)

## React Native → Flutter Migration

This Flutter app ports the React Native version (`../BabyTrackMobile/`).

| React Native | Flutter |
|--------------|---------|
| Context API | Provider |
| React Navigation | go_router |
| AsyncStorage | shared_preferences |
| expo-secure-store | flutter_secure_storage |
| react-native-ble-manager | flutter_blue_plus |
| expo-local-authentication | local_auth |
| react-native-chart-kit | fl_chart |

When porting screens:
1. Check React Native source in `BabyTrackMobile/src/screens/`
2. Match layout exactly (use same spacing, colors)
3. Port animations using `AppAnimations` constants
4. Use `DesignTokens` instead of hardcoded values
5. Add `SmartBackButton` for safe navigation

## Key Conventions

### File Organization
```
lib/
├── config/           # Firebase configuration
├── models/           # Data models (freezed classes preferred)
├── services/         # Business logic, Firebase interactions
│   ├── auth/         # Authentication services
│   └── storage/      # Local storage services
├── providers/        # State management (ChangeNotifier)
├── screens/
│   ├── auth/         # Login, signup, PIN, OTP screens
│   ├── main/         # Dashboard, trends, analysis, goals screens
│   └── settings/     # Settings, profile, add baby screens
├── widgets/
│   ├── common/       # Reusable widgets (SmartBackButton, etc.)
│   └── analytics/    # Graph widgets (future)
├── theme/            # DesignTokens, AppTheme, animations
├── navigation/       # AppRouter (go_router config)
└── utils/            # Helper functions
```

### Code Style
- Use `const` constructors wherever possible (performance)
- Prefer `ChangeNotifier` over setState for complex state
- All async operations must check `mounted` before setState
- Use `debugPrint` for logs (not `print`)
- Firestore timestamps: `firebase_core.Timestamp`
- Always dispose controllers/subscriptions

### Adding New Screens
1. Create screen file in appropriate `screens/` subdirectory
2. Import DesignTokens and SmartBackButton
3. Set `backgroundColor: DesignTokens.backgroundWarm`
4. Add route to `lib/navigation/app_router.dart`
5. Handle loading/error/empty states
6. Use 400ms animations with easeOutCubic curve

### Testing
**Location**: `test/` directory (mirrors `lib/` structure)

Run tests:
```bash
flutter test                    # All tests
flutter test test/widgets/      # Widget tests only
flutter test --coverage         # With coverage report
```

## Common Development Patterns

### Firestore Data Fetching
```dart
// In Provider
Future<void> loadData() async {
  setState(() => _isLoading = true);

  try {
    final data = await _firestoreService.getData();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
```

### Real-time Subscriptions
```dart
StreamSubscription? _subscription;

void subscribeToBaby(String babyId) {
  _subscription?.cancel();
  _subscription = _firestoreService.streamBaby(babyId).listen(
    (baby) {
      _selectedBaby = baby;
      notifyListeners();
    },
    onError: (e) => debugPrint('Stream error: $e'),
  );
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### Navigation
```dart
// Navigate to named route
context.goNamed('dashboard');

// Navigate with params
context.goNamed('otp', extra: {
  'phoneNumber': phone,
  'verificationId': id,
});

// Go to path
context.go('/settings/profile');

// Push (keeps in stack)
context.push('/ai-insights');

// Pop
context.pop();

// Safe pop (use SmartBackButton instead)
if (Navigator.of(context).canPop()) {
  context.pop();
} else {
  context.go('/welcome');
}
```

## Important Notes

### Environment
- **Devcontainer**: Linux (Ubuntu 24.04) - `/workspaces/BabyCareApp/baby_track_flutter/`
- **Windows Local**: `R:\AnvayaApp\baby_track_flutter/`
- **Flutter Path (Windows)**: `R:\dev\flutter\bin\flutter.bat`
- **Web Testing**: Chrome (`-d chrome`) or Edge (`-d edge`)

### Status
- **Auto-Login**: Implemented and active
- **Theme Consistency**: 100% complete - all screens use DesignTokens
- **Design Guidelines**: See [docs/01-overview/1.3-design-guidelines.md](docs/01-overview/1.3-design-guidelines.md)

## Current Development Status

See [docs/06-project/6.2-implementation-status.md](docs/06-project/6.2-implementation-status.md) for full status.

**Summary**:
- ✅ Authentication: 100%
- ✅ Device/IoT: 85%
- ✅ Photo System: 100%
- ✅ **Family Sharing: 75%** (NEW: Invitation UI complete)
- ✅ Theme/Design: 100%
- ✅ CI/CD: 80% (GitHub Actions, Codecov)
- ✅ Error Monitoring: 100% (Crashlytics integrated)
- ✅ **Baby Onboarding: 100%** (NEW: 3-step wizard)
- ✅ **Integration Testing: 100%** (NEW: 8/8 tests passing)
- 🟡 Testing: 20% (framework ready, needs tests)
- 🟡 Milestones: 40% (model complete, UI missing)
- 🟡 Tips/Coaching: 40% (model complete, UI missing)

## Key Gaps to Address

See [docs/06-project/6.4-world-class-gap-analysis.md](docs/06-project/6.4-world-class-gap-analysis.md) for details.

**Critical**:
1. Testing implementation (framework ready, need tests)
2. Accessibility (no Semantics widgets)
3. MilestoneModel + TipModel (blocks retention features)

**High Priority**:
4. Internationalization (i18n)
5. Offline support
6. Complete test coverage (unit, widget, integration)
