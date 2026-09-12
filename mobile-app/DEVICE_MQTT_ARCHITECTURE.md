# ESP32 Device Discovery & MQTT Communication Architecture

## Current Flow Analysis ✅

### 1. Device Discovery (BLE + WiFi Provisioning)

**Entry Point:** Dashboard → "Add Device" Button  
**Flow:**
```
User (Dashboard)
    ↓
DeviceSetupScreen (device_setup_screen.dart)
    ↓
BLE Scan (WifiProvisioningService)
    ↓
ESP32 Broadcasts (BLE: ESP_PROV_xxxx)
    ↓
User Selects Device
    ↓
WiFi Provisioning (via BLE)
    ↓
ESP32 Connects to Router
    ↓
Device Registered in Firestore
```

### 2. Device Storage (Firestore)

**Collection:** `devices`  
**Schema:**
```dart
{
  'id': string (doc ID),
  'familyId': string,
  'name': string,
  'status': enum (online/offline/error),
  'assignedBabyId': string?,
  'createdAt': timestamp,
  'updatedAt': timestamp,
  'lastSeenAt': timestamp,
  'wifiInfo': {
    'ssid': string,
    'ip': string,
    'signal': int
  }
}
```

### 3. New MQTT Communication Flow (Phase 2)

**After** WiFi provisioning completes:

```
┌─────────────────────────────────────────────────────────┐
│ Android App                                             │
├─────────────────────────────────────────────────────────┤
│ • Dashboard: Device Status Widget                        │
│ • MQTT Service: Connected to Broker                      │
│ • Provider: Listening to device topics                   │
└────────────────┬────────────────────────────────────────┘
                 │ MQTT (tcp://10.82.215.241:1883)
                 ↓
┌─────────────────────────────────────────────────────────┐
│ Mosquitto MQTT Broker                                   │
├─────────────────────────────────────────────────────────┤
│ • cradle/device001/status (ESP → Android)               │
│ • cradle/device001/cmd (Android → ESP)                  │
│ • cradle/device001/config (Config updates)              │
└────────────────┬────────────────────────────────────────┘
                 │ MQTT (tcp://192.168.150.241:1883)
                 ↓
┌─────────────────────────────────────────────────────────┐
│ ESP32-S3 Korvo-2                                        │
├─────────────────────────────────────────────────────────┤
│ • WiFi Connected (192.168.150.103)                      │
│ • MQTT Connected (esp-mqtt library)                     │
│ • Microphone Ready                                       │
│ • Status Updates Published                              │
└─────────────────────────────────────────────────────────┘
```

## Phase 2 Implementation Plan

### Step 1: Device Discovery Enhancement
- Capture device MAC/IP during BLE provisioning
- Store device identifier in Firestore
- Map Firestore device → MQTT topic (device001)

### Step 2: Create Device Status Dashboard
- Show MQTT connection status
- Display device online/offline state
- Show last activity timestamp
- Display WiFi signal strength

### Step 3: Implement Command Framework
- Android publishes to `cradle/device001/cmd`
- ESP32 receives commands
- ESP32 publishes responses to `cradle/device001/status`
- UI updates in real-time

### Step 4: Test Bidirectional Communication
```
Android → ESP32: {"cmd":"ping"}
ESP32 → Android: {"status":"online","uptime":3600}
```

## Code Files to Create/Modify

### Create:
1. `lib/widgets/device_status_widget.dart` - Real-time device status display
2. `lib/models/mqtt_device_model.dart` - Device MQTT representation
3. `lib/screens/main/device_dashboard_screen.dart` - Device control panel

### Modify:
1. `lib/services/device_service.dart` - Add MQTT device mapping
2. `lib/providers/device_provider.dart` - Add MQTT state management
3. `lib/screens/main/dashboard_screen.dart` - Add device status widget

## Key Integration Points

**1. WiFi Provisioning → MQTT:**
- After device connects to WiFi, query Firestore for device
- Initialize MQTT subscription for that device's topics

**2. Device Registration:**
- Store `deviceId` (MAC or serial)
- Map to MQTT topic: `cradle/{deviceId}/cmd`
- Store mapping in Firestore

**3. Real-time Updates:**
- MQTT Provider listens to device topics
- Updates UI via ChangeNotifier
- Firestore syncs for persistence

## Architecture Verification ✅

✅ **Device Discovery:** BLE + WiFi Provisioning (existing)
✅ **Device Storage:** Firestore `devices` collection (existing)
✅ **MQTT Service:** Created and integrated
✅ **MQTT Provider:** Created for state management
✅ **Topic Structure:** `cradle/{deviceId}/{channel}` ready
✅ **Broker Connection:** Android ↔ Mosquitto ↔ ESP32

**Ready to proceed with Phase 2 implementation.**
