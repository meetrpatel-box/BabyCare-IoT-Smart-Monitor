# Complete Testing Guide - Web Emulator with Firebase

## Prerequisites
- ✅ Firebase project: `baby-track-dev-437216`
- ✅ Flutter web app running
- ✅ Chrome browser for testing

## Test Scenarios

### 🧪 Test 1: Firebase Connection
**Goal:** Verify app connects to Firebase successfully

**Steps:**
1. Start app: `flutter run -d chrome`
2. Open browser console (F12)
3. Look for Firebase initialization logs
4. Check for any connection errors

**Expected:**
- No red errors in console
- App loads without crashes
- Firebase logo/indicators show connected

---

### 🧪 Test 2: Authentication Flow
**Goal:** Test signup, login, logout with email/password

#### Test 2A: New User Signup
**Steps:**
1. Click "Sign Up" on welcome screen
2. Enter email: `parent1@test.com`
3. Enter password: `Password123!`
4. Enter name: `Test Parent 1`
5. Click "Create Account"

**Expected:**
- ✅ User created in Firebase Authentication
- ✅ User document created in `users` collection
- ✅ Family automatically created in `families` collection
- ✅ User added to family as owner
- ✅ Redirects to dashboard

**Verify in Firebase Console:**
```
Authentication > Users:
  - parent1@test.com (UID: abc123...)

Firestore > users > {userId}:
  {
    email: "parent1@test.com",
    displayName: "Test Parent 1",
    familyIds: ["family_xyz"],
    createdAt: timestamp
  }

Firestore > families > {familyId}:
  {
    name: "Test Parent 1's Family",
    ownerId: "abc123...",
    members: [{
      userId: "abc123...",
      email: "parent1@test.com",
      role: "owner",
      joinedAt: timestamp
    }]
  }
```

#### Test 2B: Login with Existing User
**Steps:**
1. Logout from app
2. Click "Login"
3. Enter email: `parent1@test.com`
4. Enter password: `Password123!`
5. Click "Sign In"

**Expected:**
- ✅ Authentication succeeds
- ✅ Redirects to dashboard
- ✅ Shows family name in header

#### Test 2C: Logout
**Steps:**
1. Click profile icon
2. Click "Logout"

**Expected:**
- ✅ Returns to welcome screen
- ✅ User session cleared

---

### 🧪 Test 3: Device Claim Token Generation
**Goal:** Test secure token creation for device provisioning

**Steps:**
1. Login as `parent1@test.com`
2. Go to "Devices" screen
3. Click "Add Device" or "WiFi Setup"
4. Enter WiFi credentials:
   - SSID: `TestNetwork`
   - Password: `wifi123`
5. Check browser console for claim token log

**Expected Console Output:**
```
Creating claim token for device provisioning
Claim Token: CLAIM-1738742400-a1b2c3
Family ID: family_xyz
User ID: abc123
Expires at: [timestamp + 10min]
```

**Verify in Firestore:**
```
Firestore > deviceClaims > CLAIM-1738742400-a1b2c3:
  {
    token: "CLAIM-1738742400-a1b2c3",
    familyId: "family_xyz",
    userId: "abc123",
    createdAt: timestamp,
    expiresAt: timestamp + 10min,
    status: "pending"
  }
```

---

### 🧪 Test 4: WiFi Provisioning (Web Simulation)
**Goal:** Simulate device provisioning flow without real hardware

**Steps:**
1. On WiFi setup screen, enter:
   - SSID: `HomeWiFi`
   - Password: `SecurePass123`
2. Click "Connect"
3. Since we're on web (no BLE), it will log the provisioning data

**Expected Console Output:**
```
BLE not available (web platform)
Provisioning would send:
  - SSID: HomeWiFi
  - Password: SecurePass123
  - Claim Token: CLAIM-xxx
Using demo mode for web testing
```

