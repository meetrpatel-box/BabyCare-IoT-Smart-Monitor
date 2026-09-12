# 🎯 Hybrid AI Implementation Plan

**Date:** February 2, 2026  
**Approach:** Edge AI (Face Pre-check) + Cloud AI (Detailed Analysis)  
**Goal:** 99% accuracy with 70% cost reduction

---

## 📋 IMPLEMENTATION ROADMAP

### **Phase 1: Cloud Function Setup** (Week 1)
Priority: HIGH - Build cloud infrastructure first

- [ ] Create Cloud Function `analyzeFrame`
- [ ] Integrate Google Cloud Vision API
- [ ] Implement business logic (save/discard rules)
- [ ] Add Firebase Storage upload
- [ ] Add Firestore document creation
- [ ] Test with sample images
- [ ] Deploy to production

### **Phase 2: ESP32 Firmware (Simple Upload)** (Week 1-2)
Priority: HIGH - Get basic capture working

- [ ] Remove complex AI libraries (if any)
- [ ] Implement simple JPEG capture every 30s
- [ ] Add HTTP POST to Cloud Function
- [ ] Parse JSON response
- [ ] Add LED feedback (blink when saved)
- [ ] Test end-to-end flow
- [ ] Monitor network usage

### **Phase 3: Flutter App Updates** (Week 2)
Priority: MEDIUM - Display auto-captured photos

- [ ] Add "Auto-Captures" filter to photo gallery
- [ ] Create "Daily Memories" screen
- [ ] Add device settings (enable/disable auto-capture)
- [ ] Add capture interval selector (15s/30s/60s)
- [ ] Add statistics (captures today, saved today)
- [ ] Test UI/UX

### **Phase 4: Hybrid Optimization** (Week 3)
Priority: LOW - Cost optimization after data collection

- [ ] Add ESP-DL face detection library to ESP32
- [ ] Implement lightweight face pre-check
- [ ] Only upload frames WITH faces
- [ ] Measure cost reduction
- [ ] A/B test accuracy
- [ ] Fine-tune thresholds

### **Phase 5: Advanced Features** (Week 4+)
Priority: LOW - Nice to have

- [ ] Daily collage generation
- [ ] Weekly video highlights
- [ ] Smart notifications
- [ ] Activity detection improvements
- [ ] Multi-baby support

---

## 🏗️ DETAILED IMPLEMENTATION

### **TASK 1: Cloud Function - Frame Analysis**

**File:** `functions/src/analyzeFrame.ts`

