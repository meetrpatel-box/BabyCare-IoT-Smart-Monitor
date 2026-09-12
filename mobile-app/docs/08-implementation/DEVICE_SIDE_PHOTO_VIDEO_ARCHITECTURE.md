# 📸 Device-Side Photo & Video Architecture (CORRECT)

**Last Updated:** February 2, 2026  
**Vision:** Autonomous capture of baby moments from ESP32-CAM device

---

## 🎯 ARCHITECTURE OVERVIEW

### **Current Architecture (WRONG) ❌**
```
Manual Capture Flow:
User opens app → Taps camera button → Phone captures photo → Upload to Firebase
```

### **Correct Architecture (YOUR VISION) ✅**
```
Autonomous Capture Flow:
ESP32-CAM monitors baby → Detects happy face → Auto-captures photo → 
Uploads to Firebase → AI creates collage/highlights

On-Demand Video Flow:
User taps "Live View" → App sends command → ESP32 starts streaming → 
Video displayed → User closes → Streaming stops
```

---

## 🏗️ SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEVICE-SIDE AUTONOMOUS SYSTEM                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│   ESP32-CAM      │  ← ALWAYS MONITORING
│   Device         │
├──────────────────┤
│ • OV2640 Camera  │
│ • Face Detection │───────┐
│ • Edge ML Model  │       │
│ • WiFi Module    │       │
└──────────────────┘       │
         │                 │
         │                 ▼
         │        ┌─────────────────┐
         │        │  Face Analysis  │
         │        │  (On-Device)    │
         │        ├─────────────────┤
         │        │ Happy? → Capture│
         │        │ Crying? → Notify│
         │        │ Sleeping? → Skip│
         │        └─────────────────┘
         │                 │
         ▼                 ▼
┌──────────────────────────────────┐
│      Firebase Storage            │
│  photos/{babyId}/auto/{ts}.jpg   │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│      Firestore                   │
│  Auto-created photo documents    │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│   Cloud Function                 │
│   • Enhanced AI Analysis         │
│   • Create Daily Collage         │
│   • Create Weekly Highlights     │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│   Flutter App                    │
│   • View memories                │
│   • Browse auto-captures         │
│   • Control device settings      │
└──────────────────────────────────┘
```

---

## 📸 AUTONOMOUS PHOTO CAPTURE FLOW

### **LAYER 1: ESP32-CAM - Continuous Monitoring**

```cpp
// ═══════════════════════════════════════════════════════════
// ESP32-CAM FIRMWARE: Autonomous Photo Capture
// ═══════════════════════════════════════════════════════════

#include "esp_camera.h"
#include "esp_http_client.h"
#include "esp_face_detect.hpp"  // ESP-DL face detection
#include <WiFi.h>
#include <ArduinoJson.h>

// Configuration
const char* firebaseHost = "firebasestorage.googleapis.com";
const char* firebaseAuth = "YOUR_AUTH_TOKEN";
String babyId = "baby_Emma_123";
String deviceId = "AnvayaPod-A1B2C3";

// Face detection settings
bool autoCaptureEnabled = true;
int minFaceConfidence = 70;  // 0-100
int captureIntervalMs = 30000;  // Max 1 photo per 30 seconds
unsigned long lastCaptureTime = 0;

// Face emotion classifier (lightweight ML model on ESP32)
dl::detect::FaceDetection faceDetector;


// ═══════════════════════════════════════════════════════════
// MAIN LOOP: Continuous Monitoring
// ═══════════════════════════════════════════════════════════

