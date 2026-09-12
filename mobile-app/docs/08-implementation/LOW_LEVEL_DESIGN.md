# 🔧 Low-Level Design (LLD) - Data Structures & Protocol Details

**System**: BabyCareApp Real-time Monitoring  
**Date**: February 2, 2026  
**Scope**: Protocol-level implementation, memory layouts, wire formats

---

## 📋 TABLE OF CONTENTS

1. [Data Structure Definitions](#data-structure-definitions)
2. [Memory Layouts](#memory-layouts)
3. [Protocol Stack](#protocol-stack)
4. [Wire Formats](#wire-formats)
5. [API Contracts](#api-contracts)
6. [Serialization Details](#serialization-details)
7. [Network Packets](#network-packets)
8. [Firestore Protocol](#firestore-protocol)

---

## 1️⃣ DATA STRUCTURE DEFINITIONS

### **1.1 ESP32 C/C++ Structures**

#### **VitalReading (In-Memory)**
```cpp
// Size: 32 bytes (with padding)
struct VitalReading {
  uint32_t timestamp;        // Offset 0x00, 4 bytes, Unix epoch milliseconds
  uint16_t heartRate;        // Offset 0x04, 2 bytes, BPM (0-300)
  uint8_t  spO2;             // Offset 0x06, 1 byte, Percentage (0-100)
  uint8_t  _padding1;        // Offset 0x07, 1 byte, Alignment padding
  float    bodyTemp;         // Offset 0x08, 4 bytes, IEEE 754 float, Celsius
  float    envTemp;          // Offset 0x0C, 4 bytes, IEEE 754 float, Celsius
  uint8_t  breathRate;       // Offset 0x10, 1 byte, Breaths per minute
  uint8_t  motionLevel;      // Offset 0x11, 1 byte, Percentage (0-100)
  uint8_t  cryDetected;      // Offset 0x12, 1 byte, Boolean (0 or 1)
  uint8_t  _padding2;        // Offset 0x13, 1 byte, Alignment padding
  uint32_t humidity;         // Offset 0x14, 4 bytes, Percentage × 100
  uint16_t noiseLevel;       // Offset 0x18, 2 bytes, Decibels × 10
  uint8_t  ledBrightness;    // Offset 0x1A, 1 byte, PWM value (0-255)
  uint8_t  deviceStatus;     // Offset 0x1B, 1 byte, Bitmap flags
  uint32_t checksum;         // Offset 0x1C, 4 bytes, CRC32
};                           // Total: 32 bytes

// Device Status Bitmap (1 byte)
// Bit 0: WiFi connected
// Bit 1: Sensor error
// Bit 2: Low battery
// Bit 3: Motion detected
// Bit 4: Cry detected
// Bit 5: Alert sent
// Bit 6-7: Reserved
```

#### **DeviceConfig (EEPROM/Flash)**
```cpp
// Size: 128 bytes (fixed, flash-aligned)
struct DeviceConfig {
  char     magic[4];         // Offset 0x00, "BABT" signature
  uint16_t version;          // Offset 0x04, Config version
  uint16_t _reserved1;       // Offset 0x06, Reserved
  char     deviceId[32];     // Offset 0x08, Null-terminated string
  char     babyId[32];       // Offset 0x28, Null-terminated string
  char     wifiSSID[32];     // Offset 0x48, Null-terminated string
  char     wifiPassword[32]; // Offset 0x68, Null-terminated string (encrypted)
  uint32_t updateInterval;   // Offset 0x88, Milliseconds
  uint8_t  sensorFlags;      // Offset 0x8C, Enabled sensors bitmap
  uint8_t  alertFlags;       // Offset 0x8D, Enabled alerts bitmap
  uint16_t _reserved2;       // Offset 0x8E, Reserved
  uint32_t crc32;            // Offset 0x90, CRC of first 124 bytes
  uint8_t  _padding[28];     // Offset 0x94, Pad to 128 bytes
};                           // Total: 128 bytes (0x80)
```

---

### **1.2 Firestore Document Schema**

#### **VitalReading Document (Firestore)**
```javascript
// Collection: devices/{deviceId}/vitalReadings/{autoId}
{
  // Document Fields (key-value pairs)
  deviceId: {
    type: "stringValue",
    value: "AnvayaPod-A1B2"           // Max 64 chars
  },
  babyId: {
    type: "stringValue", 
    value: "baby_XYZ123"              // Max 64 chars
  },
  timestamp: {
    type: "integerValue",
    value: "1738454400000"            // Unix epoch ms as string
  },
  vitals: {
    type: "mapValue",
    fields: {
      heartRate: {
        type: "integerValue",
        value: "128"                  // 0-300 range
      },
      spO2: {
        type: "integerValue",
        value: "98"                   // 0-100 range
      },
      bodyTemp: {
        type: "doubleValue",
        value: 36.8                   // IEEE 754 double
      },
      envTemp: {
        type: "doubleValue",
        value: 24.5
      },
      breathRate: {
        type: "integerValue",
        value: "28"                   // 0-100 range
      },
      motionLevel: {
        type: "integerValue",
        value: "3"                    // 0-100 range
      },
      cryDetected: {
        type: "booleanValue",
        value: false
      },
      humidity: {
        type: "doubleValue",
        value: 45.2
      },
      noiseLevel: {
        type: "doubleValue",
        value: 42.5
      }
    }
  },
  serverTimestamp: {
    type: "timestampValue",
    value: "2026-02-02T10:30:00.123456Z"  // RFC 3339
  }
}

// Index Configuration
// Composite Index: (babyId ASC, timestamp DESC)
// Composite Index: (deviceId ASC, timestamp DESC)
```

---

### **1.3 Dart/Flutter Data Structures**

#### **LatestVitals (Dart Class)**
```dart
class LatestVitals {
  // Instance fields (memory layout varies by platform)
  final int heartRate;           // 8 bytes (Dart int is int64)
  final int spO2;                // 8 bytes
  final double temperature;      // 8 bytes (IEEE 754 double)
  final double envTemperature;   // 8 bytes
  final int breathRate;          // 8 bytes
  final int motionLevel;         // 8 bytes
  final bool cryDetected;        // 1 byte (+ padding)
  final double humidity;         // 8 bytes
  final double noiseLevel;       // 8 bytes
  final DateTime timestamp;      // ~24 bytes (object overhead)
  
  // Total instance size: ~100 bytes + object overhead (~32 bytes)
  // Actual heap allocation: ~132 bytes per instance
  
  // JSON Serialization Map
  Map<String, dynamic> toJson() => {
    'heartRate': heartRate,           // Encoded as JSON number
    'spO2': spO2,                     // Encoded as JSON number
    'temperature': temperature,        // Encoded as JSON number (float)
    'envTemperature': envTemperature,
    'breathRate': breathRate,
    'motionLevel': motionLevel,
    'cryDetected': cryDetected,       // Encoded as JSON boolean
    'humidity': humidity,
    'noiseLevel': noiseLevel,
    'timestamp': timestamp.toIso8601String(), // Encoded as JSON string
  };
  
  // Firestore Map (different from JSON)
  Map<String, dynamic> toFirestore() => {
    'heartRate': heartRate,           // Stored as Firestore integer
    'spO2': spO2,
    'temperature': temperature,        // Stored as Firestore double
    'envTemperature': envTemperature,
    'breathRate': breathRate,
    'motionLevel': motionLevel,
    'cryDetected': cryDetected,       // Stored as Firestore boolean
    'humidity': humidity,
    'noiseLevel': noiseLevel,
    'timestamp': Timestamp.fromDate(timestamp), // Stored as Firestore timestamp
  };
}
```

#### **SleepSession (Dart Class)**
```dart
class SleepSession {
  final String id;                // 20 bytes (Firestore auto-id)
  final String babyId;            // Variable length string
  final DateTime startTime;       // 24 bytes
  final DateTime? endTime;        // 24 bytes + null flag
  final Duration duration;        // 16 bytes
  final SleepQuality quality;     // 4 bytes (enum index)
  final Map<SleepStage, Duration> stageBreakdown;  // HashMap overhead + entries
  final List<VitalLog> vitalLogs; // ArrayList overhead + references
  final List<CryEvent> cryEvents; // ArrayList overhead + references
  final String? notes;            // Variable + null flag
  
  // Estimated size: 200-500 bytes depending on log count
  // With 60 vital logs: ~5KB per session object
}
```

---

## 2️⃣ MEMORY LAYOUTS

### **2.1 ESP32 Memory Map**

```
ESP32 WROOM-32 Memory Layout
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

REGION              START        END          SIZE       USAGE
──────────────────────────────────────────────────────────────
Internal ROM        0x40000000   0x40080000   512 KB     Bootloader
Internal SRAM       0x3FFE0000   0x40000000   128 KB     Heap + Stack
Internal SRAM       0x40070000   0x40080000   64 KB      Cache
External Flash      0x400C0000   0x40400000   4 MB       Code + Data
RTC Fast Memory     0x3FF80000   0x3FF82000   8 KB       Deep sleep data
RTC Slow Memory     0x50000000   0x50002000   8 KB       ULP co-processor

RUNTIME ALLOCATION
──────────────────────────────────────────────────────────────
Program Code        ~200 KB      WiFi, sensors, HTTP client
Global Variables    ~8 KB        Config, buffers, sensors
Heap (Dynamic)      ~80 KB       JSON buffers, WiFi, TLS
Stack               ~16 KB       Function call stack
WiFi/BT Reserved    ~40 KB       Network stack
Available Free      ~4 KB        Safety margin

CRITICAL BUFFERS
──────────────────────────────────────────────────────────────
JSON Buffer         1024 bytes   ArduinoJson StaticDocument
HTTP Response       4096 bytes   Response buffer
TLS Buffer          16384 bytes  SSL/TLS handshake
Sensor Ring Buffer  512 bytes    16 readings × 32 bytes
```

### **2.2 JSON Buffer Layout (ESP32)**

```cpp
// ArduinoJson StaticJsonDocument<1024>
// Memory layout (little-endian)

StaticJsonDocument<1024> doc;

// Internal structure (simplified)
struct JsonDocument {
  uint8_t  buffer[1024];      // Raw memory pool
  uint16_t capacity;          // 1024
  uint16_t used;              // Current allocation
  JsonNode* root;             // Pointer to root object
};

// After serialization for Firestore POST:
// Offset  Content
// 0x0000  {'f','i','e','l','d','s',':','{','d','e','v',...
// 0x01C0  ...,'}'  (ends around byte 450-500)
// 0x01C1  unused
// 0x03FF  end of buffer
```

### **2.3 Flutter Heap Layout**

```
DART VM HEAP (Simplified)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

New Space (Minor GC)
┌──────────────────────────────────────┐
│  Recently allocated objects          │  ~16 MB
│  LatestVitals instances              │
│  Temporary JSON maps                 │
│  Widget rebuilds                     │
└──────────────────────────────────────┘

Old Space (Major GC)
┌──────────────────────────────────────┐
│  Long-lived objects                  │  ~64 MB
│  Provider instances                  │
│  Cached data                         │
│  Widget tree                         │
└──────────────────────────────────────┘

OBJECT LAYOUT (64-bit)
┌────────────────────┐
│  Header (16 bytes) │  Class pointer, hash, flags
├────────────────────┤
│  Field 1 (8 bytes) │  int heartRate
├────────────────────┤
│  Field 2 (8 bytes) │  int spO2
├────────────────────┤
│  Field 3 (8 bytes) │  double temperature
├────────────────────┤
│  ...               │
└────────────────────┘
```

---

## 3️⃣ PROTOCOL STACK

### **3.1 OSI Model Layers**

```
LAYER               PROTOCOL              DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

7. Application       HTTPS/REST            Firestore REST API v1
                     JSON                  Payload encoding
                     
6. Presentation      TLS 1.3               Encryption, certificates
                     Content-Encoding      gzip compression (optional)
                     
5. Session           TLS Session           Session resumption
                     
4. Transport         TCP                   Port 443, reliable stream
                     Flow Control          Window scaling
                     Congestion Control    TCP Cubic
                     
3. Network           IPv4                  Routing, fragmentation
                     
2. Data Link         WiFi (802.11n)        2.4 GHz, WPA2-PSK
                     Ethernet              (if wired)
                     
1. Physical          2.4 GHz Radio         OFDM modulation
```

### **3.2 TCP/IP Stack Detail**

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                        │
│  ┌───────────────────────────────────────────────────┐     │
│  │ HTTPS Request                                     │     │
│  │ POST /v1/projects/babytrack/databases/...        │     │
│  │ Host: firestore.googleapis.com                    │     │
│  │ Content-Type: application/json                    │     │
│  │ Authorization: Bearer ya29.a0AfH6S...            │     │
│  │                                                   │     │
│  │ {JSON payload ~450 bytes}                        │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP Parser
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                     TLS/SSL LAYER                           │
│  ┌───────────────────────────────────────────────────┐     │
│  │ TLS 1.3 Record                                    │     │
│  │ ┌─────────────────────────────────────────┐      │     │
│  │ │ Content Type: 0x17 (Application Data)   │      │     │
│  │ │ Version: 0x0303 (TLS 1.2 compat)        │      │     │
│  │ │ Length: 512 bytes                       │      │     │
│  │ └─────────────────────────────────────────┘      │     │
│  │ [Encrypted HTTPS Request + MAC]                  │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ TLS Encryption
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      TCP LAYER                              │
│  ┌───────────────────────────────────────────────────┐     │
│  │ TCP Header (20 bytes)                             │     │
│  │ ┌─────────────────────────────────────────┐      │     │
│  │ │ Source Port: 52341                      │      │     │
│  │ │ Dest Port: 443                          │      │     │
│  │ │ Sequence Number: 1234567890             │      │     │
│  │ │ Ack Number: 9876543210                  │      │     │
│  │ │ Flags: PSH, ACK                         │      │     │
│  │ │ Window Size: 65535                      │      │     │
│  │ │ Checksum: 0x1A2B                        │      │     │
│  │ └─────────────────────────────────────────┘      │     │
│  │ [TLS Record Data - 512 bytes]                    │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ TCP Segmentation
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                       IP LAYER                              │
│  ┌───────────────────────────────────────────────────┐     │
│  │ IPv4 Header (20 bytes)                            │     │
│  │ ┌─────────────────────────────────────────┐      │     │
│  │ │ Version: 4, IHL: 5                      │      │     │
│  │ │ TOS: 0x00                               │      │     │
│  │ │ Total Length: 552 bytes                 │      │     │
│  │ │ ID: 0x1234                              │      │     │
│  │ │ Flags: DF (Don't Fragment)              │      │     │
│  │ │ TTL: 64                                 │      │     │
│  │ │ Protocol: 6 (TCP)                       │      │     │
│  │ │ Checksum: 0x5678                        │      │     │
│  │ │ Source IP: 192.168.1.100               │      │     │
│  │ │ Dest IP: 142.250.185.110 (Google)      │      │     │
│  │ └─────────────────────────────────────────┘      │     │
│  │ [TCP Segment - 532 bytes]                        │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ IP Routing
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    WiFi (802.11) LAYER                      │
│  ┌───────────────────────────────────────────────────┐     │
│  │ WiFi Frame Header (24 bytes)                      │     │
│  │ Frame Control: 0x0208 (Data)                      │     │
│  │ Duration: 0x0000                                  │     │
│  │ Address 1: Router MAC (destination)               │     │
│  │ Address 2: ESP32 MAC (source)                     │     │
│  │ Address 3: Gateway MAC                            │     │
│  │ Sequence Control: 0x0123                          │     │
│  │ [IP Packet - 552 bytes]                           │     │
│  │ FCS: 0x9ABCDEF0 (CRC32)                          │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ WiFi Radio
                        ▼
            [Radio Waves @ 2.4 GHz]
```

---

## 4️⃣ WIRE FORMATS

### **4.1 Firestore REST API Request**

```http
POST /v1/projects/babytrack-prod/databases/(default)/documents/devices/AnvayaPod-A1B2/vitalReadings HTTP/1.1
Host: firestore.googleapis.com
User-Agent: ESP32-HTTPClient/1.0
Content-Type: application/json
Content-Length: 486
Authorization: Bearer ya29.a0AfH6SMBxxx...
Accept-Encoding: identity
Connection: keep-alive

{
  "fields": {
    "deviceId": {
      "stringValue": "AnvayaPod-A1B2"
    },
    "babyId": {
      "stringValue": "baby_XYZ123"
    },
    "timestamp": {
      "integerValue": "1738454400000"
    },
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {
            "integerValue": "128"
          },
          "spO2": {
            "integerValue": "98"
          },
          "bodyTemp": {
            "doubleValue": 36.8
          },
          "breathRate": {
            "integerValue": "28"
          },
          "motionLevel": {
            "integerValue": "3"
          }
        }
      }
    }
  }
}
```

**Byte Analysis:**
```
Total HTTP Request Size: ~750 bytes
├─ HTTP Headers: ~264 bytes
│  ├─ Request line: ~120 bytes
│  ├─ Host header: ~38 bytes
│  ├─ User-Agent: ~30 bytes
│  ├─ Content headers: ~50 bytes
│  └─ Auth header: ~200+ bytes (JWT token)
└─ JSON Body: ~486 bytes
   ├─ Field names (keys): ~180 bytes
   ├─ Type annotations: ~120 bytes
   └─ Actual values: ~186 bytes
```

### **4.2 Firestore REST API Response**

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8
Vary: Origin, X-Origin, Referer
Date: Sun, 02 Feb 2026 10:30:00 GMT
Server: ESF
Cache-Control: private
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
Alt-Svc: h3=":443"; ma=2592000,h3-29=":443"; ma=2592000
Content-Length: 612

{
  "name": "projects/babytrack-prod/databases/(default)/documents/devices/AnvayaPod-A1B2/vitalReadings/abc123xyz",
  "fields": {
    "deviceId": {
      "stringValue": "AnvayaPod-A1B2"
    },
    "babyId": {
      "stringValue": "baby_XYZ123"
    },
    "timestamp": {
      "integerValue": "1738454400000"
    },
    "vitals": {
      "mapValue": {
        "fields": {
          "heartRate": {
            "integerValue": "128"
          },
          "spO2": {
            "integerValue": "98"
          },
          "bodyTemp": {
            "doubleValue": 36.8
          },
          "breathRate": {
            "integerValue": "28"
          },
          "motionLevel": {
            "integerValue": "3"
          }
        }
      }
    }
  },
  "createTime": "2026-02-02T10:30:00.123456Z",
  "updateTime": "2026-02-02T10:30:00.123456Z"
}
```

### **4.3 Firestore Snapshot Protocol (Flutter)**

```
Google Cloud Firestore WebChannel Protocol
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Transport: HTTP/2 over TLS 1.3
Endpoint: wss://firestore.googleapis.com/google.firestore.v1.Firestore/Listen

INITIAL HANDSHAKE
─────────────────────────────────────────────────────────────
Client → Server: Listen Request
{
  "database": "projects/babytrack-prod/databases/(default)",
  "addTarget": {
    "query": {
      "parent": "projects/.../documents/babies",
      "structuredQuery": {
        "from": [{"collectionId": "babies"}],
        "where": {
          "fieldFilter": {
            "field": {"fieldPath": "id"},
            "op": "EQUAL",
            "value": {"stringValue": "baby_XYZ123"}
          }
        }
      }
    },
    "targetId": 1
  }
}

Server → Client: Target Added
{
  "targetChange": {
    "targetChangeType": "ADD",
    "targetIds": [1]
  }
}

Server → Client: Current Snapshot
{
  "documentChange": {
    "document": {
      "name": "projects/.../documents/babies/baby_XYZ123",
      "fields": {
        "latestVitals": {
          "mapValue": {
            "fields": {
              "heartRate": {"integerValue": "128"},
              "spO2": {"integerValue": "98"},
              ...
            }
          }
        }
      },
      "updateTime": "2026-02-02T10:30:00.123456Z"
    },
    "targetIds": [1]
  }
}

REAL-TIME UPDATE (when data changes)
─────────────────────────────────────────────────────────────
Server → Client: Document Update
{
  "documentChange": {
    "document": {
      "name": "projects/.../documents/babies/baby_XYZ123",
      "fields": {
        "latestVitals": {
          "mapValue": {
            "fields": {
              "heartRate": {"integerValue": "132"},  ← Changed!
              "spO2": {"integerValue": "98"},
              "temperature": {"doubleValue": 36.9},   ← Changed!
              ...
            }
          }
        }
      },
      "updateTime": "2026-02-02T10:30:01.456789Z"
    },
    "targetIds": [1]
  }
}
```

---

## 5️⃣ API CONTRACTS

### **5.1 Firestore REST API**

#### **Endpoint Structure**
```
BASE URL: https://firestore.googleapis.com/v1

RESOURCE PATH FORMAT:
projects/{project-id}/databases/{database-id}/documents/{collection}/{document}

EXAMPLE:
projects/babytrack-prod/databases/(default)/documents/devices/AnvayaPod-A1B2/vitalReadings/abc123

OPERATIONS:
├─ GET     Read document
├─ POST    Create document (auto-ID)
├─ PATCH   Update document (merge)
├─ DELETE  Delete document
└─ GET     List documents (query)
```

#### **Authentication Flow**
```
1. ESP32 Device Authentication:
   ┌─────────────────────────────────────────┐
   │ Service Account JSON Key (stored)      │
   │ {                                       │
   │   "type": "service_account",            │
   │   "project_id": "babytrack-prod",       │
   │   "private_key_id": "abc123...",        │
   │   "private_key": "-----BEGIN PRIVATE...",│
   │   "client_email": "device@..."          │
   │ }                                       │
   └─────────────────────────────────────────┘
                    ▼
   ┌─────────────────────────────────────────┐
   │ JWT Generation (on ESP32)               │
   │ Header: {"alg":"RS256","typ":"JWT"}     │
   │ Payload: {                              │
   │   "iss": "device@babytrack...",         │
   │   "scope": "https://www.googleapis...", │
   │   "aud": "https://oauth2.googleapis...",│
   │   "exp": now + 3600,                    │
   │   "iat": now                            │
   │ }                                       │
   │ Signature: RS256(header.payload, key)   │
   └─────────────────────────────────────────┘
                    ▼
   ┌─────────────────────────────────────────┐
   │ POST https://oauth2.googleapis.com/token│
   │ grant_type=urn:ietf:params:oauth:...    │
   │ assertion={JWT}                          │
   └─────────────────────────────────────────┘
                    ▼
   ┌─────────────────────────────────────────┐
   │ Response: Access Token                  │
   │ {                                       │
   │   "access_token": "ya29.a0AfH6SMB...",  │
   │   "expires_in": 3600,                   │
   │   "token_type": "Bearer"                │
   │ }                                       │
   └─────────────────────────────────────────┘
                    ▼
   Used in: Authorization: Bearer ya29...

2. Flutter App Authentication:
   ┌─────────────────────────────────────────┐
   │ Firebase Auth (Email/Password)          │
   │ POST https://identitytoolkit.google... │
   │ {                                       │
   │   "email": "user@example.com",          │
   │   "password": "********",               │
   │   "returnSecureToken": true             │
   │ }                                       │
   └─────────────────────────────────────────┘
                    ▼
   ┌─────────────────────────────────────────┐
   │ Response: ID Token                      │
   │ {                                       │
   │   "idToken": "eyJhbGciOiJSUzI1N...",    │
   │   "refreshToken": "AEu4IL3...",         │
   │   "expiresIn": "3600"                   │
   │ }                                       │
   └─────────────────────────────────────────┘
                    ▼
   FlutterFire SDK handles automatically
```

### **5.2 WebSocket Protocol (Firestore Streams)**

```
WebSocket Frame Structure (RFC 6455)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+

Example Firestore Update Frame:
FIN: 1 (final frame)
Opcode: 1 (text frame)
Mask: 0 (server → client, no mask)
Payload Length: 245 bytes
Payload: {JSON document update}
```

---

## 6️⃣ SERIALIZATION DETAILS

### **6.1 JSON Encoding**

#### **UTF-8 Encoding**
```
String: "AnvayaPod-A1B2"

Byte Sequence (hex):
41 6E 76 61 79 61 50 6F 64 2D 41 31 42 32

Breakdown:
'A'  = 0x41 (65 decimal)
'n'  = 0x6E (110 decimal)
'v'  = 0x76 (118 decimal)
...
'-'  = 0x2D (45 decimal)
...
'2'  = 0x32 (50 decimal)

Total: 14 bytes (ASCII compatible)
```

#### **Number Encoding**
```json
// Integer (in JSON)
"heartRate": 128

Wire format (ASCII): "128"
Bytes: 31 32 38 (3 bytes)

// Double (in JSON)
"bodyTemp": 36.8

Wire format (ASCII): "36.8"
Bytes: 33 36 2E 38 (4 bytes)

// In Firestore internal format (binary):
IEEE 754 Double: 0x4042666666666666 (8 bytes)
```

### **6.2 Firestore Type System**

```
TYPE                JSON REP              BINARY STORAGE        SIZE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
stringValue         "text"                UTF-8 bytes           Variable
integerValue        "123"                 int64 (varint)        1-9 bytes
doubleValue         36.8                  IEEE 754 double       8 bytes
booleanValue        true/false            1 bit (+ padding)     1 byte
timestampValue      "2026-02-02T..."      int64 seconds         8 bytes
                                          + int32 nanos         4 bytes
nullValue           null                  0 bytes               0 bytes
referenceValue      "projects/..."        UTF-8 path            Variable
geoPointValue       {lat, lng}            double × 2            16 bytes
bytesValue          "base64..."           Raw bytes             Variable
arrayValue          [...]                 Length + items        Variable
mapValue            {...}                 Length + pairs        Variable
```

### **6.3 Protocol Buffers (Internal)**

```protobuf
// Firestore internally uses Protocol Buffers
// This is the actual structure (simplified)

message Document {
  string name = 1;                    // Full path
  map<string, Value> fields = 2;      // Field data
  google.protobuf.Timestamp create_time = 3;
  google.protobuf.Timestamp update_time = 4;
}

message Value {
  oneof value_type {
    NullValue null_value = 11;
    bool boolean_value = 1;
    int64 integer_value = 2;
    double double_value = 3;
    Timestamp timestamp_value = 5;
    string string_value = 17;
    bytes bytes_value = 18;
    string reference_value = 5;
    LatLng geo_point_value = 8;
    ArrayValue array_value = 9;
    MapValue map_value = 6;
  }
}

// Wire format (binary, varint encoded):
// Tag: field_number << 3 | wire_type
// Example: field 2 (int64) → tag = 0x10 (16 decimal)
```

---

## 7️⃣ NETWORK PACKETS

### **7.1 Complete Packet Capture**

```
Wireshark Packet Analysis: ESP32 → Firestore POST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Frame 42: 802 bytes on wire (6416 bits)
Ethernet II, Src: Espressif_12:34:56, Dst: Netgear_aa:bb:cc
Internet Protocol Version 4, Src: 192.168.1.100, Dst: 142.250.185.110
Transmission Control Protocol, Src Port: 52341, Dst Port: 443
Transport Layer Security
  TLSv1.3 Record Layer: Application Data Protocol: http-over-tls
    Content Type: Application Data (23)
    Version: TLS 1.2 (0x0303)
    Length: 750
    Encrypted Application Data: 1a2b3c4d5e6f7... (750 bytes)

Decrypted HTTP (if TLS session key available):
  POST /v1/projects/babytrack-prod/databases/(default)/... HTTP/1.1
  [Full HTTP request as shown in section 4.1]
```

**Packet Breakdown:**
```
Total Packet Size: 802 bytes
├─ Ethernet Header: 14 bytes
│  ├─ Destination MAC: 6 bytes
│  ├─ Source MAC: 6 bytes
│  └─ Type (IPv4): 2 bytes
├─ IP Header: 20 bytes
│  ├─ Version/IHL: 1 byte
│  ├─ TOS: 1 byte
│  ├─ Total Length: 2 bytes
│  ├─ ID: 2 bytes
│  ├─ Flags/Offset: 2 bytes
│  ├─ TTL: 1 byte
│  ├─ Protocol (TCP): 1 byte
│  ├─ Checksum: 2 bytes
│  ├─ Source IP: 4 bytes
│  └─ Dest IP: 4 bytes
├─ TCP Header: 20 bytes
│  ├─ Source Port: 2 bytes
│  ├─ Dest Port: 2 bytes
│  ├─ Seq Number: 4 bytes
│  ├─ Ack Number: 4 bytes
│  ├─ Offset/Flags: 2 bytes
│  ├─ Window: 2 bytes
│  ├─ Checksum: 2 bytes
│  └─ Urgent Pointer: 2 bytes
└─ TLS + HTTP Payload: 748 bytes
   ├─ TLS Header: 5 bytes
   ├─ TLS MAC: 16 bytes
   ├─ HTTP Request: ~750 bytes (compressed)
   └─ Padding: Variable
```

### **7.2 TCP Connection Lifecycle**

```
THREE-WAY HANDSHAKE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ESP32                           Firestore Server
  │                                    │
  │  SYN (seq=1000)                    │
  ├───────────────────────────────────►│
  │                                    │
  │  SYN-ACK (seq=5000, ack=1001)      │
  │◄───────────────────────────────────┤
  │                                    │
  │  ACK (seq=1001, ack=5001)          │
  ├───────────────────────────────────►│
  │                                    │
  │  [TCP CONNECTION ESTABLISHED]      │

TLS HANDSHAKE (TLS 1.3)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  │  ClientHello                       │
  │  ├─ Supported ciphers              │
  │  ├─ Supported extensions           │
  │  └─ Random nonce                   │
  ├───────────────────────────────────►│
  │                                    │
  │  ServerHello                       │
  │  ├─ Selected cipher                │
  │  ├─ Server certificate             │
  │  ├─ Server random                  │
  │  └─ Key exchange                   │
  │◄───────────────────────────────────┤
  │                                    │
  │  [Derive session keys]             │
  │  ClientFinished (encrypted)        │
  ├───────────────────────────────────►│
  │                                    │
  │  ServerFinished (encrypted)        │
  │◄───────────────────────────────────┤
  │                                    │
  │  [TLS HANDSHAKE COMPLETE]          │

HTTP REQUEST/RESPONSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  │  HTTP POST (encrypted)             │
  ├───────────────────────────────────►│
  │                                    │
  │  HTTP 200 OK (encrypted)           │
  │◄───────────────────────────────────┤
  │                                    │

CONNECTION CLOSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  │  FIN (seq=2000)                    │
  ├───────────────────────────────────►│
  │                                    │
  │  ACK (ack=2001)                    │
  │◄───────────────────────────────────┤
  │                                    │
  │  FIN (seq=6000)                    │
  │◄───────────────────────────────────┤
  │                                    │
  │  ACK (ack=6001)                    │
  ├───────────────────────────────────►│
  │                                    │
  │  [TCP CONNECTION CLOSED]           │
```

---

## 8️⃣ FIRESTORE PROTOCOL DEEP DIVE

### **8.1 Document Write Path**

```
CLIENT REQUEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Client serializes document to JSON
2. Wraps in Firestore REST API format
3. Adds authentication header
4. Sends HTTPS POST

FIRESTORE FRONTEND (API Layer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

5. Validates authentication token
6. Parses JSON to internal format
7. Checks security rules
8. Validates schema
9. Generates document ID (if auto)
10. Adds server timestamp

FIRESTORE STORAGE (Data Layer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

11. Serializes to Protocol Buffer
12. Writes to Bigtable row
    - Row Key: project/database/collection/docId
    - Column Family: fields
    - Columns: field names
    - Values: typed values
13. Updates indexes
    - Single field indexes
    - Composite indexes
14. Commits transaction

FIRESTORE REALTIME (Listener Layer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

15. Detects document change
16. Finds active listeners for this document
17. Serializes update to JSON
18. Pushes to WebSocket connections
19. Clients receive snapshot update
```

### **8.2 Index Structure**

```
FIRESTORE INDEX INTERNAL FORMAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Single-Field Index: babies collection, field: timestamp
──────────────────────────────────────────────────────────────
Index Table (sorted B-tree):
┌─────────────────────────────────────────────────────────┐
│ Index Key                    │ Document Reference       │
├──────────────────────────────┼──────────────────────────┤
│ 1738454000000 (2026-02-02)  │ → babies/baby_ABC        │
│ 1738454100000               │ → babies/baby_XYZ        │
│ 1738454200000               │ → babies/baby_123        │
│ ...                         │ ...                      │
└─────────────────────────────────────────────────────────┘

Composite Index: vitalReadings, fields: (babyId ASC, timestamp DESC)
──────────────────────────────────────────────────────────────
Index Table (sorted B-tree):
┌──────────────────────────────────────────────────────────────┐
│ Composite Key                      │ Document Reference      │
├────────────────────────────────────┼─────────────────────────┤
│ ("baby_ABC", 1738454200000)       │ → vitalReadings/xyz     │
│ ("baby_ABC", 1738454100000)       │ → vitalReadings/abc     │
│ ("baby_XYZ", 1738454300000)       │ → vitalReadings/def     │
│ ("baby_XYZ", 1738454200000)       │ → vitalReadings/ghi     │
│ ...                               │ ...                     │
└──────────────────────────────────────────────────────────────┘

Query Execution:
WHERE babyId = 'baby_XYZ' ORDER BY timestamp DESC LIMIT 10

1. Use composite index
2. Seek to key ("baby_XYZ", ∞)
3. Scan backwards (DESC order)
4. Read first 10 entries
5. Fetch documents by reference
6. Return results

Time Complexity: O(log N + K) where K = result size
```

### **8.3 Security Rules Evaluation**

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /babies/{babyId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.parentIds;
      allow write: if request.auth != null && 
                      request.auth.uid in resource.data.parentIds;
    }
  }
}

EVALUATION PROCESS (per request)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Parse request path: /babies/baby_XYZ123
2. Match rule: match /babies/{babyId}
3. Extract auth token from request
4. Decode JWT to get auth.uid
5. Fetch document: babies/baby_XYZ123
6. Read resource.data.parentIds array
7. Evaluate: auth.uid in parentIds
   - auth.uid = "user_ABC"
   - parentIds = ["user_ABC", "user_DEF"]
   - Result: TRUE
8. Grant access ✓

If FALSE → Return HTTP 403 Forbidden
If TRUE → Continue to data layer

Execution Time: ~5-10ms per request
```

---

## 🎯 PERFORMANCE METRICS

```
OPERATION                    LATENCY         THROUGHPUT      NOTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ESP32 sensor read            10-50 ms        100 Hz          I2C bus
JSON serialization           5-10 ms         N/A             ArduinoJson
HTTP POST to Firestore       300-800 ms      ~10/sec         Network latency
Firestore write              50-200 ms       1000/sec        Server processing
Firestore index update       20-100 ms       N/A             Async background
Firestore → Flutter stream   100-300 ms      Real-time       WebSocket push
Flutter JSON parse           1-5 ms          N/A             dart:convert
Provider notification        <1 ms           N/A             Synchronous
Widget rebuild               5-16 ms         60 FPS          Flutter engine
Total end-to-end             500-2000 ms     N/A             Sensor → Screen

BANDWIDTH USAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Per vital reading            ~750 bytes      Upload          HTTP overhead
Per vital reading            ~850 bytes      Download        Response
Readings per minute          60              Rate            1/second
Hourly bandwidth             ~3 MB           Total           Both directions
Daily bandwidth (active)     ~50-75 MB       8-12 hours      Sleep monitoring
Monthly bandwidth            ~1.5 GB         Estimated       30 days

STORAGE REQUIREMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Per vital document           ~600 bytes      Firestore       Compressed
Per sleep session            ~2 KB           Firestore       With logs
Daily storage (1 baby)       ~50 MB          Firestore       Raw readings
Daily storage (compressed)   ~5 MB           Firestore       With TTL
Monthly storage              ~150 MB         Firestore       Per baby
```

---

## 📊 SUMMARY

This LLD document covers:

✅ **Data Structures**: C structs, Firestore schemas, Dart classes  
✅ **Memory Layouts**: ESP32 RAM, JSON buffers, Dart heap  
✅ **Protocol Stack**: OSI layers, TCP/IP, TLS, HTTP, WebSocket  
✅ **Wire Formats**: JSON, Protocol Buffers, binary encoding  
✅ **API Contracts**: REST endpoints, authentication flows  
✅ **Serialization**: UTF-8, JSON, type mapping  
✅ **Network Packets**: Wireshark-level packet analysis  
✅ **Firestore Internals**: Write path, indexes, security rules  

**Key Insights:**
- Total packet overhead: ~250 bytes per request (headers + TLS)
- Firestore uses Protocol Buffers internally, JSON externally
- Real-time updates use WebSocket with custom protocol
- End-to-end latency dominated by network (300-800ms of 700ms total)
- Bandwidth efficient: ~1.5 GB/month per baby for 24/7 monitoring

