# 🧪 Integration Testing Guide

Complete guide to test the BabyTrack system with Firebase emulators and device simulator.

---

## 🎯 Quick Start (3 Steps)

### **1. Start Firebase Emulators**

```bash
./start-testing-env.sh
```

This will start:
- ✅ Firestore Emulator (port 8080)
- ✅ Auth Emulator (port 9099)
- ✅ Storage Emulator (port 9199)
- ✅ Functions Emulator (port 5001)
- ✅ Emulator UI (http://localhost:4000)

### **2. Start Device Simulator** (Terminal 2)

```bash
cd device_simulator
flutter run -d chrome
```

This opens the **AnvayaPod Simulator** web app.

### **3. Start Main App** (Terminal 3)

```bash
cd baby_track_flutter
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

This opens the **BabyTrack App** connected to emulators.

---

## 🧪 Testing Scenarios

### **Scenario 1: Test Vital Signs Streaming**

**In Device Simulator (Chrome Tab 1):**

1. Set sensor values:
   - Heart Rate: 140 BPM
   - Respiratory Rate: 40 BPM
   - Body Temp: 37.0°C

2. Enable "Realistic Variance"

3. Set streaming interval: 5 seconds

4. Click **▶️ Start Streaming**

**In Main App (Chrome Tab 2):**

5. Navigate to Dashboard

6. Watch vitals update in real-time every 5 seconds

7. Verify values match simulator

**Expected Result:** ✅ Vitals display updates automatically

---

### **Scenario 2: Test Milestone Auto-Detection**

**In Device Simulator:**

1. Click **"Long Sleep (6h)"** trigger button

2. This publishes a sleep event to Firestore

**In Firestore Emulator UI (http://localhost:4000):**

3. Navigate to Firestore tab

4. Check `device_events` collection

5. Should see new document with `eventType: "long_sleep_6h"`

**In Main App:**

6. Cloud Function should detect the event (if deployed)

7. New milestone appears: "First 6-Hour Sleep! 🌙"

**Expected Result:** ✅ Milestone auto-created from device event

---

### **Scenario 3: Test Photo Upload with Storage Quota**

**In Main App:**

1. Login as free tier user

2. Navigate to Photos

3. Try to upload 101st photo

**Expected Result:** 
- ✅ First 100 photos: Upload successful
- ✅ 101st photo: Error "Storage limit reached. Upgrade to Premium"
- ✅ Premium upsell dialog appears

---

### **Scenario 4: Test Firebase Rules**

**In Firestore Emulator UI:**

1. Go to Firestore tab

2. Try to manually create a milestone document

3. Without proper authentication, should fail

**Expected Result:** ✅ Security rules enforced

---

## 📊 View Test Data

### **Firestore Data**

Open: http://localhost:4000/firestore

Collections to check:
- `babies` - Baby profiles
- `vital_signs` - Real-time sensor data
- `milestones` - Logged milestones
- `device_events` - Trigger events
- `photos` - Photo metadata
- `user_storage_usage` - Storage quota tracking

### **Auth Users**

Open: http://localhost:4000/auth

Test users:
- test@example.com (Premium tier)
- free@example.com (Free tier)

### **Storage Files**

Open: http://localhost:4000/storage

Check uploaded photos and thumbnails.

---

## 🔧 Troubleshooting

### **Problem: "Can't connect to emulators"**

**Solution:**
```bash
# Check if emulators are running
curl http://localhost:4000

# If not, start them
firebase emulators:start
```

### **Problem: "Main app not updating with simulator data"**

**Solution:**
1. Verify emulator flag: `--dart-define=USE_EMULATOR=true`
2. Check console for "Connected to emulators" message
3. Verify simulator is publishing (check console logs)
4. Check Firestore emulator UI for new documents

### **Problem: "Flutter not found"**

**Solution:**
```bash
# This is a dev container - Flutter needs to be installed
# For now, test architecture is ready but Flutter isn't available
```

---

## 🎨 Testing Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    Testing Environment                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Terminal 1: Firebase Emulators                             │
│  ├── Firestore (localhost:8080)                             │
│  ├── Auth (localhost:9099)                                  │
│  ├── Storage (localhost:9199)                               │
│  ├── Functions (localhost:5001)                             │
│  └── UI (localhost:4000) ← View all data here               │
│                                                              │
│  Terminal 2: Device Simulator (Chrome Tab 1)                │
│  ├── Adjust sensor values with sliders                      │
│  ├── Start/stop streaming                                   │
│  ├── Trigger milestone events                               │
│  └── Publishes to → Firestore Emulator                      │
│                                                              │
│  Terminal 3: Main App (Chrome Tab 2)                        │
│  ├── Reads from ← Firestore Emulator                        │
│  ├── Displays real-time vitals                              │
│  ├── Shows detected milestones                              │
│  └── Tests feature gating (Free/Premium)                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Test Checklist

### **Device Simulator**
- [ ] Can adjust all sensor values
- [ ] Streaming publishes to Firestore
- [ ] Realistic variance works
- [ ] Milestone triggers create events
- [ ] Device ID visible in data

### **Main App**
- [ ] Connects to emulator successfully
- [ ] Displays real-time vitals
- [ ] Updates when simulator publishes
- [ ] Free tier quota enforced
- [ ] Premium features locked appropriately

### **Firebase Emulators**
- [ ] Firestore data persists
- [ ] Auth works locally
- [ ] Storage uploads work
- [ ] Emulator UI accessible
- [ ] Security rules enforced

### **Integration**
- [ ] Data flows: Simulator → Firestore → App
- [ ] Real-time updates work
- [ ] Cloud Functions trigger (if deployed)
- [ ] Milestone auto-detection works
- [ ] No production Firebase calls

---

## 📝 Next Steps After Testing

1. **Document bugs found**
2. **Write automated integration tests**
3. **Add more test scenarios**
4. **Deploy Cloud Functions to emulator**
5. **Test with multiple babies**
6. **Test concurrent users**
7. **Performance testing**

---

## 🚀 Production Deployment

When ready for production:

```bash
# Run main app WITHOUT emulator flag
cd baby_track_flutter
flutter run -d chrome

# This connects to real Firebase (production)
```

⚠️ **Never run device simulator against production!**

---

**Questions? Issues?**

Check the console logs in all 3 terminals for detailed debug info.
