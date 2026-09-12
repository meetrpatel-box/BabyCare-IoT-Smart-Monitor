# ESP32 Device Simulator - Complete Testing Guide

This guide covers end-to-end testing with the AnvayaPod Simulator publishing vital signs to Firebase, which the Flutter app displays in real-time.

## Architecture

```
┌─────────────────────┐         ┌──────────────────┐         ┌───────────────────┐
│  Device Simulator   │────────>│     Firebase     │<────────│   Flutter App     │
│   (Port 8081)       │         │  slumber-insights│         │   (Port 8080)     │
│                     │         │    Production    │         │                   │
│ - Sensor Controls   │         │                   │         │ - Live Vitals     │
│ - Publish Vitals    │         │ - vital_signs     │         │ - Dashboard      │
│ - Realistic Variance│         │ - devices         │         │ - Device Status   │
└─────────────────────┘         └──────────────────┘         └───────────────────┘
```

## Prerequisites

✅ **Required:**
- Flutter app running on port 8080
- Firebase project: `slumber-insights-tqv7z`
- User account created in Flutter app
- Device registered with familyId

## Test Setup

### Step 1: Start Flutter App (Main App)

```bash
cd /workspaces/BabyCareApp/baby_track_flutter

# Check if already running
lsof -i :8080

# If not, start it
$HOME/flutter/bin/flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

**Access:** http://localhost:8080

### Step 2: Create Test User & Device

1. **Sign up in Flutter app:**
   - Email: `simulator-test@example.com`
   - Password: `TestPassword123!`
   - Name: `Simulator Tester`

2. **Note your Family ID:**
   Open browser console and run:
   ```javascript
   firebase.auth().currentUser.uid.then(uid => {
     firebase.firestore().collection('users').doc(uid).get().then(doc => {
       console.log('Family ID:', doc.data().familyIds[0]);
     });
   });
   ```

3. **Create a test baby:**
   In browser console:
   ```javascript
   const familyId = 'YOUR_FAMILY_ID_HERE';
   
   firebase.firestore().collection('babies').add({
     name: 'Test Baby',
     dateOfBirth: firebase.firestore.Timestamp.fromDate(new Date('2026-01-01')),
     gender: 'male',
     familyId: familyId,
     createdAt: firebase.firestore.FieldValue.serverTimestamp()
   }).then(doc => {
     console.log('Baby ID:', doc.id);
     localStorage.setItem('testBabyId', doc.id);
   });
   ```

4. **Register simulator device:**
   ```javascript
   const familyId = 'YOUR_FAMILY_ID_HERE';
   const babyId = localStorage.getItem('testBabyId');
   
   firebase.firestore().collection('devices').add({
     name: 'Simulator Device',
     deviceId: 'simulator-001',
     familyId: familyId,
     assignedBabyId: babyId,
     status: 'online',
     firmwareVersion: '1.0.0-sim',
     capabilities: {
       hasCamera: false,
       hasMicrophone: false,
       hasVitalSensors: true,
       supportsVideo: false,
       supportsAudio: false
     },
     createdAt: firebase.firestore.FieldValue.serverTimestamp(),
     updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
     lastSeenAt: firebase.firestore.FieldValue.serverTimestamp()
   }).then(doc => {
     console.log('Device ID:', doc.id);
   });
   ```

### Step 3: Update Simulator Config

Edit `/workspaces/BabyCareApp/device_simulator/lib/screens/simulator_screen.dart`:

```dart
// Line 15-16: Update these values
String _selectedBabyId = 'YOUR_BABY_ID_HERE';  // From step 3
String _deviceId = 'simulator-001';            // Keep this
```

### Step 4: Start Device Simulator

```bash
cd /workspaces/BabyCareApp/device_simulator

# Install dependencies
$HOME/flutter/bin/flutter pub get