```typescript
// ═══════════════════════════════════════════════════════════
// CLOUD FUNCTION: Analyze Frame from ESP32
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import vision from '@google-cloud/vision';
import * as Busboy from 'busboy';

const visionClient = new vision.ImageAnnotatorClient();
const storage = admin.storage();
const db = admin.firestore();

interface FrameAnalysisRequest {
  deviceId: string;
  babyId: string;
  imageBuffer: Buffer;
}

interface AnalysisDecision {
  shouldSave: boolean;
  reason: string;
  confidence: number;
  visionData: {
    faceCount: number;
    mood: string;
    activity: string;
    joyLikelihood: string;
    labels: string[];
  };
}

export const analyzeFrame = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      return res.status(204).send('');
    }
    
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }
    
    try {
      // Parse multipart form data
      const {deviceId, babyId, imageBuffer} = await parseMultipartForm(req);
      
      console.log(`[analyzeFrame] Device: ${deviceId}, Baby: ${babyId}, Size: ${imageBuffer.length} bytes`);
      
      // Run Vision API analysis
      const decision = await analyzeWithVisionAPI(imageBuffer, deviceId, babyId);
      
      // Save if worthy
      if (decision.shouldSave) {
        await savePhoto(imageBuffer, babyId, deviceId, decision);
      }
      
      // Log analytics
      await logAnalytics(babyId, decision);
      
      // Return decision to ESP32
      return res.status(200).json({
        shouldSave: decision.shouldSave,
        reason: decision.reason,
        confidence: decision.confidence,
        faceCount: decision.visionData.faceCount,
        mood: decision.visionData.mood,
        activity: decision.visionData.activity,
      });
      
    } catch (error) {
      console.error('[analyzeFrame] Error:', error);
      return res.status(500).json({
        error: error.message,
        shouldSave: false,
      });
    }
  });


// ═══════════════════════════════════════════════════════════
// Vision API Analysis
// ═══════════════════════════════════════════════════════════

async function analyzeWithVisionAPI(
  imageBuffer: Buffer,
  deviceId: string,
  babyId: string
): Promise<AnalysisDecision> {
  
  const [result] = await visionClient.annotateImage({
    image: { content: imageBuffer },
    features: [
      { type: 'FACE_DETECTION', maxResults: 5 },
      { type: 'LABEL_DETECTION', maxResults: 20 },
      { type: 'SAFE_SEARCH_DETECTION' },
    ],
  });
  
  const faces = result.faceAnnotations || [];
  const labels = result.labelAnnotations || [];
  const safeSearch = result.safeSearchAnnotation;
  
  // Safety check
  if (
    safeSearch?.adult !== 'VERY_UNLIKELY' ||
    safeSearch?.violence !== 'VERY_UNLIKELY'
  ) {
    return {
      shouldSave: false,
      reason: 'inappropriate_content',
      confidence: 0,
      visionData: { faceCount: 0, mood: 'unknown', activity: 'unknown', joyLikelihood: 'UNKNOWN', labels: [] },
    };
  }
  
  // No face detected
  if (faces.length === 0) {
    return {
      shouldSave: false,
      reason: 'no_face_detected',
      confidence: 0,
      visionData: { faceCount: 0, mood: 'unknown', activity: 'unknown', joyLikelihood: 'UNKNOWN', labels: [] },
    };
  }
  
  // Analyze primary face
  const face = faces[0];
  const mood = extractMood(face);
  const activity = extractActivity(labels);
  
  // Business rules
  let shouldSave = false;
  let reason = 'neutral';
  let confidence = 0;
  
  // RULE 1: Happy moments (HIGH PRIORITY)
  if (face.joyLikelihood === 'VERY_LIKELY') {
    shouldSave = true;
    reason = 'very_happy';
    confidence = 0.95;
  } else if (face.joyLikelihood === 'LIKELY') {
    shouldSave = true;
    reason = 'happy';
    confidence = 0.85;
  }
  
  // RULE 2: Crying/Distressed (ALERT)
  else if (
    face.sorrowLikelihood === 'VERY_LIKELY' ||
    face.angerLikelihood === 'LIKELY'
  ) {
    shouldSave = true;
    reason = 'crying_alert';
    confidence = 0.90;
  }
  
  // RULE 3: Surprised/Excited
  else if (face.surpriseLikelihood === 'VERY_LIKELY') {
    shouldSave = true;
    reason = 'surprised';
    confidence = 0.80;
  }
  
  // RULE 4: Special activities
  else if (activity.isSpecial) {
    shouldSave = true;
    reason = activity.name;
    confidence = activity.confidence;
  }
  
  // RULE 5: Multiple faces (family time)
  else if (faces.length >= 2) {
    shouldSave = true;
    reason = 'family_moment';
    confidence = 0.75;
  }
  
  // RULE 6: Peaceful moments (10% sampling)
  else if (Math.random() < 0.1) {
    shouldSave = true;
    reason = 'peaceful_moment';
    confidence = 0.60;
  }
  
  return {
    shouldSave,
    reason,
    confidence,
    visionData: {
      faceCount: faces.length,
      mood,
      activity: activity.name,
      joyLikelihood: face.joyLikelihood || 'UNKNOWN',
      labels: labels.slice(0, 5).map((l) => l.description || ''),
    },
  };
}


// ═══════════════════════════════════════════════════════════
// Save Photo to Storage & Firestore
// ═══════════════════════════════════════════════════════════

async function savePhoto(
  imageBuffer: Buffer,
  babyId: string,
  deviceId: string,
  decision: AnalysisDecision
): Promise<void> {
  
  const timestamp = Date.now();
  const filename = `${timestamp}_${decision.reason}.jpg`;
  const storagePath = `photos/${babyId}/auto/${filename}`;
  
  // Upload to Storage
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);
  
  await file.save(imageBuffer, {
    contentType: 'image/jpeg',
    metadata: {
      metadata: {
        babyId,
        deviceId,
        captureReason: decision.reason,
        confidence: decision.confidence.toString(),
        timestamp: new Date().toISOString(),
      },
    },
  });
  
  // Get download URL
  await file.makePublic();
  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
  
  // Create Firestore document
  await db
    .collection('babies')
    .doc(babyId)
    .collection('photos')
    .add({
      babyId,
      uploadedBy: deviceId,
      photoUrl: publicUrl,
      thumbnailUrl: publicUrl,
      capturedAt: admin.firestore.Timestamp.now(),
      uploadedAt: admin.firestore.Timestamp.now(),
      source: 'auto_capture',
      captureReason: decision.reason,
      
      aiTags: {
        mood: decision.visionData.mood,
        activity: decision.visionData.activity,
        people: decision.visionData.faceCount > 1 ? ['baby', 'parent'] : ['baby'],
        confidence: decision.confidence,
      },
      
      visionAnalysis: decision.visionData,
      
      isArchived: false,
      viewCount: 0,
      likedBy: [],
      commentsCount: 0,
    });
  
  console.log(`[savePhoto] Saved: ${storagePath}`);
  
  // Send notification for high-confidence moments
  if (decision.confidence > 0.9) {
    await sendNotification(babyId, decision);
  }
}


// ═══════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════

function extractMood(face: any): string {
  if (face.joyLikelihood === 'VERY_LIKELY') return 'very_happy';
  if (face.joyLikelihood === 'LIKELY') return 'happy';
  if (face.sorrowLikelihood === 'VERY_LIKELY') return 'crying';
  if (face.angerLikelihood === 'LIKELY') return 'upset';
  if (face.surpriseLikelihood === 'VERY_LIKELY') return 'surprised';
  return 'calm';
}

function extractActivity(labels: any[]): { name: string; isSpecial: boolean; confidence: number } {
  const labelNames = labels.map((l) => l.description?.toLowerCase() || '');
  
  const activities = [
    { name: 'feeding', keywords: ['bottle', 'milk', 'feeding'], confidence: 0.85 },
    { name: 'playing', keywords: ['toy', 'play', 'game'], confidence: 0.80 },
    { name: 'bath', keywords: ['bath', 'water', 'towel'], confidence: 0.85 },
    { name: 'sleeping', keywords: ['sleeping', 'crib', 'bed'], confidence: 0.75 },
  ];
  
  for (const activity of activities) {
    if (labelNames.some((label) => activity.keywords.some((kw) => label.includes(kw)))) {
      return { name: activity.name, isSpecial: true, confidence: activity.confidence };
    }
  }
  
  return { name: 'unknown', isSpecial: false, confidence: 0 };
}

async function logAnalytics(babyId: string, decision: AnalysisDecision): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  
  await db
    .collection('analytics')
    .doc(`${babyId}_${today}`)
    .set(
      {
        babyId,
        date: today,
        framesAnalyzed: admin.firestore.FieldValue.increment(1),
        framesSaved: decision.shouldSave ? admin.firestore.FieldValue.increment(1) : 0,
        moodCounts: {
          [decision.visionData.mood]: admin.firestore.FieldValue.increment(1),
        },
      },
      { merge: true }
    );
}

async function sendNotification(babyId: string, decision: AnalysisDecision): Promise<void> {
  // Get baby document to find parent FCM tokens
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const familyMembers = babyDoc.data()?.familyMembers || [];
  
  // Get FCM tokens for family members
  const tokens: string[] = [];
  for (const userId of familyMembers) {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) tokens.push(fcmToken);
  }
  
  if (tokens.length === 0) return;
  
  // Send notification
  await admin.messaging().sendMulticast({
    tokens,
    notification: {
      title: '📸 Happy Moment Captured!',
      body: `We just captured a ${decision.reason.replace('_', ' ')}`,
    },
    data: {
      type: 'auto_capture',
      babyId,
      reason: decision.reason,
    },
  });
}

function parseMultipartForm(req: any): Promise<FrameAnalysisRequest> {
  return new Promise((resolve, reject) => {
    const busboy = Busboy({ headers: req.headers });
    const fields: any = {};
    let imageBuffer: Buffer | null = null;
    
    busboy.on('field', (fieldname: string, val: string) => {
      fields[fieldname] = val;
    });
    
    busboy.on('file', (fieldname: string, file: any) => {
      if (fieldname === 'image') {
        const chunks: Buffer[] = [];
        file.on('data', (data: Buffer) => chunks.push(data));
        file.on('end', () => {
          imageBuffer = Buffer.concat(chunks);
        });
      }
    });
    
    busboy.on('finish', () => {
      if (!imageBuffer) {
        reject(new Error('No image uploaded'));
      } else {
        resolve({
          deviceId: fields.deviceId,
          babyId: fields.babyId,
          imageBuffer,
        });
      }
    });
    
    busboy.on('error', reject);
    
    req.pipe(busboy);
  });
}
```

