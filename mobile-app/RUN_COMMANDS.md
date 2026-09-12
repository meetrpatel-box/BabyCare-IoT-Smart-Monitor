# Flutter Run Commands Reference

**Saved for Future Reference** - Commands to run and test the Baby Track Flutter app

---

## Prerequisites

1. **Flutter SDK installed**: https://docs.flutter.dev/get-started/install
2. **Flutter added to PATH**
3. **Chrome browser** (for web testing)

Check installation:
```bash
flutter doctor
```

---

## Quick Start Commands

### Run on Web (Chrome)
```bash
cd R:\AnvayaApp\baby_track_flutter
flutter run -d chrome
```

### Run on Web Server (custom port)
```bash
cd R:\AnvayaApp\baby_track_flutter
flutter run -d web-server --web-port 8080
```

### Run on Android Emulator
```bash
cd R:\AnvayaApp\baby_track_flutter
flutter emulators --launch <emulator_id>
flutter run
```

### Run on Windows Desktop
```bash
cd R:\AnvayaApp\baby_track_flutter
flutter run -d windows
```

---

## Batch Scripts

### Windows Batch File
Double-click: `run-web.bat`

Or from command prompt:
```cmd
cd R:\AnvayaApp\baby_track_flutter
run-web.bat
```

---

## Testing Child Psychology Guidelines

When the app runs, verify these updates:

### ✅ Dashboard Screen (Home)

1. **Data Transparency** (NEW):
   - Look for: "☁️ Live via Cloud • Updated 30s ago"
   - Green text below "Sleeping soundly for 2h 15m"
   - Verify cloud icon is visible

2. **Vital Reassurance** (NEW):
   - Look for: "✅ All vitals within healthy range"
   - Below vitals grid (36.5°C | 45% | 120 BPM)
   - Green background box with checkmark

3. **Color Psychology**:
   - Sleeping badge: Soft indigo (#4338CA) background
   - Awake badge: Warm amber (#F59E0B) background
   - Primary buttons: Teal (#33CCB2)

### ✅ Video Call Screen

1. Navigate: Click **"View Live Stream"** on dashboard

2. **Live Pulse Animation** (NEW):
   - Red dot next to "Live via Cloud" should pulse
   - Smooth 1.5-second breathing rhythm
   - Opacity fades 1.0 → 0.5 → 1.0 (not flashing)

3. **Data Transparency**:
   - "Live via Cloud" badge
   - "WiFi 99%" status
   - "25dB" decibel level

### ✅ Animation Standards

- All transitions: 400ms (calm, smooth)
- Navigation: 300ms (responsive)
- Success feedback: 500ms (gentle celebration)
- No rushed or jarring animations

---

## Build Commands

### Development Build
```bash
flutter build web --debug
```

### Production Build
```bash
flutter build web --release
```

### Android APK
```bash
flutter build apk --release
```

### Windows Desktop
```bash
flutter build windows --release
```

---

## Troubleshooting

### Flutter not found
```bash
# Check if Flutter is installed
where flutter

# If not found, add to PATH or install from:
# https://docs.flutter.dev/get-started/install
```

### Chrome not launching
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d chrome
```

### Port already in use
```bash
# Use different port
flutter run -d web-server --web-port 8081
```

### Clear cache and rebuild
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

---

## Performance Testing

### Hot Reload (while running)
Press `r` in terminal

### Hot Restart (while running)
Press `R` in terminal

### Quit app
Press `q` in terminal

---

## Files Modified for Child Psychology Guidelines

1. **lib/theme/app_animations.dart** (NEW)
   - Animation durations: 300-500ms
   - Easing curves: easeOutCubic, easeInOutQuad

2. **lib/screens/main/dashboard_screen.dart**
   - Added data transparency
   - Added vital reassurance

3. **lib/screens/main/video_call_screen.dart**
   - Added live pulse animation
   - 1500ms breathing rhythm

4. **CHILD_PSYCHOLOGY_COMPLIANCE.md** (NEW)
   - Full compliance audit

5. **GUIDELINE_UPDATES_SUMMARY.md** (NEW)
   - Implementation details

---

## Reference

- **Design Guidelines**: `R:\AnvayaApp\DESIGN_GUIDELINES.md` (Section 6)
- **Compliance Report**: `CHILD_PSYCHOLOGY_COMPLIANCE.md`
- **Update Summary**: `GUIDELINE_UPDATES_SUMMARY.md`

---

**Last Updated**: 2026-01-29
**Status**: ✅ Ready for Testing