void loop() {
  // Check if auto-capture is enabled
  if (!autoCaptureEnabled) {
    delay(1000);
    return;
  }
  
  // Rate limiting - don't capture too frequently
  unsigned long now = millis();
  if (now - lastCaptureTime < captureIntervalMs) {
    delay(100);
    return;
  }
  
  // STEP 1: Capture frame for analysis
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    delay(1000);
    return;
  }
  
  
  // STEP 2: Run face detection (ON-DEVICE, no cloud needed!)
  std::vector<dl::detect::result_t> faces = faceDetector.infer(
    (uint8_t*)fb->buf, 
    {fb->height, fb->width, 3}
  );
  
  if (faces.empty()) {
    // No face detected - skip
    esp_camera_fb_return(fb);
    delay(500);
    return;
  }
  
  
  // STEP 3: Analyze emotion (simplified on-device model)
  FaceEmotion emotion = analyzeEmotion(fb, faces[0]);
  
  Serial.printf("Face detected! Emotion: %s (confidence: %.2f)\n", 
                emotion.label, emotion.confidence);
  
  
  // STEP 4: Decide if we should capture
  bool shouldCapture = false;
  String captureReason = "";
  
  if (emotion.label == "happy" && emotion.confidence > 0.7) {
    shouldCapture = true;
    captureReason = "happy_moment";
  }
  else if (emotion.label == "laughing" && emotion.confidence > 0.6) {
    shouldCapture = true;
    captureReason = "laughing";
  }
  else if (emotion.label == "smiling" && emotion.confidence > 0.65) {
    shouldCapture = true;
    captureReason = "smiling";
  }
  else if (emotion.label == "crying" && emotion.confidence > 0.8) {
    shouldCapture = true;
    captureReason = "crying_alert";
  }
  
  
  // STEP 5: Capture and upload if triggered
  if (shouldCapture) {
    Serial.println("📸 Capturing moment: " + captureReason);
    
    // Upload to Firebase
    bool success = uploadPhotoToFirebase(fb, captureReason, emotion);
    
    if (success) {
      lastCaptureTime = now;
      Serial.println("✓ Photo uploaded successfully!");
      
      // Blink LED to indicate capture
      blinkLED(2);
    }
  }
  
  // Return frame buffer
  esp_camera_fb_return(fb);
  
  delay(500);  // Check twice per second
}


// ═══════════════════════════════════════════════════════════
// EMOTION ANALYSIS (Edge ML Model)
// ═══════════════════════════════════════════════════════════

struct FaceEmotion {
  String label;      // "happy", "crying", "neutral", "sleeping"
  float confidence;  // 0.0 - 1.0
};

FaceEmotion analyzeEmotion(camera_fb_t* fb, dl::detect::result_t face) {
  // Extract face region
  int x = face.box[0];
  int y = face.box[1];
  int w = face.box[2];
  int h = face.box[3];
  
  // Simplified emotion detection using facial landmarks
  // In production, use TensorFlow Lite model
  
  FaceEmotion emotion;
  
  // Get mouth position (keypoint index 3, 4)
  float mouthY = face.keypoint[3 * 2 + 1];  // Y coordinate of mouth
  
  // Get eye positions (keypoint index 0, 1)
  float leftEyeY = face.keypoint[0 * 2 + 1];
  float rightEyeY = face.keypoint[1 * 2 + 1];
  float avgEyeY = (leftEyeY + rightEyeY) / 2.0;
  
  // Calculate smile ratio
  float smileRatio = (mouthY - avgEyeY) / (float)h;
  
  // Classify emotion based on facial geometry
  if (smileRatio > 0.45) {
    emotion.label = "happy";
    emotion.confidence = min(smileRatio * 1.8, 1.0);
  }
  else if (smileRatio > 0.35) {
    emotion.label = "smiling";
    emotion.confidence = smileRatio * 2.0;
  }
  else if (smileRatio < 0.25) {
    emotion.label = "crying";
    emotion.confidence = (0.25 - smileRatio) * 3.0;
  }
  else {
    emotion.label = "neutral";
    emotion.confidence = 0.6;
  }
  
  // Check if eyes are closed (sleeping detection)
  // TODO: Implement eye aspect ratio calculation
  
  return emotion;
}


// ═══════════════════════════════════════════════════════════
// UPLOAD TO FIREBASE STORAGE
// ═══════════════════════════════════════════════════════════

