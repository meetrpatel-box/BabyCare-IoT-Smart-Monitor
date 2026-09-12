# 📸 Photo & Video Service - Complete Data Flow

**Last Updated:** February 2, 2026

---

## 🎯 OVERVIEW

The Photo/Video service handles:
- **Photo Upload** from mobile app camera to Firebase Storage
- **Video Streaming** from ESP32-CAM device for live monitoring
- **AI Tagging** using Cloud Vision API for automatic classification
- **Engagement Features** (likes, comments, sharing)
- **Smart Search** with filters (date, mood, activity, people)

---

## 📸 PHOTO UPLOAD FLOW

### **Complete Journey: Camera → Storage → Firestore → UI**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHOTO UPLOAD JOURNEY                                │
└─────────────────────────────────────────────────────────────────────────────┘

STEP 1: User Captures Photo
├─ Flutter app uses image_picker plugin
├─ Photo saved to temporary directory
└─ File path: /tmp/image_picker_XXXXX.jpg

STEP 2: Upload Initiated
├─ PhotoService.uploadPhoto() called
├─ File size: 2.4 MB (original quality)
└─ Duration: ~3-5 seconds (depending on network)

STEP 3: Firebase Storage Upload
├─ Path: photos/{babyId}/{timestamp}.jpg
├─ Progress tracking (0% → 100%)
├─ Metadata: uploadedBy, babyId, contentType
└─ Result: Download URL obtained

STEP 4: Firestore Document Created
├─ Collection: babies/{babyId}/photos
├─ Document ID: auto-generated
├─ Initial data: URL, timestamps, empty AI tags
└─ Status: "processing"

STEP 5: AI Analysis Triggered (Background)
├─ Cloud Function: onPhotoUpload
├─ Calls Cloud Vision API
├─ Detects: mood, activity, people, objects
└─ Updates Firestore with AI tags

STEP 6: UI Updates (Real-time)
├─ Firestore stream triggers
├─ PhotoProvider rebuilds
├─ Gallery shows new photo with AI tags
└─ Total latency: 3-8 seconds (upload + AI)
```

---

## 🔥 LAYER-BY-LAYER BREAKDOWN

### **LAYER 1: Flutter App - User Interaction**

```dart
// ═══════════════════════════════════════════════════════════
// USER TAPS "CAPTURE PHOTO" BUTTON
// ═══════════════════════════════════════════════════════════

// UI Button
ElevatedButton.icon(
  onPressed: () async {
    // Pick image from camera
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,  // Compress to 85% quality
      maxWidth: 1920,    // Max 1920px width
      maxHeight: 1080,   // Max 1080px height
    );
    
    if (image != null) {
      // Start upload
      _uploadPhoto(image);
    }
  },
  icon: Icon(Icons.camera_alt),
  label: Text('Capture Moment'),
)

// ═══════════════════════════════════════════════════════════
// UPLOAD FUNCTION
// ═══════════════════════════════════════════════════════════

void _uploadPhoto(XFile imageFile) async {
  setState(() {
    _isUploading = true;
    _uploadProgress = 0.0;
  });
  
  try {
    // Convert XFile to File
    final file = File(imageFile.path);
    
    // Get current baby ID
    final babyId = context.read<BabyProvider>().currentBaby!.id;
    final userId = context.read<AuthProvider>().currentUser!.uid;
    
    // Upload with progress tracking
    final photo = await PhotoService().uploadPhoto(
      babyId: babyId,
      userId: userId,
      photoFile: file,
      caption: _captionController.text,
      manualTags: _selectedTags,
      dataContext: PhotoDataContext(
        heartRate: _currentVitals?.heartRate,
        bodyTemp: _currentVitals?.temperature,
        activity: _currentActivity,
      ),
      capturedAt: DateTime.now(),
      onProgress: (progress) {
        setState(() {
          _uploadProgress = progress;  // 0.0 to 1.0
        });
      },
    );
    
    // Success!
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo uploaded! AI analyzing...')),
    );
    
    setState(() {
      _isUploading = false;
    });
    
  } catch (e) {
    // Error handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e')),
    );
    
    setState(() {
      _isUploading = false;
    });
  }
}