**Manual Device Registration (Simulating ESP32):**
Open browser console and run:
```javascript
// Simulate ESP32 registering with Firebase
const deviceData = {
  name: "Baby Monitor #1",
  familyId: "family_xyz", // Copy from claim token
  hardwareId: "ESP32-DEV-001",
  model: "ESP32-CAM",
  firmwareVersion: "1.0.0",
  status: "online",
  capabilities: {
    camera: true,
    microphone: true,
    temperature: true,
    heartRate: true,
    motionDetection: true
  },
  wifiInfo: {
    ssid: "HomeWiFi",
    rssi: -45,
    ipAddress: "192.168.1.100"
  },
  createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  lastSeenAt: firebase.firestore.FieldValue.serverTimestamp()
};

firebase.firestore().collection('devices').add(deviceData)
  .then(doc => console.log('Device registered:', doc.id));
```

**Expected:**
- ✅ New device document created in Firestore
- ✅ Device appears in app's "Devices" screen
- ✅ Status shows "online"

---

### 🧪 Test 5: Device Ownership Isolation
**Goal:** Verify users only see their family's devices

#### Setup: Create Second User/Family
1. Logout from `parent1@test.com`
2. Sign up as new user:
   - Email: `parent2@test.com`
   - Password: `Password123!`
   - Name: `Test Parent 2`

3. Manually create device for Family 2 in Firebase Console:
```
Firestore > devices > [Add Document]:
  {
    name: "Baby Monitor #2",
    familyId: "[Family2's ID from families collection]",
    hardwareId: "ESP32-DEV-002",
    status: "online",
    createdAt: [auto],
    lastSeenAt: [auto]
  }
```

#### Test Isolation
**Steps:**
1. Login as `parent1@test.com`
2. Go to "Devices" screen
3. Count devices shown

**Expected:**
- ✅ Only shows "Baby Monitor #1" (Family 1's device)
- ❌ Does NOT show "Baby Monitor #2" (Family 2's device)

4. Logout, login as `parent2@test.com`
5. Go to "Devices" screen

**Expected:**
- ✅ Only shows "Baby Monitor #2" (Family 2's device)
- ❌ Does NOT show "Baby Monitor #1" (Family 1's device)

---

### 🧪 Test 6: Baby Profile Creation
**Goal:** Test baby data management

**Steps:**
1. Login as `parent1@test.com`
2. If onboarding shows, fill baby form:
   - Name: `Baby Emma`
   - Date of Birth: `2026-02-01`
   - Gender: `Female`
3. Upload photo (optional)
4. Click "Save"

**Expected:**
- ✅ Baby document created in Firestore
- ✅ Baby linked to family
- ✅ Dashboard shows baby name

**Verify in Firestore:**
```
Firestore > babies > {babyId}:
  {
    name: "Baby Emma",
    dateOfBirth: timestamp,
    gender: "female",
    familyId: "family_xyz",
    createdAt: timestamp
  }

Firestore > families > {familyId}:
  {
    ...existing fields...
    babyIds: ["baby_abc123"]
  }
```

---

### 🧪 Test 7: Vital Signs Streaming
**Goal:** Test real-time vital signs data flow

#### Setup: Send Test Vitals to Firebase
Run in browser console:
```javascript
// Get your device ID from Firestore
const deviceId = "YOUR_DEVICE_ID";
const babyId = "YOUR_BABY_ID";

// Send 10 vital signs readings
for (let i = 0; i < 10; i++) {
  setTimeout(() => {
    const vitalData = {
      deviceId: deviceId,
      babyId: babyId,
      heartRate: 120 + Math.floor(Math.random() * 20),
      temperature: 36.8 + (Math.random() * 0.8),
      respiratoryRate: 40 + Math.floor(Math.random() * 10),
      timestamp: firebase.firestore.FieldValue.serverTimestamp()
    };
    
    firebase.firestore().collection('vital_signs').add(vitalData)
      .then(() => console.log(`Sent vital #${i+1}`));
  }, i * 5000); // Send every 5 seconds
}, 0);
```

**Expected in App:**
1. Go to "Live Vitals" screen
2. See real-time updates every 5 seconds
3. Heart rate changes: 120-140 BPM
4. Temperature: 36.8-37.6°C
5. Respiratory rate: 40-50 breaths/min
6. Status indicator shows "LIVE" (green)

---

### 🧪 Test 8: Device Disconnection Detection
**Goal:** Test offline detection when vitals stop

#### Part A: Stop Sending Vitals
**Steps:**
1. Stop the vital signs loop from Test 7
2. Wait 60 seconds
3. Refresh app

**Expected:**
- ⏳ After 60s: Status should show "OFFLINE" (needs Cloud Function)
- 📱 App shows last known vital sign with timestamp
- 🔴 Red indicator in Live Vitals screen

#### Part B: Reconnection
**Steps:**
1. Send new vital sign (run console script again)
2. Watch app update in real-time

**Expected:**
- ✅ Status changes to "LIVE"
- ✅ New readings appear
- ✅ Timeline continues

---

### 🧪 Test 9: Family Invitations
**Goal:** Test second member joining family

#### Create Invitation
**Steps:**
1. Login as `parent1@test.com` (family owner)
2. Go to Settings > Family Members
3. Click "Invite Member"
4. Enter email: `parent2@test.com`
5. Select role: `parent`
6. Click "Send Invite"

**Expected:**
- ✅ Invite created in `familyInvites` collection
- ✅ Shows pending invite in UI

**Verify in Firestore:**
```
Firestore > familyInvites > {inviteId}:
  {
    familyId: "family_xyz",
    inviterUserId: "abc123",
    inviteeEmail: "parent2@test.com",
    role: "parent",
    status: "pending",
    createdAt: timestamp,
    expiresAt: timestamp + 7 days
  }
