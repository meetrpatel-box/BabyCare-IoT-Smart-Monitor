# WiFi Provisioning Flow - Complete Architecture

## 📋 Overview: Device → Firebase ← App Communication

```
┌─────────────┐        ┌──────────────┐        ┌─────────────┐
│   ESP32     │        │   Firebase   │        │  Flutter    │
│   Device    │◄──────►│  (Backend)   │◄──────►│    App      │
│  (Anvaya)   │  MQTT  │              │  REST  │  (Mobile)   │
└─────────────┘        └──────────────┘        └─────────────┘
      │                       │                        │
      │                       │                        │
   Sensors              Firestore DB             User Interface
   WiFi                 Auth                     WiFi Config
   Bluetooth            Storage                  Monitoring
```

## 🔄 Complete Provisioning Flow

### Phase 1: Initial Setup (App → Device via Bluetooth)

**Step 1: Device Discovery**
```
1. User clicks "Set Up Device" in app
2. App enables Bluetooth
3. ESP32 in provisioning mode broadcasts BLE:
   - Service UUID: esp_prov_service
   - Device name: "ANVAYA_XXXXXX"
4. App scans for BLE devices
5. Shows list of discovered devices
```

**Step 2: BLE Connection**
```
1. User selects device from list
2. App connects to ESP32 via BLE
3. ESP32 sends device info:
   {
     "deviceId": "anvaya-pod-001",
     "firmwareVersion": "1.0.0",
     "capabilities": ["heartRate", "respiration", "temperature"]
   }
```

**Step 3: WiFi Credentials Transfer**
```
1. App scans for available WiFi networks
2. User enters WiFi password
3. App sends to ESP32 via BLE (encrypted):
   {
     "ssid": "HomeWiFi",
     "password": "********",
     "security": "WPA2"
   }
4. ESP32 attempts to connect to WiFi
5. Sends status back to app:
   - "connecting" → "connected" → "ip_assigned"
```

---

### Phase 2: Cloud Registration (Device → Firebase)

**Step 4: Device Claims Cloud Connection**
```
1. ESP32 now has internet (WiFi connected)
2. Makes HTTPS POST to Firebase Cloud Function:
   POST /registerDevice
   {
     "deviceId": "anvaya-pod-001",
     "macAddress": "AA:BB:CC:DD:EE:FF",
     "firmwareVersion": "1.0.0",
     "localIP": "192.168.1.100"
   }

3. Cloud Function (Node.js):
   - Validates device signature
   - Creates Firestore document:
     /devices/{deviceId}
     {
       "status": "active",
       "registeredAt": timestamp,
       "lastSeen": timestamp,
       "sensors": {...}
     }
   - Returns auth token for MQTT
```

**Step 5: App Links Device to Baby Profile**
```
1. App sends to Firebase (via REST API):
   POST /linkDeviceToBaby
   {
     "deviceId": "anvaya-pod-001",
     "babyId": "baby_12345",
     "parentUserId": "user_abc"
   }

2. Firestore update:
   /babies/{babyId}
   {
     "deviceId": "anvaya-pod-001",
     "linkedAt": timestamp
   }
```

---

### Phase 3: Real-Time Data Flow (Device → Firebase → App)

**Option A: MQTT (Recommended for low latency)**

```
Device → MQTT Broker → Cloud Function → Firestore → App

1. ESP32 publishes to MQTT topic:
   Topic: devices/anvaya-pod-001/vitals
   {
     "heartRate": 135,
     "respiratoryRate": 40,
     "temperature": 36.8,
     "timestamp": 1707123456789
   }

2. Cloud Function subscribes to topic:
   - Validates data
   - Adds metadata (babyId from device mapping)
   - Writes to Firestore:
     /vital_signs/{doc_id}
     {
       "babyId": "baby_12345",
       "deviceId": "anvaya-pod-001",
       "heartRate": 135,
       ...
     }

3. App listens to Firestore real-time:
   firestore.collection('vital_signs')
     .where('babyId', '==', babyId)
     .orderBy('timestamp', 'desc')
     .limit(1)
     .snapshots()
   
   → Updates UI within ~500ms
```

**Option B: Direct HTTPS POST (Simpler but higher latency)**

```
Device → Cloud Function → Firestore → App

1. ESP32 HTTP POST every 5 seconds:
   POST https://us-central1-PROJECT.cloudfunctions.net/recordVitals
   {
     "deviceId": "anvaya-pod-001",
     "vitals": {
       "heartRate": 135,
       "respiratoryRate": 40,
       "temperature": 36.8
     },
     "timestamp": 1707123456789
   }

2. Cloud Function (Node.js):
   exports.recordVitals = functions.https.onRequest(async (req, res) => {
     const { deviceId, vitals, timestamp } = req.body;
     
     // Get baby ID from device
     const device = await admin.firestore()
       .collection('devices')
       .doc(deviceId)
       .get();
     const babyId = device.data().babyId;
     
     // Store vitals
     await admin.firestore()
       .collection('vital_signs')
       .add({
         babyId,
         deviceId,
         ...vitals,
         timestamp: admin.firestore.Timestamp.fromMillis(timestamp)
       });
     
     res.json({ success: true });
   });

3. App gets real-time updates via Firestore listener
```

---

## 📡 Technical Implementation Details

### ESP32 Side (Firmware - C++)