// RENDERED OUTPUT ON SCREEN:
┌─────────────────────────────────────────┐
│  📷 Upload Photo                        │
├─────────────────────────────────────────┤
│                                         │
│  [█████████████████████████░░░] 85%    │
│  Uploading: emma_birthday.jpg           │
│  2.4 MB / 2.8 MB                        │
│                                         │
│  Estimated: 2 seconds remaining         │
│                                         │
└─────────────────────────────────────────┘
```

---

### **LAYER 2: PhotoService - Business Logic**

```dart
// ═══════════════════════════════════════════════════════════
// PHOTO SERVICE: uploadPhoto()
// ═══════════════════════════════════════════════════════════

Future<PhotoModel> uploadPhoto({
  required String babyId,
  required String userId,
  required File photoFile,
  String? caption,
  List<String>? manualTags,
  PhotoDataContext? dataContext,
  DateTime? capturedAt,
  void Function(double progress)? onProgress,
}) async {
  
  // STEP 1: Generate unique filename
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final extension = path.extension(photoFile.path).toLowerCase();
  final fileName = '$timestamp$extension';
  final storagePath = 'photos/$babyId/$fileName';
  
  // Example:
  // timestamp = 1738526400000
  // extension = .jpg
  // fileName = 1738526400000.jpg
  // storagePath = photos/baby_Emma_123/1738526400000.jpg
  
  
  // STEP 2: Upload to Firebase Storage
  final ref = _storage.ref().child(storagePath);
  final uploadTask = ref.putFile(
    photoFile,
    SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedBy': userId,
        'babyId': babyId,
      },
    ),
  );
  
  // Track upload progress
  uploadTask.snapshotEvents.listen((event) {
    final progress = event.bytesTransferred / event.totalBytes;
    onProgress?.call(progress);
    
    // Example progress events:
    // 0.00 → 0 bytes / 2,400,000 bytes
    // 0.25 → 600,000 / 2,400,000
    // 0.50 → 1,200,000 / 2,400,000
    // 0.75 → 1,800,000 / 2,400,000
    // 1.00 → 2,400,000 / 2,400,000 ✓
  });
  
  
  // STEP 3: Get download URL
  final snapshot = await uploadTask;
  final photoUrl = await snapshot.ref.getDownloadURL();
  
  // photoUrl = https://firebasestorage.googleapis.com/v0/b/
  //            babycare-app.appspot.com/o/photos%2Fbaby_Emma_123
  //            %2F1738526400000.jpg?alt=media&token=abc123...
  
  
  // STEP 4: Create Firestore document
  final photoDoc = _firestore
    .collection('babies')
    .doc(babyId)
    .collection('photos')
    .doc();  // Auto-generate ID
  
  final now = DateTime.now();
  
  final photo = PhotoModel(
    id: photoDoc.id,
    babyId: babyId,
    uploadedBy: userId,
    photoUrl: photoUrl,
    thumbnailUrl: photoUrl,  // Same for now (TODO: Cloud Function)
    capturedAt: capturedAt ?? now,
    uploadedAt: now,
    aiTags: AIPhotoTags.empty(),  // Will be filled by AI
    dataContext: dataContext,
    caption: caption,
    manualTags: manualTags ?? [],
  );
  
  await photoDoc.set(photo.toFirestore());
  
  
  // STEP 5: Trigger AI analysis (async, non-blocking)
  _triggerAITagging(babyId, photo.id, photoUrl);
  
  return photo;
}
```

---

### **LAYER 3: Firebase Storage - File Storage**

```
┌─────────────────────────────────────────────────────────────┐
│              FIREBASE STORAGE STRUCTURE                     │
└─────────────────────────────────────────────────────────────┘