---

### **TASK 2: ESP32 Firmware - Simple Upload Mode**

**File:** `firmware/esp32_babycare/src/photo_capture.cpp`

```cpp
// ═══════════════════════════════════════════════════════════
// ESP32-CAM: Simple Frame Upload (Phase 2)
// ═══════════════════════════════════════════════════════════

#include "esp_camera.h"
#include "esp_http_client.h"
#include <WiFi.h>
#include <ArduinoJson.h>

// Configuration
const char* CLOUD_FUNCTION_URL = "https://us-central1-babycare-app.cloudfunctions.net/analyzeFrame";
String DEVICE_ID = "AnvayaPod-A1B2C3";
String BABY_ID = "baby_Emma_123";

// Settings (can be updated via device commands)
bool autoCaptureEnabled = true;
int captureIntervalMs = 30000;  // 30 seconds
unsigned long lastCaptureTime = 0;

// Stats
int framesCapturesToday = 0;
int framesSavedToday = 0;


void setupCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  
  // Higher quality settings
  config.frame_size = FRAMESIZE_SVGA;  // 800x600
  config.jpeg_quality = 12;  // 0-63, lower = better quality
  config.fb_count = 1;
  
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return;
  }
  
  Serial.println("Camera initialized successfully");
}


void captureLoop() {
  if (!autoCaptureEnabled) {
    delay(1000);
    return;
  }
  
  unsigned long now = millis();
  if (now - lastCaptureTime < captureIntervalMs) {
    delay(100);
    return;
  }
  
  // Capture frame
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    delay(1000);
    return;
  }
  
  Serial.printf("Captured frame: %d bytes (%.1f KB)\n", fb->len, fb->len / 1024.0);
  framesCapturesToday++;
  
  // Upload to cloud for analysis
  FrameAnalysisResult result = uploadFrameForAnalysis(fb);
  
  if (result.success) {
    if (result.shouldSave) {
      Serial.printf("✓ SAVED: %s (%.2f confidence)\n", 
                    result.reason.c_str(), result.confidence);
      framesSavedToday++;
      blinkLED(3, 100);  // 3 fast blinks = saved
    } else {
      Serial.printf("○ Discarded: %s\n", result.reason.c_str());
      blinkLED(1, 50);   // 1 quick blink = analyzed
    }
  } else {
    Serial.printf("✗ Upload failed: %s\n", result.error.c_str());
  }
  
  esp_camera_fb_return(fb);
  lastCaptureTime = now;
  
  // Print stats every 10 captures
  if (framesCapturesToday % 10 == 0) {
    printStats();
  }
}


struct FrameAnalysisResult {
  bool success;
  bool shouldSave;
  String reason;
  float confidence;
  String mood;
  String activity;
  int faceCount;
  String error;
};

FrameAnalysisResult uploadFrameForAnalysis(camera_fb_t* fb) {
  
  FrameAnalysisResult result = {false, false, "", 0.0, "", "", 0, ""};
  
  // Create multipart form boundary
  String boundary = "----BabyCareFrame" + String(random(10000, 99999));
  
  // Build multipart body
  String bodyStart = "";
  bodyStart += "--" + boundary + "\r\n";
  bodyStart += "Content-Disposition: form-data; name=\"deviceId\"\r\n\r\n";
  bodyStart += DEVICE_ID + "\r\n";
  bodyStart += "--" + boundary + "\r\n";
  bodyStart += "Content-Disposition: form-data; name=\"babyId\"\r\n\r\n";
  bodyStart += BABY_ID + "\r\n";
  bodyStart += "--" + boundary + "\r\n";
  bodyStart += "Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n";
  bodyStart += "Content-Type: image/jpeg\r\n\r\n";
  
  String bodyEnd = "\r\n--" + boundary + "--\r\n";
  
  int totalLength = bodyStart.length() + fb->len + bodyEnd.length();
  
  // HTTP client config
  esp_http_client_config_t config = {};
  config.url = CLOUD_FUNCTION_URL;
  config.method = HTTP_METHOD_POST;
  config.timeout_ms = 20000;  // 20 seconds
  
  esp_http_client_handle_t client = esp_http_client_init(&config);
  
  // Set headers
  String contentType = "multipart/form-data; boundary=" + boundary;
  esp_http_client_set_header(client, "Content-Type", contentType.c_str());
  
  // Open connection
  esp_http_client_open(client, totalLength);
  
  // Write body
  esp_http_client_write(client, bodyStart.c_str(), bodyStart.length());
  esp_http_client_write(client, (const char*)fb->buf, fb->len);
  esp_http_client_write(client, bodyEnd.c_str(), bodyEnd.length());
  
  // Read response
  int contentLength = esp_http_client_fetch_headers(client);
  char response[1024] = {0};
  int readLen = esp_http_client_read(client, response, sizeof(response) - 1);
  
  int statusCode = esp_http_client_get_status_code(client);
  esp_http_client_close(client);
  esp_http_client_cleanup(client);
  
  // Parse response
  if (statusCode == 200 && readLen > 0) {
    StaticJsonDocument<1024> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      result.success = true;
      result.shouldSave = doc["shouldSave"] | false;
      result.reason = doc["reason"] | "unknown";
      result.confidence = doc["confidence"] | 0.0;
      result.mood = doc["mood"] | "unknown";
      result.activity = doc["activity"] | "unknown";
      result.faceCount = doc["faceCount"] | 0;
    } else {
      result.error = "JSON parse error";
    }
  } else {
    result.error = "HTTP " + String(statusCode);
  }
  
  return result;
}


void blinkLED(int times, int delayMs) {
  const int LED_PIN = 4;
  pinMode(LED_PIN, OUTPUT);
  
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(delayMs);
    digitalWrite(LED_PIN, LOW);
    delay(delayMs);
  }
}


void printStats() {
  Serial.println("\n===== CAPTURE STATS =====");
  Serial.printf("Frames captured today: %d\n", framesCapturesToday);
  Serial.printf("Frames saved today: %d\n", framesSavedToday);
  Serial.printf("Save rate: %.1f%%\n", 
                framesCapturesToday > 0 ? 
                (framesSavedToday * 100.0 / framesCapturesToday) : 0.0);
  Serial.printf("Interval: %d seconds\n", captureIntervalMs / 1000);
  Serial.println("========================\n");
}
```