# Start simulator
$HOME/flutter/bin/flutter run -d web-server --web-port=8081 --web-hostname=0.0.0.0
```

**Access:** http://localhost:8081

## Testing Scenarios

### 🧪 Test 1: Basic Vital Signs Streaming

**Goal:** Verify device simulator publishes data that appears in Flutter app

**Steps:**
1. Open **Device Simulator** (port 8081)
2. Open **Flutter App** (port 8080) in different tab
3. In Flutter app: Navigate to "Live Vitals" screen
4. In Device Simulator:
   - Click ▶️ **Play** button in app bar
   - Watch "Readings" counter increase
   - Default: publishes every 5 seconds

**Expected Results:**
- ✅ Flutter app shows "LIVE" green indicator
- ✅ Heart rate updates every 5 seconds
- ✅ Respiratory rate updates
- ✅ Temperature displays
- ✅ Values match simulator sliders
- ✅ Timestamp shows "Just now" or "X seconds ago"

**Debugging:**
- Open browser console in Flutter app
- Should see Firestore real-time listener updates
- Check Firebase Console → Firestore → `vital_signs` collection
- Verify documents are being created with correct `babyId`

---

### 🧪 Test 2: Realistic Variance Mode

**Goal:** Test natural sensor fluctuations

**Steps:**
1. In Device Simulator:
   - Enable "Realistic Variance" toggle
   - Set Heart Rate to 140 BPM
   - Click ▶️ Play
2. Watch values in Flutter app

**Expected Results:**
- ✅ Heart rate fluctuates ±2 BPM (138-142)
- ✅ Respiratory rate varies ±1 BPM
- ✅ Temperature changes ±0.1°C
- ✅ Changes look natural, not erratic
- ✅ Values stay within safe ranges

---

### 🧪 Test 3: Manual Sensor Adjustment

**Goal:** Test real-time response to manual changes

**Steps:**
1. Start streaming from simulator
2. While streaming, adjust sliders:
   - **Heart Rate:** Drag to 180 BPM
   - **R espiratory Rate:** Drag to 55 BPM
   - **Body Temp:** Drag to 38.5°C

**Expected Results:**
- ✅ Flutter app updates within 5 seconds
- ✅ Alert colors appear for abnormal values:
  - Red: HR > 170 or < 110
  - Red: RR > 55 or < 35
  - Red: Temp > 37.5 or < 36.5

---

### 🧪 Test 4: Streaming Interval Changes

**Goal:** Test different update frequencies

**Steps:**
1. Stop streaming (if running)
2. Change "Stream Interval" to **1 second**
3. Start streaming
4. Watch Flutter app update frequency
5. Change to **30 seconds**
6. Observe slower updates

**Expected Results:**
- ✅ 1s interval: Very frequent updates
- ✅ 30s interval: Updates every 30 seconds
- ✅ "Last publish" time updates correctly
- ✅ No data loss regardless of interval

---

### 🧪 Test 5: Device Disconnection Simulation

**Goal:** Test offline detection

**Steps:**
1. Start streaming
2. Click ⏹️ **Stop** button in simulator
3. Wait 60 seconds
4. Check Flutter app

**Expected Results:**
- ✅ "LIVE" indicator turns to "OFFLINE"
- ✅ Shows last known vital signs
- ✅ Displays "Last seen: X minutes ago"
- ✅ (If Cloud Function implemented) Gets disconnection alert

---

### 🧪 Test 6: Reconnection Flow

**Goal:** Test device coming back online

**Steps:**
1. After stopping (Test 5)
2. Click ▶️ **Play** button again
3. Watch Flutter app

**Expected Results:**
- ✅ "OFFLINE" changes back to "LIVE"
- ✅ New vitals appear
- ✅ Timestamp resets to "Just now"
- ✅ Reading counter continues from previous count

---

### 🧪 Test 7: Multi-Device Testing

**Goal:** Test multiple devices for same baby

**Setup:**
1. Register second simulator device in Firestore:
   ```javascript
   firebase.firestore().collection('devices').add({
     name: 'Simulator Device 2',
     deviceId: 'simulator-002',
     familyId: 'YOUR_FAMILY_ID',
     assignedBabyId: 'YOUR_BABY_ID',
     status: 'online',
     // ... rest of fields
   });
   ```

2. Open simulator in **two browser tabs**
3. Update `_deviceId` in one tab to `simulator-002`

**Steps:**
1. Start streaming from **both** tabs
2. Set different heart rates in each
3. Watch Flutter app

**Expected Results:**
- ✅ Both devices appear in Devices list
- ✅ Live Vitals can switch between devices
- ✅ Each device shows its own sensor values
- ✅ No data mixing between devices

---

### 🧪 Test 8: Family Isolation

**Goal:** Verify users only see their own family's data

**Setup:**
1. Create **second user** in Flutter app:
   - Email: `family2@example.com`
   - Password: `TestPassword123!`
2. Creates new family automatically
3. Register device for Family 2

**Steps:**
1. Login as User 1 → See "simulator-001"
2. Logout
3. Login as User 2 → Should NOT see "simulator-001"

**Expected Results:**
- ✅ User 1 sees only their devices
- ✅ User 2 sees only their devices
- ✅ No cross-family data visibility
- ✅ Vital signs filtered by familyId

---

### 🧪 Test 9: Historical Data & Charts

**Goal:** Test data accumulation over time

**Steps:**
1. Start simulator streaming
2. Let it run for 5+ minutes
3. In Flutter app: Go to History/Charts screen
4. Check data visualization

**Expected Results:**
- ✅ Line charts show trend over time
- ✅ Heart rate plotted correctly
- ✅ Temperature curve visible
- ✅ Can zoom/pan charts
- ✅ Data points match published values

---

### 🧪 Test 10: Performance & Load

**Goal:** Test high-frequency data streaming

**Steps:**
1. Set Stream Interval to **1 second**
2. Enable Realistic Variance
3. Let run for **10 minutes** (600 readings)
4. Monitor:
   - Browser console for errors
   - Firebase Console → Firestore usage
   - Flutter app responsiveness

**Expected Results:**
- ✅ No memory leaks
- ✅ App remains responsive
- ✅ Firestore write quota not exceeded
- ✅ Real-time listener handles load
- ✅ Charts update smoothly

---

## Quick Test Commands

### Check Simulator is Publishing
```bash
# Watch Firestore for new vitals
firebase firestore:get vital_signs --limit 5 --order-by timestamp desc
```

### Monitor Real-time in Browser Console
```javascript
// In Flutter app console
firebase.firestore().collection('vital_signs')
  .where('deviceId', '==', 'simulator-001')
  .orderBy('timestamp', 'desc')
  .limit(1)
  .onSnapshot(snapshot => {
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`HR: ${data.heartRate}, RR: ${data.respiratoryRate}, Temp: ${data.bodyTemperature}`);
    });
  });