Root: gs://babycare-app.appspot.com/
├── photos/
│   ├── baby_Emma_123/
│   │   ├── 1738526400000.jpg      (2.4 MB, uploaded 2026-02-02)
│   │   ├── 1738530000000.jpg      (1.8 MB, uploaded 2026-02-02)
│   │   ├── 1738533600000.png      (3.1 MB, uploaded 2026-02-02)
│   │   └── ...
│   ├── baby_Oliver_456/
│   │   ├── 1738540000000.jpg
│   │   └── ...
│   └── ...
├── thumbnails/  (Generated by Cloud Function)
│   ├── baby_Emma_123/
│   │   ├── 1738526400000_thumb.jpg  (150 KB, 300x300)
│   │   └── ...
│   └── ...
└── videos/  (Future: video recordings)
    └── ...


STORAGE RULES (security.rules):
─────────────────────────────────────────────────────────────

service firebase.storage {
  match /b/{bucket}/o {
    
    // Photos - only family members can upload/view
    match /photos/{babyId}/{fileName} {
      allow read: if request.auth != null && 
                     isFamilyMember(babyId);
      allow write: if request.auth != null && 
                      isFamilyMember(babyId);
    }
    
    // Thumbnails - read-only by family
    match /thumbnails/{babyId}/{fileName} {
      allow read: if request.auth != null && 
                     isFamilyMember(babyId);
      allow write: if false;  // Only Cloud Function can write
    }
  }
  
  function isFamilyMember(babyId) {
    let baby = firestore.get(/databases/(default)/documents/babies/$(babyId));
    return request.auth.uid in baby.data.familyMembers;
  }
}
```

---

### **LAYER 4: Firestore - Metadata Storage**

```dart
// ═══════════════════════════════════════════════════════════
// FIRESTORE DOCUMENT STRUCTURE
// ═══════════════════════════════════════════════════════════

Collection: babies/{babyId}/photos
Document ID: photo_abc123

{
  // Identifiers
  babyId: "baby_Emma_123",
  uploadedBy: "user_parent_xyz",
  
  // URLs
  photoUrl: "https://firebasestorage.googleapis.com/.../1738526400000.jpg",
  thumbnailUrl: "https://firebasestorage.googleapis.com/.../1738526400000_thumb.jpg",
  
  // Timestamps
  capturedAt: Timestamp(2026-02-02T14:30:00Z),
  uploadedAt: Timestamp(2026-02-02T14:32:15Z),
  
  // AI-Generated Tags (updated by Cloud Function)
  aiTags: {
    mood: "happy",           // happy, calm, crying, sleeping, alert
    activity: "playing",     // feeding, playing, sleeping, bath, tummy_time
    people: ["mom", "dad"],  // Detected faces
    location: null,
    confidence: 0.92         // 92% confidence
  },
  
  // Data Context (vitals at time of photo)
  dataContext: {
    heartRate: 125,
    bodyTemp: 36.8,
    activity: "playing"
  },
  
  // User-Generated Content
  caption: "Emma's first birthday! 🎂",
  manualTags: ["birthday", "milestone", "family"],
  
  // Organization
  albumIds: ["album_birthday_2026"],
  
  // Engagement
  viewCount: 47,
  likedBy: ["user_parent_xyz", "user_grandma_abc", "user_aunt_def"],
  commentsCount: 12,
  
  // Sharing
  sharedWith: ["user_grandma_abc", "user_aunt_def"],
  isPublic: false,
  
  // Status
  isArchived: false,
  deletedAt: null
}


// ═══════════════════════════════════════════════════════════
// FIRESTORE INDEXES (for efficient queries)
// ═══════════════════════════════════════════════════════════

// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "photos",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "babyId", "order": "ASCENDING"},
        {"fieldPath": "isArchived", "order": "ASCENDING"},
        {"fieldPath": "capturedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "photos",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "babyId", "order": "ASCENDING"},
        {"fieldPath": "manualTags", "arrayConfig": "CONTAINS"},
        {"fieldPath": "capturedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "photos",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "babyId", "order": "ASCENDING"},
        {"fieldPath": "albumIds", "arrayConfig": "CONTAINS"},
        {"fieldPath": "capturedAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

---

### **LAYER 5: Cloud Functions - AI Processing**

```javascript
// ═══════════════════════════════════════════════════════════
// CLOUD FUNCTION: AI Photo Tagging
// ═══════════════════════════════════════════════════════════

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

const visionClient = new vision.ImageAnnotatorClient();

// Triggered when photo document is created
exports.onPhotoUpload = functions.firestore
  .document('babies/{babyId}/photos/{photoId}')
  .onCreate(async (snap, context) => {
    
    const photo = snap.data();
    const babyId = context.params.babyId;
    const photoId = context.params.photoId;
    
    console.log(`AI analyzing photo ${photoId} for baby ${babyId}`);
    
    try {
      // STEP 1: Download photo URL
      const photoUrl = photo.photoUrl;
      
      
      // STEP 2: Call Cloud Vision API
      const [result] = await visionClient.annotateImage({
        image: { source: { imageUri: photoUrl } },
        features: [
          { type: 'FACE_DETECTION', maxResults: 10 },
          { type: 'LABEL_DETECTION', maxResults: 20 },
          { type: 'IMAGE_PROPERTIES' },
          { type: 'SAFE_SEARCH_DETECTION' }
        ]
      });
      
      // Example Vision API Response:
      // {
      //   faceAnnotations: [
      //     {
      //       joyLikelihood: 'VERY_LIKELY',      // Happy!
      //       sorrowLikelihood: 'VERY_UNLIKELY',
      //       angerLikelihood: 'VERY_UNLIKELY',
      //       surpriseLikelihood: 'POSSIBLE'
      //     }
      //   ],
      //   labelAnnotations: [
      //     { description: 'Baby', score: 0.98 },
      //     { description: 'Playing', score: 0.92 },
      //     { description: 'Toy', score: 0.87 },
      //     { description: 'Indoor', score: 0.85 }
      //   ]
      // }
      
      
      // STEP 3: Process results into our tags
      const mood = detectMood(result.faceAnnotations);
      const activity = detectActivity(result.labelAnnotations);
      const people = detectPeople(result.faceAnnotations);
      const confidence = calculateConfidence(result);
      
      const aiTags = {
        mood: mood,           // "happy"
        activity: activity,   // "playing"
        people: people,       // ["mom", "dad"]
        confidence: confidence // 0.92
      };
      
      
      // STEP 4: Update Firestore document
      await snap.ref.update({
        'aiTags': aiTags,
        'aiProcessedAt': admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`AI tagging complete for ${photoId}:`, aiTags);
      
      
      // STEP 5: Generate thumbnail (Cloud Storage)
      await generateThumbnail(photoUrl, babyId, photoId);
      
      
      // STEP 6: Send notification to family
      await notifyFamily(babyId, {
        title: 'New Photo Added',
        body: `${photo.uploadedByName} added a new photo of Emma`,
        imageUrl: photo.thumbnailUrl,
        data: {
          type: 'photo_uploaded',
          photoId: photoId,
          babyId: babyId
        }
      });
      
      return { success: true };
      
    } catch (error) {
      console.error('AI tagging failed:', error);
      
      // Update with error status
      await snap.ref.update({
        'aiTags.error': error.message,
        'aiProcessedAt': admin.firestore.FieldValue.serverTimestamp()
      });
      
      return { success: false, error: error.message };
    }
  });


// ═══════════════════════════════════════════════════════════
// HELPER: Detect Mood from Face Analysis
// ═══════════════════════════════════════════════════════════

function detectMood(faceAnnotations) {
  if (!faceAnnotations || faceAnnotations.length === 0) {
    return 'unknown';
  }
  
  const face = faceAnnotations[0];  // Use first detected face (baby)
  
  // Joy likelihood values: VERY_LIKELY, LIKELY, POSSIBLE, UNLIKELY, VERY_UNLIKELY
  if (face.joyLikelihood === 'VERY_LIKELY' || face.joyLikelihood === 'LIKELY') {
    return 'happy';
  }
  
  if (face.sorrowLikelihood === 'VERY_LIKELY' || face.sorrowLikelihood === 'LIKELY') {
    return 'crying';
  }
  
  if (face.angerLikelihood === 'VERY_LIKELY') {
    return 'crying';
  }
  
  // Check if eyes are closed (sleeping)
  if (face.underExposedLikelihood === 'VERY_LIKELY') {
    return 'sleeping';
  }
  
  return 'calm';
}


// ═══════════════════════════════════════════════════════════
// HELPER: Detect Activity from Labels
// ═══════════════════════════════════════════════════════════

function detectActivity(labelAnnotations) {
  if (!labelAnnotations) return 'unknown';
  
  const labels = labelAnnotations.map(l => l.description.toLowerCase());
  
  // Activity keywords mapping
  const activityKeywords = {
    'feeding': ['bottle', 'feeding', 'milk', 'breast', 'nursing'],
    'playing': ['toy', 'playing', 'play', 'game', 'blocks'],
    'sleeping': ['sleeping', 'crib', 'bed', 'nap', 'blanket'],
    'bath': ['bath', 'water', 'bathtub', 'towel', 'soap'],
    'tummy_time': ['tummy', 'floor', 'mat', 'crawling'],
    'outdoor': ['outdoor', 'park', 'stroller', 'nature', 'outside']
  };
  
  // Find best matching activity
  for (const [activity, keywords] of Object.entries(activityKeywords)) {
    if (labels.some(label => keywords.includes(label))) {
      return activity;
    }
  }
  
  return 'unknown';
}


// ═══════════════════════════════════════════════════════════
// HELPER: Generate Thumbnail
// ═══════════════════════════════════════════════════════════

async function generateThumbnail(photoUrl, babyId, photoId) {
  const sharp = require('sharp');
  const {Storage} = require('@google-cloud/storage');
  const storage = new Storage();
  const axios = require('axios');
  
  // Download original image
  const response = await axios.get(photoUrl, { responseType: 'arraybuffer' });
  const imageBuffer = Buffer.from(response.data);
  
  // Resize to 300x300 thumbnail
  const thumbnailBuffer = await sharp(imageBuffer)
    .resize(300, 300, { fit: 'cover' })
    .jpeg({ quality: 80 })
    .toBuffer();
  
  // Upload thumbnail to Storage
  const bucket = storage.bucket('babycare-app.appspot.com');
  const thumbnailPath = `thumbnails/${babyId}/${photoId}_thumb.jpg`;
  const file = bucket.file(thumbnailPath);
  
  await file.save(thumbnailBuffer, {
    contentType: 'image/jpeg',
    metadata: {
      metadata: {
        originalPhoto: photoId
      }
    }
  });
  
  // Get public URL
  const thumbnailUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(thumbnailPath)}?alt=media`;
  
  // Update Firestore with thumbnail URL
  await admin.firestore()
    .collection('babies').doc(babyId)
    .collection('photos').doc(photoId)
    .update({ thumbnailUrl: thumbnailUrl });
  
  console.log(`Thumbnail generated: ${thumbnailUrl}`);
}
```

---

### **LAYER 6: Flutter UI - Real-time Display**

```dart
// ═══════════════════════════════════════════════════════════
// PHOTO STREAM SUBSCRIPTION
// ═══════════════════════════════════════════════════════════

class PhotoGalleryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final babyId = context.watch<BabyProvider>().currentBaby!.id;
    
    return Scaffold(
      appBar: AppBar(title: Text('Photo Gallery')),
      body: StreamBuilder<List<PhotoModel>>(
        stream: PhotoService().streamPhotos(babyId, limit: 50),
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
                  Icon(Icons.photo_library, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No photos yet'),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _capturePhoto(context),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Capture First Photo'),
                  ),
                ],
              ),
            );
          }
          
          // Display in grid
          return GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return PhotoTile(photo: photos[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _capturePhoto(context),
        child: Icon(Icons.camera_alt),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// PHOTO TILE WIDGET
// ═══════════════════════════════════════════════════════════

class PhotoTile extends StatelessWidget {
  final PhotoModel photo;
  
  const PhotoTile({required this.photo});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPhotoDetail(context, photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image
          CachedNetworkImage(
            imageUrl: photo.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          
          // AI mood badge
          if (photo.aiTags.isProcessed)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  photo.aiTags.moodEmoji,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          
          // Like count
          if (photo.likedBy.isNotEmpty)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      '${photo.likedBy.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// RENDERED OUTPUT:
┌─────────────────────────────────────────────────────────────┐
│  📷 Photo Gallery                                    [+]    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┬─────────┬─────────┐                          │
│  │ 😊      │ 😴      │ 🎉      │                          │
│  │         │         │         │                          │
│  │ [Photo] │ [Photo] │ [Photo] │                          │
│  │         │         │         │                          │
│  │      ❤️3│         │      ❤️5│                          │
│  └─────────┴─────────┴─────────┘                          │
│  ┌─────────┬─────────┬─────────┐                          │
│  │ 😊      │ 😊      │ 🍼      │                          │
│  │         │         │         │                          │
│  │ [Photo] │ [Photo] │ [Photo] │                          │
│  │         │         │      ❤️8│                          │
│  │      ❤️2│      ❤️1│         │                          │
│  └─────────┴─────────┴─────────┘                          │
│                                                             │
│  Total: 127 photos                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📹 VIDEO STREAMING FLOW

### **ESP32-CAM → Firebase → Flutter Live Video**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VIDEO STREAMING ARCHITECTURE                             │
└─────────────────────────────────────────────────────────────────────────────┘

DEVICE SIDE (ESP32-CAM):
├─ OV2640 camera module
├─ Captures 640x480 JPEG frames
├─ Frame rate: 10-15 FPS
├─ Compression: JPEG quality 60%
└─ Streams via HTTP or WebSocket

TRANSPORT LAYER:
├─ Option 1: HTTP multipart stream (MJPEG)
├─ Option 2: WebSocket binary frames
├─ Option 3: WebRTC peer-to-peer
└─ Latency: 200-500ms (local WiFi)

FLUTTER APP:
├─ VideoCallScreen displays live feed
├─ Controls: mute, snapshot, night vision
├─ Overlay: vitals, cry detection, motion alerts
└─ Recording: save to Firebase Storage
```

### **ESP32-CAM Firmware (Arduino C++)**

```cpp
// ═══════════════════════════════════════════════════════════
// ESP32-CAM: Video Streaming Server
// ═══════════════════════════════════════════════════════════

#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>

WebServer server(80);

// Camera configuration
camera_config_t config;
config.ledc_channel = LEDC_CHANNEL_0;
config.ledc_timer = LEDC_TIMER_0;
config.pin_d0 = Y2_GPIO_NUM;
config.pin_d1 = Y3_GPIO_NUM;
// ... (all pins)
config.xclk_freq_hz = 20000000;
config.pixel_format = PIXFORMAT_JPEG;  // JPEG format
config.frame_size = FRAMESIZE_VGA;     // 640x480
config.jpeg_quality = 12;              // 0-63 (lower = higher quality)
config.fb_count = 2;                   // Double buffering

// Initialize camera
esp_err_t err = esp_camera_init(&config);
if (err != ESP_OK) {
  Serial.printf("Camera init failed: 0x%x", err);
  return;
}


// ═══════════════════════════════════════════════════════════
// HTTP MJPEG Stream Handler
// ═══════════════════════════════════════════════════════════

void handleMjpegStream() {
  WiFiClient client = server.client();
  
  // Send HTTP headers for multipart stream
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: multipart/x-mixed-replace; boundary=frame");
  client.println();
  
  while (client.connected()) {
    // Capture frame
    camera_fb_t * fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      break;
    }
    
    // Send frame boundary
    client.println("--frame");
    client.println("Content-Type: image/jpeg");
    client.printf("Content-Length: %u\r\n\r\n", fb->len);
    
    // Send JPEG data
    client.write(fb->buf, fb->len);
    client.println();
    
    // Return frame buffer
    esp_camera_fb_return(fb);
    
    // Control frame rate (100ms = ~10 FPS)
    delay(100);
  }
}

// Setup routes
void setup() {
  WiFi.begin(ssid, password);
  
  server.on("/stream", HTTP_GET, handleMjpegStream);
  server.on("/snapshot", HTTP_GET, handleSnapshot);
  
  server.begin();
  Serial.println("Camera stream ready at http://" + WiFi.localIP() + "/stream");
}

void loop() {
  server.handleClient();
}


// ═══════════════════════════════════════════════════════════
// EXAMPLE: Single Snapshot Capture
// ═══════════════════════════════════════════════════════════

void handleSnapshot() {
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "text/plain", "Camera capture failed");
    return;
  }
  
  // Send JPEG response
  server.sendHeader("Content-Disposition", "inline; filename=snapshot.jpg");
  server.send_P(200, "image/jpeg", (const char *)fb->buf, fb->len);
  
  esp_camera_fb_return(fb);
}
```

### **Flutter Video Display**

```dart
// ═══════════════════════════════════════════════════════════
// VIDEO CALL SCREEN (Live Monitoring)
// ═══════════════════════════════════════════════════════════

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  String? _streamUrl;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStreamUrl();
  }
  
  Future<void> _loadStreamUrl() async {
    // Get device from provider
    final device = context.read<DeviceProvider>().currentDevice;
    
    if (device != null && device.status == 'online') {
      setState(() {
        _streamUrl = 'http://${device.ipAddress}/stream';
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Video feed
            Container(
              height: 400,
              child: _streamUrl != null
                ? MjpegView(
                    streamUrl: _streamUrl!,
                    isLive: true,
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: Text('Device offline'),
                  ),
            ),
            
            // Controls
            _buildControls(),
            
            // Vitals overlay
            _buildVitalsOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.mic),
          onPressed: () => _toggleMicrophone(),
        ),
        IconButton(
          icon: Icon(Icons.videocam_off),
          onPressed: () => _pauseStream(),
        ),
        IconButton(
          icon: Icon(Icons.camera_alt),
          onPressed: () => _captureSnapshot(),
        ),
        IconButton(
          icon: Icon(Icons.nightlight),
          onPressed: () => _toggleNightVision(),
        ),
      ],
    );
  }
  
  // Capture snapshot from video stream
  Future<void> _captureSnapshot() async {
    final device = context.read<DeviceProvider>().currentDevice;
    final snapshotUrl = 'http://${device!.ipAddress}/snapshot';
    
    // Download JPEG
    final response = await http.get(Uri.parse(snapshotUrl));
    
    if (response.statusCode == 200) {
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      // Upload to Firebase (reuse PhotoService)
      final babyId = context.read<BabyProvider>().currentBaby!.id;
      final userId = context.read<AuthProvider>().currentUser!.uid;
      
      await PhotoService().uploadPhoto(
        babyId: babyId,
        userId: userId,
        photoFile: file,
        caption: 'Baby monitor snapshot',
        capturedAt: DateTime.now(),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snapshot saved to gallery!')),
      );
    }
  }
}