bool uploadPhotoToFirebase(camera_fb_t* fb, String reason, FaceEmotion emotion) {
  
  // Generate filename with timestamp
  unsigned long timestamp = millis();
  String filename = String(timestamp) + "_" + reason + ".jpg";
  String storagePath = "photos/" + babyId + "/auto/" + filename;
  
  // Firebase Storage upload URL
  String uploadUrl = "https://firebasestorage.googleapis.com/v0/b/";
  uploadUrl += "babycare-app.appspot.com/o/";
  uploadUrl += urlEncode(storagePath);
  uploadUrl += "?uploadType=media";
  
  // Create HTTP client
  esp_http_client_config_t config = {};
  config.url = uploadUrl.c_str();
  config.method = HTTP_METHOD_POST;
  config.timeout_ms = 10000;
  
  esp_http_client_handle_t client = esp_http_client_init(&config);
  
  // Set headers
  esp_http_client_set_header(client, "Content-Type", "image/jpeg");
  esp_http_client_set_header(client, "Authorization", ("Bearer " + String(firebaseAuth)).c_str());
  
  // Upload JPEG data
  esp_http_client_set_post_field(client, (const char*)fb->buf, fb->len);
  
  // Execute request
  esp_err_t err = esp_http_client_perform(client);
  
  if (err == ESP_OK) {
    int status = esp_http_client_get_status_code(client);
    
    if (status == 200) {
      // Get download URL from response
      int contentLength = esp_http_client_get_content_length(client);
      char* response = (char*)malloc(contentLength + 1);
      esp_http_client_read(client, response, contentLength);
      response[contentLength] = '\0';
      
      // Parse JSON to get download URL
      StaticJsonDocument<512> doc;
      deserializeJson(doc, response);
      String downloadUrl = doc["downloadTokens"].as<String>();
      
      free(response);
      
      // Create Firestore document with metadata
      createPhotoDocument(storagePath, downloadUrl, reason, emotion);
      
      esp_http_client_cleanup(client);
      return true;
    }
  }
  
  Serial.printf("Upload failed: %s\n", esp_err_to_name(err));
  esp_http_client_cleanup(client);
  return false;
}


// ═══════════════════════════════════════════════════════════
// CREATE FIRESTORE DOCUMENT (via REST API)
// ═══════════════════════════════════════════════════════════

void createPhotoDocument(String storagePath, String downloadUrl, 
                         String reason, FaceEmotion emotion) {
  
  // Firestore REST API endpoint
  String firestoreUrl = "https://firestore.googleapis.com/v1/projects/";
  firestoreUrl += "babycare-app/databases/(default)/documents/";
  firestoreUrl += "babies/" + babyId + "/photos";
  
  // Create JSON document
  StaticJsonDocument<1024> doc;
  
  doc["fields"]["babyId"]["stringValue"] = babyId;
  doc["fields"]["uploadedBy"]["stringValue"] = deviceId;
  doc["fields"]["photoUrl"]["stringValue"] = downloadUrl;
  doc["fields"]["thumbnailUrl"]["stringValue"] = downloadUrl;
  doc["fields"]["capturedAt"]["timestampValue"] = getCurrentISOTimestamp();
  doc["fields"]["uploadedAt"]["timestampValue"] = getCurrentISOTimestamp();
  doc["fields"]["source"]["stringValue"] = "auto_capture";
  doc["fields"]["captureReason"]["stringValue"] = reason;
  
  // Device-side emotion detection
  doc["fields"]["deviceEmotion"]["mapValue"]["fields"]["label"]["stringValue"] = emotion.label;
  doc["fields"]["deviceEmotion"]["mapValue"]["fields"]["confidence"]["doubleValue"] = emotion.confidence;
  
  // AI tags (will be enhanced by Cloud Function)
  doc["fields"]["aiTags"]["mapValue"]["fields"]["mood"]["stringValue"] = emotion.label;
  doc["fields"]["aiTags"]["mapValue"]["fields"]["activity"]["stringValue"] = "unknown";
  doc["fields"]["aiTags"]["mapValue"]["fields"]["confidence"]["doubleValue"] = 0.0;
  
  doc["fields"]["isArchived"]["booleanValue"] = false;
  
  // Serialize to JSON string
  String jsonPayload;
  serializeJson(doc, jsonPayload);
  
  // HTTP POST to Firestore
  esp_http_client_config_t config = {};
  config.url = firestoreUrl.c_str();
  config.method = HTTP_METHOD_POST;
  
  esp_http_client_handle_t client = esp_http_client_init(&config);
  esp_http_client_set_header(client, "Content-Type", "application/json");
  esp_http_client_set_header(client, "Authorization", ("Bearer " + String(firebaseAuth)).c_str());
  esp_http_client_set_post_field(client, jsonPayload.c_str(), jsonPayload.length());
  
  esp_err_t err = esp_http_client_perform(client);
  
  if (err == ESP_OK) {
    Serial.println("✓ Firestore document created");
  } else {
    Serial.printf("✗ Firestore create failed: %s\n", esp_err_to_name(err));
  }
  
  esp_http_client_cleanup(client);
}