```

#### Accept Invitation
**Steps:**
1. Logout
2. Login as `parent2@test.com`
3. Should see invitation notification
4. Click "Accept"

**Expected:**
- ✅ User added to Family 1's members array
- ✅ User's familyIds updated
- ✅ Invite status = "accepted"
- ✅ Can now see Family 1's devices and baby

---

### 🧪 Test 10: Multi-Device Scenario
**Goal:** One family with multiple devices

**Steps:**
1. Login as `parent1@test.com`
2. Create 3 devices manually in Firestore (all with family_xyz)
3. Assign each device to same baby
4. Send vitals from multiple devices

**Expected:**
- ✅ All 3 devices show in Devices screen
- ✅ Dashboard shows combined vitals
- ✅ Can filter by device

---

## Quick Test Checklist

Copy this to track your testing progress:

```
□ Firebase connection established
□ User signup creates user + family
□ User login/logout works
□ Claim token generated on WiFi setup
□ Device appears after manual registration
□ User 1 only sees Family 1 devices
□ User 2 only sees Family 2 devices
□ Baby profile creates and links to family
□ Real-time vitals stream updates UI
□ LIVE indicator shows when data flows
□ OFFLINE shows when vitals stop (needs Cloud Function)
□ Family invitation sent successfully
□ Second member accepts and joins family
□ Multi-device setup works correctly
```

---

## Common Issues & Solutions

### Issue: "Permission Denied" errors
**Solution:** Check Firebase Security Rules
```javascript
// Firestore Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /families/{familyId} {
      allow read: if request.auth != null && 
        request.auth.uid in resource.data.members.map(m => m.userId);
      allow write: if request.auth != null;
    }
    match /devices/{deviceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /vital_signs/{vitalId} {
      allow read: if request.auth != null;
      allow write: if true; // ESP32 writes without auth
    }
  }
}
```

### Issue: "User not found" after signup
**Check:** 
1. Firebase Console > Authentication > Users
2. Firestore > users collection
3. Browser console for errors

### Issue: Devices not showing
**Debug:**
```javascript
// Run in console
firebase.firestore().collection('devices')
  .where('familyId', '==', 'YOUR_FAMILY_ID')
  .get()
  .then(snapshot => {
    console.log('Devices found:', snapshot.size);
    snapshot.forEach(doc => console.log(doc.data()));
  });
```

### Issue: Vitals not updating
**Check:**
1. Device status is "online"
2. babyId matches
3. Firestore rules allow writes
4. Browser console for stream errors

---

## Next Steps After Testing

Once all tests pass:
1. ✅ Deploy Firebase Security Rules
2. ✅ Implement Cloud Function for heartbeat monitoring
3. ✅ Add push notification setup
4. ✅ Configure iOS Info.plist for mobile
5. ✅ Test on real Android/iOS device
6. ✅ Integrate real ESP32 hardware