// ═══════════════════════════════════════════════════════════
// MJPEG VIEWER WIDGET (displays HTTP multipart stream)
// ═══════════════════════════════════════════════════════════

class MjpegView extends StatefulWidget {
  final String streamUrl;
  final bool isLive;
  final BoxFit fit;
  
  const MjpegView({
    required this.streamUrl,
    this.isLive = true,
    this.fit = BoxFit.contain,
  });
  
  @override
  _MjpegViewState createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  late HttpClient _httpClient;
  late StreamController<Uint8List> _frameController;
  
  @override
  void initState() {
    super.initState();
    _frameController = StreamController<Uint8List>();
    _startStream();
  }
  
  Future<void> _startStream() async {
    _httpClient = HttpClient();
    _httpClient.connectionTimeout = Duration(seconds: 5);
    
    try {
      final request = await _httpClient.getUrl(Uri.parse(widget.streamUrl));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        // Parse multipart stream
        await for (var data in response) {
          // Extract JPEG frames from multipart boundary
          // (Simplified - actual implementation needs boundary parsing)
          _frameController.add(data);
        }
      }
    } catch (e) {
      print('Stream error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List>(
      stream: _frameController.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          gaplessPlayback: true,  // Smooth frame transitions
        );
      },
    );
  }
  
  @override
  void dispose() {
    _httpClient.close();
    _frameController.close();
    super.dispose();
  }
}
```

---

## 🎯 COMPLETE FLOW SUMMARY

### **Photo Upload: Camera → Cloud → Gallery**

| Step | Location | Duration | Data Size | Output |
|------|----------|----------|-----------|---------|
| 1. Capture | Flutter App | 0ms | 2.4 MB (JPEG) | Local file |
| 2. Compress | Flutter | 200ms | → 1.8 MB | Optimized JPEG |
| 3. Upload | Firebase Storage | 3000ms | 1.8 MB | Download URL |
| 4. Save Metadata | Firestore | 100ms | 2 KB (JSON) | Document ID |
| 5. AI Analysis | Cloud Function | 2000ms | API call | AI tags |
| 6. Thumbnail | Cloud Function | 1500ms | 150 KB | Thumb URL |
| 7. Notify Family | FCM | 500ms | Push notification | Alert sent |
| **TOTAL** | **End-to-end** | **~7.3s** | **4 MB total** | **Live in gallery** |

### **Video Streaming: ESP32-CAM → App**

| Component | Technology | Data Rate | Latency |
|-----------|-----------|-----------|---------|
| Camera Capture | OV2640 sensor | 10 FPS, 640x480 | 0ms |
| JPEG Compression | ESP32 hardware | 20 KB/frame | 50ms |
| Network Transfer | HTTP/WiFi | 200 KB/s | 200ms |
| Frame Display | Flutter Image.memory | 10 FPS | 100ms |
| **TOTAL LATENCY** | **ESP32 → Screen** | - | **~350ms** |

---

## 🔐 SECURITY & PRIVACY

```dart
// ═══════════════════════════════════════════════════════════
// SECURITY RULES
// ═══════════════════════════════════════════════════════════

// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Photos - only family members
    match /babies/{babyId}/photos/{photoId} {
      allow read: if isFamilyMember(babyId);
      allow create: if isFamilyMember(babyId) && 
                       request.resource.data.uploadedBy == request.auth.uid;
      allow update: if isFamilyMember(babyId);
      allow delete: if isFamilyMember(babyId) && 
                       resource.data.uploadedBy == request.auth.uid;
    }
  }
  
  function isFamilyMember(babyId) {
    let baby = get(/databases/$(database)/documents/babies/$(babyId));
    return request.auth.uid in baby.data.familyMembers;
  }
}

// Storage Security Rules
service firebase.storage {
  match /b/{bucket}/o {
    match /photos/{babyId}/{fileName} {
      allow read: if request.auth != null && isFamilyMember(babyId);
      allow write: if request.auth != null && isFamilyMember(babyId);
    }
  }
}
```

---

## 📊 PERFORMANCE OPTIMIZATION

### **Best Practices**

1. **Lazy Loading:** Load photos in batches of 20 using pagination
2. **Thumbnail First:** Show 300x300 thumbnails in grid, full image on tap
3. **Caching:** Use `cached_network_image` package for automatic caching
4. **Compression:** Resize images before upload (max 1920x1080)
5. **Progressive Upload:** Show progress bar during upload
6. **Offline Support:** Queue uploads when offline, sync when online

### **Data Usage**

```
Average photo upload: 1.8 MB
Average thumbnail: 150 KB
Photos per day: ~10
Daily data usage: ~20 MB (uploads + views)
Monthly data usage: ~600 MB
```

---

## 🚀 FUTURE ENHANCEMENTS

1. **Video Recording** - Record and store video clips
2. **Live Streaming** - WebRTC for lower latency
3. **Cloud ML** - Advanced baby emotion detection
4. **Auto Albums** - AI-generated albums (birthdays, firsts, etc.)
5. **Shared Family Albums** - Collaborative photo albums
6. **Print Integration** - Order physical photo books
7. **Face Recognition** - Automatic family member tagging
8. **Smart Search** - Natural language photo search ("show me Emma sleeping last week")

---

**Documentation complete! Photo/video service fully architected.** 📸✅