// ═══════════════════════════════════════════════════════════
// LISTEN FOR APP COMMANDS (Auto-capture settings)
// ═══════════════════════════════════════════════════════════

void checkForCommands() {
  // Poll Firestore for pending commands
  String commandsUrl = "https://firestore.googleapis.com/v1/projects/";
  commandsUrl += "babycare-app/databases/(default)/documents/";
  commandsUrl += "deviceCommands?";
  commandsUrl += "pageSize=10&";
  commandsUrl += "orderBy=createdAt";
  
  // Firestore query: WHERE deviceId == "AnvayaPod-A1B2C3" AND status == "pending"
  // (Simplified - use Firestore REST API structured query)
  
  // HTTP GET
  esp_http_client_config_t config = {};
  config.url = commandsUrl.c_str();
  config.method = HTTP_METHOD_GET;
  
  esp_http_client_handle_t client = esp_http_client_init(&config);
  esp_http_client_set_header(client, "Authorization", ("Bearer " + String(firebaseAuth)).c_str());
  
  esp_err_t err = esp_http_client_perform(client);
  
  if (err == ESP_OK) {
    int contentLength = esp_http_client_get_content_length(client);
    char* response = (char*)malloc(contentLength + 1);
    esp_http_client_read(client, response, contentLength);
    response[contentLength] = '\0';
    
    // Parse commands
    StaticJsonDocument<2048> doc;
    deserializeJson(doc, response);
    
    JsonArray documents = doc["documents"].as<JsonArray>();
    
    for (JsonObject command : documents) {
      String commandType = command["fields"]["commandType"]["stringValue"];
      
      // Process command
      if (commandType == "enable_auto_capture") {
        autoCaptureEnabled = true;
        Serial.println("✓ Auto-capture ENABLED");
      }
      else if (commandType == "disable_auto_capture") {
        autoCaptureEnabled = false;
        Serial.println("✓ Auto-capture DISABLED");
      }
      else if (commandType == "set_capture_interval") {
        int interval = command["fields"]["payload"]["mapValue"]["fields"]["intervalMs"]["integerValue"];
        captureIntervalMs = interval;
        Serial.printf("✓ Capture interval set to %d ms\n", interval);
      }
      else if (commandType == "start_video_stream") {
        startVideoStreaming();
      }
      else if (commandType == "stop_video_stream") {
        stopVideoStreaming();
      }
      
      // Mark command as completed
      String commandId = extractDocumentId(command["name"]);
      updateCommandStatus(commandId, "completed");
    }
    
    free(response);
  }
  
  esp_http_client_cleanup(client);
}
```

---

## 📹 ON-DEMAND VIDEO STREAMING

### **LAYER 2: Flutter App - Send Stream Command**

```dart
// ═══════════════════════════════════════════════════════════
// FLUTTER APP: Start Live Video Stream
// ═══════════════════════════════════════════════════════════

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isStreaming = false;
  String? _streamUrl;
  String? _commandId;
  
  @override
  void initState() {
    super.initState();
    // Don't auto-start stream - wait for user action
  }
  
  // User taps "Start Live View"
  Future<void> _startLiveStream() async {
    final device = context.read<DeviceProvider>().currentDevice;
    if (device == null) return;
    
    setState(() {
      _isStreaming = true;
    });
    
    try {
      // STEP 1: Send command to device
      _commandId = await DeviceService().sendDeviceCommand(
        deviceId: device.id,
        commandType: 'start_video_stream',
        payload: {
          'quality': 'high',  // low, medium, high
          'fps': 15,          // frames per second
        },
      );
      
      // STEP 2: Wait for device to start streaming
      await Future.delayed(Duration(seconds: 2));
      
      // STEP 3: Get stream URL from device
      setState(() {
        _streamUrl = 'http://${device.ipAddress}/stream';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Live stream started')),
      );
      
    } catch (e) {
      setState(() {
        _isStreaming = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start stream: $e')),
      );
    }
  }
  
  // User closes live view
  Future<void> _stopLiveStream() async {
    final device = context.read<DeviceProvider>().currentDevice;
    if (device == null) return;
    
    // STEP 1: Send stop command
    await DeviceService().sendDeviceCommand(
      deviceId: device.id,
      commandType: 'stop_video_stream',
      payload: {},
    );
    
    setState(() {
      _isStreaming = false;
      _streamUrl = null;
    });
  }
  
  @override
  void dispose() {
    // Always stop streaming when screen closes
    if (_isStreaming) {
      _stopLiveStream();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Baby Monitor'),
        actions: [
          if (_isStreaming)
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: _stopLiveStream,
            ),
        ],
      ),
      body: Column(
        children: [
          // Video feed
          Container(
            height: 400,
            color: Colors.black,
            child: _streamUrl != null
              ? MjpegView(streamUrl: _streamUrl!)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                      SizedBox(height: 16),
                      Text(
                        'Stream inactive',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isStreaming ? null : _startLiveStream,
                        icon: Icon(Icons.play_arrow),
                        label: Text('Start Live View'),
                      ),
                    ],
                  ),
                ),
          ),
          
          // Controls
          if (_isStreaming) _buildStreamControls(),
        ],
      ),
    );
  }
  
  Widget _buildStreamControls() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: () => _captureSnapshot(),
            tooltip: 'Capture Snapshot',
          ),
          IconButton(
            icon: Icon(Icons.mic),
            onPressed: () => _toggleMicrophone(),
            tooltip: 'Talk to Baby',
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () => _toggleNightVision(),
            tooltip: 'Night Vision',
          ),
        ],
      ),
    );
  }
}
```

---

## 🎨 AI COLLAGE & HIGHLIGHTS GENERATION

### **Cloud Function: Create Daily/Weekly Memories**

```javascript
// ═══════════════════════════════════════════════════════════
// CLOUD FUNCTION: Auto-Generate Photo Collages
// ═══════════════════════════════════════════════════════════

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sharp = require('sharp');
const {Storage} = require('@google-cloud/storage');
const vision = require('@google-cloud/vision');