```cpp
// 1. BLE Provisioning
#include <WiFiProv.h>
#include <wifi_provisioning/manager.h>

void setupProvisioning() {
  WiFiProv.beginProvision(
    WIFI_PROV_SCHEME_BLE,
    WIFI_PROV_SCHEME_HANDLER_FREE_BTDM,
    WIFI_PROV_SECURITY_1,
    "anvaya-pod-001",
    "prov_service"
  );
}

// 2. WiFi Connection Callback
void onWiFiConnected() {
  Serial.println("WiFi Connected!");
  registerWithCloud();
}

// 3. Cloud Registration
void registerWithCloud() {
  HTTPClient http;
  http.begin("https://PROJECT.cloudfunctions.net/registerDevice");
  http.addHeader("Content-Type", "application/json");
  
  String payload = "{\"deviceId\":\"" + deviceId + "\"}";
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    startSensorLoop();
  }
}

// 4. Send Vitals
void sendVitals() {
  HTTPClient http;
  http.begin("https://PROJECT.cloudfunctions.net/recordVitals");
  
  String payload = "{\"deviceId\":\"" + deviceId + 
                   "\",\"heartRate\":" + String(heartRate) + "}";
  http.POST(payload);
}
```

### Flutter Side (App - Dart)

```dart
// 1. BLE Device Discovery
import 'package:esp_provisioning/esp_provisioning.dart';

Future<void> startProvisioning() async {
  // Scan for BLE devices
  final devices = await EspProvisioning.searchESPDevices();
  
  // Connect to selected device
  await EspProvisioning.establishSession(deviceName: 'ANVAYA_001');
  
  // Send WiFi credentials
  await EspProvisioning.sendWifiConfig(
    ssid: 'HomeWiFi',
    password: 'password123',
  );
  
  // Wait for connection
  final status = await EspProvisioning.getStatus();
  if (status == 'connected') {
    await linkDeviceToFirebase();
  }
}

// 2. Link Device in Firebase
Future<void> linkDeviceToFirebase() async {
  final user = FirebaseAuth.instance.currentUser!;
  
  // Create baby profile
  final babyRef = await FirebaseFirestore.instance
    .collection('babies')
    .add({
      'name': 'Baby Emma',
      'parentId': user.uid,
      'deviceId': 'anvaya-pod-001',
      'createdAt': FieldValue.serverTimestamp(),
    });
  
  // Update device with baby link
  await FirebaseFirestore.instance
    .collection('devices')
    .doc('anvaya-pod-001')
    .set({
      'babyId': babyRef.id,
      'status': 'active',
      'linkedAt': FieldValue.serverTimestamp(),
    });
}

// 3. Listen for Real-Time Data
Stream<VitalSign> listenToVitals(String babyId) {
  return FirebaseFirestore.instance
    .collection('vital_signs')
    .where('babyId', isEqualTo: babyId)
    .orderBy('timestamp', descending: true)
    .limit(1)
    .snapshots()
    .map((snapshot) => 
      VitalSign.fromFirestore(snapshot.docs.first)
    );
}
```

### Firebase Cloud Functions (Backend - Node.js)

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 1. Device Registration
exports.registerDevice = functions.https.onRequest(async (req, res) => {
  const { deviceId, macAddress, firmwareVersion } = req.body;
  
  // Validate device signature
  // ... security checks ...
  
  // Register in Firestore
  await admin.firestore().collection('devices').doc(deviceId).set({
    macAddress,
    firmwareVersion,
    status: 'active',
    registeredAt: admin.firestore.FieldValue.serverTimestamp(),
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  res.json({ success: true, deviceId });
});

// 2. Record Vitals
exports.recordVitals = functions.https.onRequest(async (req, res) => {
  const { deviceId, vitals, timestamp } = req.body;
  
  // Get baby ID from device
  const deviceDoc = await admin.firestore()
    .collection('devices')
    .doc(deviceId)
    .get();
  
  if (!deviceDoc.exists) {
    return res.status(404).json({ error: 'Device not found' });
  }
  
  const babyId = deviceDoc.data().babyId;
  
  // Store vitals
  await admin.firestore().collection('vital_signs').add({
    babyId,
    deviceId,
    heartRate: vitals.heartRate,
    respiratoryRate: vitals.respiratoryRate,
    bodyTemperature: vitals.temperature,
    timestamp: admin.firestore.Timestamp.fromMillis(timestamp),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Update device last seen
  await deviceDoc.ref.update({
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  res.json({ success: true });
});
```

---

## 🔐 Security Considerations

1. **Device Authentication**: ESP32 signs requests with device secret
2. **HTTPS Only**: All cloud communication encrypted
3. **Firebase Rules**: Users can only read their own baby's data
4. **BLE Encryption**: Provisioning uses secure pairing
5. **Token Rotation**: MQTT tokens expire and refresh

---

## 📊 Data Flow Summary

**Upload (Device → Cloud → App)**
```
ESP32 Sensors → WiFi → Cloud Function → Firestore → App Listener
   (every 3-5s)    (HTTPS)   (validate)    (write)    (real-time)
```

**Download (App → Cloud → Device)**
```
App Settings → Firestore → Cloud Function → MQTT → ESP32
   (button)      (write)     (trigger)      (pub)   (receive)
```

---

## 🎯 Current Implementation Status

✅ **Completed:**
- Firebase Firestore structure
- Flutter app UI and real-time listeners
- Error handling and user guidance
- Device setup wizard UI

🚧 **Pending:**
- ESP32 firmware WiFi provisioning code
- BLE provisioning library integration in Flutter
- Cloud Functions for device registration
- MQTT broker setup (or use Cloud IoT Core)

---

This is the complete architecture! The flow is:
**App provisions device → Device connects to Firebase → Firebase stores data → App displays real-time**