---

### **TASK 3: Flutter App - Auto-Captures Gallery**

**File:** `baby_track_flutter/lib/screens/photos/auto_captures_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';
import '../../providers/photo_provider.dart';
import '../../providers/baby_provider.dart';
import '../../widgets/photo_grid.dart';

class AutoCapturesScreen extends StatefulWidget {
  @override
  _AutoCapturesScreenState createState() => _AutoCapturesScreenState();
}

class _AutoCapturesScreenState extends State<AutoCapturesScreen> {
  String _selectedFilter = 'all';
  
  @override
  Widget build(BuildContext context) {
    final babyId = context.watch<BabyProvider>().currentBaby?.id;
    
    if (babyId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Auto Captures')),
        body: Center(child: Text('No baby selected')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Auto Captures'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/auto-capture-settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCard(babyId),
          _buildFilterChips(),
          Expanded(
            child: _buildPhotoGrid(babyId),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsCard(String babyId) {
    return FutureBuilder<Map<String, int>>(
      future: _getStats(babyId),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'today': 0, 'saved': 0};
        
        return Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Captured Today', stats['today'] ?? 0),
                _buildStatItem('Saved Today', stats['saved'] ?? 0),
                _buildStatItem('Save Rate', 
                  stats['today']! > 0 
                    ? '${((stats['saved']! * 100) ~/ stats['today']!)}%'
                    : '0%'),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String label, dynamic value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
  
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('😊 Happy', 'happy'),
          _buildFilterChip('😢 Crying', 'crying'),
          _buildFilterChip('😮 Surprised', 'surprised'),
          _buildFilterChip('👨‍👩‍👧 Family', 'family'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }
  
  Widget _buildPhotoGrid(String babyId) {
    return StreamBuilder<List<PhotoModel>>(
      stream: context.read<PhotoProvider>().streamAutoCaptures(
        babyId,
        filter: _selectedFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final photos = snapshot.data ?? [];
        
        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No auto-captures yet'),
                SizedBox(height: 8),
                Text(
                  'Your device will automatically capture happy moments',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }
        
        return PhotoGrid(photos: photos);
      },
    );
  }
  
  Future<Map<String, int>> _getStats(String babyId) async {
    // TODO: Implement stats from analytics collection
    return {'today': 48, 'saved': 12};
  }
  
  void _showFilterDialog() {
    // TODO: Show advanced filter options
  }
}
```