const storage = new Storage();
const visionClient = new vision.ImageAnnotatorClient();

// Triggered daily at 8 PM
exports.createDailyCollage = functions.pubsub
  .schedule('0 20 * * *')  // Cron: Every day at 8:00 PM
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    
    console.log('Creating daily collages for all babies...');
    
    // Get all babies
    const babiesSnapshot = await admin.firestore()
      .collection('babies')
      .get();
    
    for (const babyDoc of babiesSnapshot.docs) {
      const babyId = babyDoc.id;
      
      try {
        await generateDailyCollage(babyId);
        console.log(`✓ Daily collage created for baby ${babyId}`);
      } catch (error) {
        console.error(`✗ Failed to create collage for ${babyId}:`, error);
      }
    }
    
    return null;
  });


// ═══════════════════════════════════════════════════════════
// GENERATE DAILY COLLAGE
// ═══════════════════════════════════════════════════════════

async function generateDailyCollage(babyId) {
  
  // STEP 1: Get all auto-captured happy photos from today
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(startOfDay);
  endOfDay.setDate(endOfDay.getDate() + 1);
  
  const photosSnapshot = await admin.firestore()
    .collection('babies').doc(babyId)
    .collection('photos')
    .where('source', '==', 'auto_capture')
    .where('captureReason', 'in', ['happy_moment', 'smiling', 'laughing'])
    .where('capturedAt', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
    .where('capturedAt', '<', admin.firestore.Timestamp.fromDate(endOfDay))
    .orderBy('capturedAt', 'asc')
    .limit(20)  // Max 20 photos per collage
    .get();
  
  if (photosSnapshot.empty) {
    console.log(`No happy moments captured today for ${babyId}`);
    return;
  }
  
  const photos = photosSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
  
  console.log(`Found ${photos.length} happy moments for collage`);
  
  
  // STEP 2: Download all photos
  const bucket = storage.bucket('babycare-app.appspot.com');
  const photoBuffers = [];
  
  for (const photo of photos) {
    try {
      // Extract path from URL
      const url = new URL(photo.photoUrl);
      const path = decodeURIComponent(url.pathname.split('/o/')[1].split('?')[0]);
      
      const file = bucket.file(path);
      const [buffer] = await file.download();
      photoBuffers.push(buffer);
    } catch (error) {
      console.error(`Failed to download photo ${photo.id}:`, error);
    }
  }
  
  
  // STEP 3: Create collage layout
  const collageWidth = 1200;
  const collageHeight = 1200;
  const photosPerRow = Math.ceil(Math.sqrt(photoBuffers.length));
  const photoWidth = Math.floor(collageWidth / photosPerRow);
  const photoHeight = Math.floor(collageHeight / Math.ceil(photoBuffers.length / photosPerRow));
  
  // Resize all photos
  const resizedPhotos = await Promise.all(
    photoBuffers.map(buffer => 
      sharp(buffer)
        .resize(photoWidth, photoHeight, { fit: 'cover' })
        .toBuffer()
    )
  );
  
  // Create composite image
  const composites = resizedPhotos.map((buffer, index) => {
    const row = Math.floor(index / photosPerRow);
    const col = index % photosPerRow;
    
    return {
      input: buffer,
      left: col * photoWidth,
      top: row * photoHeight
    };
  });
  
  const collageBuffer = await sharp({
    create: {
      width: collageWidth,
      height: collageHeight,
      channels: 3,
      background: { r: 255, g: 255, b: 255 }
    }
  })
  .composite(composites)
  .jpeg({ quality: 90 })
  .toBuffer();
  
  
  // STEP 4: Add text overlay
  const dateStr = startOfDay.toLocaleDateString('en-US', { 
    month: 'long', 
    day: 'numeric', 
    year: 'numeric' 
  });
  
  const finalCollage = await sharp(collageBuffer)
    .composite([
      {
        input: Buffer.from(`
          <svg width="${collageWidth}" height="100">
            <rect x="0" y="0" width="${collageWidth}" height="100" 
                  fill="rgba(0,0,0,0.6)" />
            <text x="${collageWidth/2}" y="50" 
                  font-family="Arial" font-size="32" font-weight="bold"
                  fill="white" text-anchor="middle" alignment-baseline="middle">
              Happy Moments - ${dateStr}
            </text>
            <text x="${collageWidth/2}" y="80" 
                  font-family="Arial" font-size="18"
                  fill="white" text-anchor="middle" alignment-baseline="middle">
              ${photos.length} smiles captured
            </text>
          </svg>
        `),
        top: 0,
        left: 0
      }
    ])
    .toBuffer();
  
  
  // STEP 5: Upload collage to Storage
  const collageFilename = `collage_${startOfDay.getTime()}.jpg`;
  const collagePath = `collages/${babyId}/daily/${collageFilename}`;
  const collageFile = bucket.file(collagePath);
  
  await collageFile.save(finalCollage, {
    contentType: 'image/jpeg',
    metadata: {
      metadata: {
        babyId: babyId,
        date: dateStr,
        photoCount: photos.length,
        type: 'daily_collage'
      }
    }
  });
  
  // Get download URL
  const [collageUrl] = await collageFile.getSignedUrl({
    action: 'read',
    expires: '03-01-2500'
  });
  
  
  // STEP 6: Create Firestore document
  await admin.firestore()
    .collection('babies').doc(babyId)
    .collection('memories')
    .add({
      type: 'daily_collage',
      date: admin.firestore.Timestamp.fromDate(startOfDay),
      title: `Happy Moments - ${dateStr}`,
      description: `${photos.length} smiles captured today`,
      imageUrl: collageUrl,
      photoIds: photos.map(p => p.id),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  
  
  // STEP 7: Send notification to parents
  await sendNotification(babyId, {
    title: '📸 Daily Highlight Ready!',
    body: `We captured ${photos.length} happy moments today`,
    imageUrl: collageUrl,
    data: {
      type: 'daily_collage',
      babyId: babyId
    }
  });
  
  console.log(`✓ Collage created and saved to ${collagePath}`);
}


// ═══════════════════════════════════════════════════════════
// WEEKLY HIGHLIGHTS VIDEO (Future Enhancement)
// ═══════════════════════════════════════════════════════════

exports.createWeeklyHighlights = functions.pubsub
  .schedule('0 20 * * 0')  // Every Sunday at 8 PM
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    
    // Get photos from last 7 days
    // Create video compilation using ffmpeg
    // Add background music
    // Upload to Storage
    // Notify parents
    
    // TODO: Implement video generation
    
    return null;
  });
```

---

## 📊 COMPLETE DATA FLOW COMPARISON

### **OLD (Manual) vs NEW (Autonomous)**

| Aspect | ❌ OLD (Wrong) | ✅ NEW (Correct) |
|--------|---------------|------------------|
| **Photo Capture** | User opens app → Taps button | ESP32 detects emotion → Auto-captures |
| **Trigger** | Manual user action | AI face detection (on-device) |
| **Frequency** | ~5-10 photos/day | ~20-50 moments/day |
| **Upload Source** | Phone camera | ESP32-CAM device |
| **Storage Path** | `photos/{babyId}/{ts}.jpg` | `photos/{babyId}/auto/{ts}_{reason}.jpg` |
| **Metadata** | Manual caption | Auto: reason, emotion, confidence |
| **Video Streaming** | Always on? | On-demand (start/stop commands) |
| **Network Usage** | High (always streaming) | Low (stream only when viewing) |
| **Battery (Device)** | High drain | Optimized (stream on request) |
| **Memories** | Manual album creation | Auto-generated daily collages |
| **User Effort** | High (manual photos) | Zero (fully autonomous) |

---

## 🎯 IMPLEMENTATION ALIGNMENT

### **What Needs to Change:**

1. **ESP32-CAM Firmware** ✅ (New code required)
   - Add face detection library (ESP-DL)
   - Implement emotion classification
   - Add auto-capture logic
   - Implement command polling

2. **PhotoService** ⚠️ (Partial change)
   - Add support for `source: "auto_capture"`
   - Add `captureReason` field
   - Keep existing upload methods for manual captures

3. **Cloud Functions** ✅ (New functions required)
   - `createDailyCollage()` - Generate photo collages
   - `createWeeklyHighlights()` - Generate video highlights
   - Enhanced AI analysis for auto-captured photos

4. **DeviceService** ✅ (Already exists!)
   - Already has `sendDeviceCommand()` ✓
   - Add specific commands:
     - `enable_auto_capture`
     - `disable_auto_capture`
     - `set_capture_interval`
     - `start_video_stream`
     - `stop_video_stream`

5. **Flutter UI** ⚠️ (Add new screens)
   - "Memories" screen to view collages
   - "Auto-Captures" gallery filter
   - Device settings for auto-capture preferences
   - On-demand video streaming controls

---

## 🚀 MIGRATION PLAN

### **Phase 1: Device-Side Capture**
- [ ] Install ESP-DL face detection library on ESP32
- [ ] Implement emotion analysis algorithm
- [ ] Add auto-capture logic with rate limiting
- [ ] Test Firebase Storage upload from device
- [ ] Implement command polling

### **Phase 2: Cloud Processing**
- [ ] Create Cloud Function for daily collages
- [ ] Implement photo selection algorithm (best moments)
- [ ] Add text overlays and branding
- [ ] Set up scheduled triggers (cron jobs)

### **Phase 3: App Integration**
- [ ] Add "Memories" screen to view collages
- [ ] Implement on-demand video streaming
- [ ] Add device settings UI
- [ ] Create auto-capture toggle switch

### **Phase 4: Enhancements**
- [ ] Weekly video highlights
- [ ] Smart notifications (X happy moments today!)
- [ ] Shared family memories
- [ ] Print/share collages

---

## ✅ ANSWER: IS CURRENT ARCH ALIGNED?

**NO** ❌ - The current architecture I documented was **wrong**. 

**Your vision is:**
- ✅ **Autonomous capture** from ESP32-CAM device (not manual app photos)
- ✅ **On-device AI** to detect happy moments
- ✅ **Auto-upload** to Firebase
- ✅ **AI-generated collages** daily/weekly
- ✅ **On-demand video** streaming (not always-on)

**Current codebase status:**
- ✅ DeviceService has command infrastructure
- ⚠️ ESP32 firmware needs face detection + auto-capture
- ⚠️ Cloud Functions need collage generation
- ⚠️ Flutter UI needs "Memories" section

**This document is the CORRECT architecture!** 🎯