```

### Cleanup Test Data
```javascript
// Delete all simulator readings
firebase.firestore().collection('vital_signs')
  .where('source', '==', 'simulator')
  .get()
  .then(snapshot => {
    const batch = firebase.firestore().batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    return batch.commit();
  })
  .then(() => console.log('✅ Cleaned up simulator data'));
```

## Troubleshooting

### Simulator not publishing

1. **Check Firebase connection:**
   - Open simulator browser console
   - Should see: "🔥 Connected to Production Firebase"

2. **Verify IDs match:**
   ```dart
   // In simulator_screen.dart
   String _selectedBabyId = '...';  // Must match actual baby
   ```

3. **Check Firestore rules:** Allow writes from device

### Flutter app not showing vitals

1. **Check baby assigned to device:**
   - Device must have `assignedBabyId`
   - Must match baby you're viewing

2. **Verify real-time listener:**
   - Open browser console
   - Look for Firestore snapshot errors

3. **Check familyId filtering:**
   - Device `familyId` must match user's family

### Data visible but not updating

1. **Clear browser cache**
2. **Refresh Flutter app**
3. **Check simulator is still streaming** (watch counter)
4. **Verify timestamp** is recent in Firestore

## Next Steps

After successful testing:
1. ✅ Implement Cloud Function for heartbeat monitoring
2. ✅ Add push notifications for alerts
3. ✅ Test with real ESP32 hardware
4. ✅ Deploy to production
5. ✅ iOS/Android mobile app testing