---

## 📊 COST OPTIMIZATION STRATEGY

### **Phase 2 (Week 1-2): Measure Baseline**

```
Capture every 30 seconds:
├─ 120 frames/hour
├─ 2,880 frames/day
├─ Vision API calls: 2,880/day
├─ Cost: ~$4.32/day ($130/month)
└─ Save rate: ~10-15% (300-400 photos/day saved)
```

### **Phase 4 (Week 3): Add Hybrid Optimization**

```
Lightweight face check on ESP32:
├─ Capture every 30 seconds
├─ Quick face detection (ESP-DL)
├─ Upload only if face detected
├─ Expected: 70% have no face
├─ Vision API calls: 864/day (30% of frames)
├─ Cost: ~$1.30/day ($40/month)
└─ 70% cost reduction! ✅
```

---

## ✅ SUCCESS METRICS

### **Week 1 Targets:**
- [ ] Cloud Function deployed and tested
- [ ] ESP32 captures and uploads successfully
- [ ] Receives analysis response
- [ ] Photos saved to Firebase Storage
- [ ] Firestore documents created

### **Week 2 Targets:**
- [ ] 100+ auto-captures per day
- [ ] 10-15% save rate achieved
- [ ] Flutter app displays auto-captures
- [ ] LED feedback working on device

### **Week 3 Targets:**
- [ ] Hybrid face detection implemented
- [ ] Cost reduced to <$50/month
- [ ] 99% accuracy maintained

### **Week 4+ Targets:**
- [ ] Daily collages generated
- [ ] Push notifications working
- [ ] User feedback collected
- [ ] Fine-tuning based on data

---

## 🚀 DEPLOYMENT CHECKLIST

### **Cloud Function Deployment:**
```bash
cd functions
npm install
npm run build
firebase deploy --only functions:analyzeFrame
```

### **ESP32 Firmware Upload:**
```bash
cd firmware/esp32_babycare
pio run --target upload
pio device monitor
```

### **Flutter App Update:**
```bash
cd baby_track_flutter
flutter pub get
flutter run
```

---

## 📝 TESTING PLAN

### **Unit Tests:**
- [ ] Cloud Function: Test with sample images
- [ ] ESP32: Test HTTP multipart upload
- [ ] Flutter: Test auto-capture stream

### **Integration Tests:**
- [ ] End-to-end: ESP32 → Cloud → Firestore → Flutter
- [ ] Error handling: Network failure, Vision API timeout
- [ ] Performance: Upload latency <5 seconds

### **User Acceptance Tests:**
- [ ] Happy moments captured correctly
- [ ] Crying alerts triggered
- [ ] No false positives (empty room captures)
- [ ] Battery usage acceptable

---

**Implementation starts now!** 🎯 Begin with Phase 1 (Cloud Function) this week!

