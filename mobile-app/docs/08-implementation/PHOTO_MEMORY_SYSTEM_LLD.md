# Photo Memory System - Low-Level Design (LLD)

**Document ID**: LLD-PHOTO-001  
**Version**: 1.0.0  
**Status**: 🟢 Ready for Implementation  
**Last Updated**: February 3, 2026  
**Feature**: Photo Memory System with AI Tagging & Albums

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Feature Gating & Subscription Tiers](#feature-gating--subscription-tiers)
3. [Data Models](#data-models)
4. [Service Layer](#service-layer)
5. [Cloud Functions](#cloud-functions)
6. [UI Components](#ui-components)
7. [AI Tagging & Search](#ai-tagging--search)
8. [Implementation Roadmap](#implementation-roadmap)

---

## 1. Overview

### 1.1 Purpose

The Photo Memory System enables parents to:
- **Capture & Store** - Upload photos/videos from phone or ESP32-CAM
- **Organize** - Create albums, tag people, events, milestones
- **Auto-Tag** - AI-powered tagging (facial recognition, object detection, scene classification)
- **Search** - Find photos by date, tag, baby, milestone, or AI-detected content
- **Share** - Generate shareable albums, memory books, PDFs
- **Timeline** - View photos in chronological timeline with contextual data (vitals, milestones, growth)

### 1.2 Key Features

| Feature | Free Tier | Premium Tier | Premium+Device |
|---------|-----------|--------------|----------------|
| Photo uploads | ✅ (100 photos) | ✅ (Unlimited) | ✅ (Unlimited) |
| Video uploads | ❌ | ✅ (10 GB) | ✅ (Unlimited) |
| Manual albums | ✅ (5 albums) | ✅ (Unlimited) | ✅ (Unlimited) |
| Manual tagging | ✅ | ✅ | ✅ |
| **AI auto-tagging** | ❌ | ✅ | ✅ |
| **Facial recognition** | ❌ | ✅ | ✅ |
| **Smart albums** | ❌ | ✅ | ✅ |
| **Timeline with vitals** | ❌ | ✅ | ✅ |
| **ESP32-CAM integration** | ❌ | ❌ | ✅ |
| **Memory book PDF** | ❌ | ✅ | ✅ |
| **Cloud backup** | Basic | Full | Full + Device |
| **Search by content** | Basic | Advanced AI | Advanced AI |

### 1.3 Device Dependencies

**Without AnvayaPod** (App-Only Mode):
- Manual photo uploads from phone only
- Basic organization and albums
- No ESP32-CAM auto-capture

**With AnvayaPod** (Premium + Device):
- ESP32-CAM automatic photo capture
- Milestone moment capture (triggered by events)
- Timeline integration with sensor data
- Auto-upload from device to cloud

### 1.4 Storage Limits

| Tier | Photos | Videos | Total Storage |
|------|--------|--------|---------------|
| Free | 100 | 0 | 500 MB |
| Premium | Unlimited | 1000 | 10 GB |
| Premium+Device | Unlimited | Unlimited | 50 GB |

---

## 2. Feature Gating & Subscription Tiers

### 2.1 Storage Model

```dart
enum StorageTier {
  free,           // 100 photos, 500 MB
  premium,        // Unlimited photos, 10 GB
  premiumDevice,  // Unlimited, 50 GB
}

class StorageQuota {
  final StorageTier tier;
  final int maxPhotos;
  final int maxVideos;
  final int maxStorageBytes;
  
  // Current usage
  final int currentPhotos;
  final int currentVideos;
  final int currentStorageBytes;

  StorageQuota({
    required this.tier,
    required this.maxPhotos,
    required this.maxVideos,
    required this.maxStorageBytes,
    this.currentPhotos = 0,
    this.currentVideos = 0,
    this.currentStorageBytes = 0,
  });

  bool get canUploadPhoto => 
      maxPhotos == -1 || currentPhotos < maxPhotos;
  
  bool get canUploadVideo => 
      maxVideos == -1 || currentVideos < maxVideos;
  
  bool canUploadSize(int bytes) => 
      maxStorageBytes == -1 || (currentStorageBytes + bytes) <= maxStorageBytes;
  
  int get photosRemaining => 
      maxPhotos == -1 ? 999999 : maxPhotos - currentPhotos;
  
  int get storageRemaining => 
      maxStorageBytes == -1 ? 999999999 : maxStorageBytes - currentStorageBytes;
  
  double get usagePercentage => 
      maxStorageBytes == -1 ? 0.0 : (currentStorageBytes / maxStorageBytes) * 100;

  static StorageQuota forTier(StorageTier tier) {
    switch (tier) {
      case StorageTier.free:
        return StorageQuota(
          tier: tier,
          maxPhotos: 100,
          maxVideos: 0,
          maxStorageBytes: 500 * 1024 * 1024, // 500 MB
        );
      case StorageTier.premium:
        return StorageQuota(
          tier: tier,
          maxPhotos: -1, // Unlimited
          maxVideos: 1000,
          maxStorageBytes: 10 * 1024 * 1024 * 1024, // 10 GB
        );
      case StorageTier.premiumDevice:
        return StorageQuota(
          tier: tier,
          maxPhotos: -1,
          maxVideos: -1,
          maxStorageBytes: 50 * 1024 * 1024 * 1024, // 50 GB
        );
    }
  }
}
```

### 2.2 Feature Access Model

```dart
class PhotoFeatureAccess {
  final SubscriptionTier tier;
  final DeviceType deviceType;

  PhotoFeatureAccess({
    required this.tier,
    required this.deviceType,
  });

  // AI Features (Premium only)
  bool get canUseAITagging => tier != SubscriptionTier.free;
  bool get canUseFacialRecognition => tier != SubscriptionTier.free;
  bool get canUseSmartAlbums => tier != SubscriptionTier.free;
  bool get canUseAdvancedSearch => tier != SubscriptionTier.free;
  
  // Device Features
  bool get canUseESP32CAM => 
      tier != SubscriptionTier.free && deviceType == DeviceType.anvayaPod;
  bool get canAutoCapture => canUseESP32CAM;
  bool get canSyncVitals => canUseESP32CAM;
  
  // Export Features
  bool get canExportMemoryBook => tier != SubscriptionTier.free;
  bool get canExportHighRes => tier != SubscriptionTier.free;
  bool get canShareAlbums => true; // All tiers
  
  // Video Features
  bool get canUploadVideos => tier != SubscriptionTier.free;
  
  // Album Limits
  int get maxAlbums => tier == SubscriptionTier.free ? 5 : -1;
  
  // Storage
  StorageQuota get storageQuota {
    if (tier == SubscriptionTier.free) {
      return StorageQuota.forTier(StorageTier.free);
    } else if (deviceType == DeviceType.anvayaPod) {
      return StorageQuota.forTier(StorageTier.premiumDevice);
    } else {
      return StorageQuota.forTier(StorageTier.premium);
    }
  }
}
```

---

## 3. Data Models

### 3.1 Flutter Model: `PhotoModel`

**File**: `lib/models/photo_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PhotoSource {
  phoneCamera,    // Uploaded from phone camera
  phoneGallery,   // Selected from phone gallery
  esp32Cam,       // Captured by ESP32-CAM
  imported,       // Imported from external source
}

enum PhotoType {
  photo,
  video,
  burst,          // Burst photo sequence
}

class PhotoModel {
  final String id;
  final String babyId;
  final String userId;
  
  // Media info
  final PhotoType type;
  final PhotoSource source;
  final String url; // Firebase Storage URL
  final String? thumbnailUrl; // Compressed thumbnail
  final String? originalUrl; // Full resolution (premium only)
  
  // Metadata
  final DateTime capturedAt; // When photo was taken
  final DateTime uploadedAt; // When photo was uploaded
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final String? deviceModel; // Camera model or "ESP32-CAM"
  
  // Organization
  final List<String> albumIds; // Albums this photo belongs to
  final List<String> tagIds; // Manual tags
  final List<String> aiTags; // AI-detected tags (Premium)
  final String? caption; // User caption
  final String? location; // e.g., "Home", "Hospital", "Park"
  
  // AI Detection (Premium only)
  final Map<String, double>? aiLabels; // {"smile": 0.95, "happy": 0.89}
  final List<FaceDetection>? faces; // Detected faces
  final String? dominantColor; // Hex color
  final double? qualityScore; // 0-1, photo quality
  
  // Associations
  final String? milestoneId; // Associated milestone
  final String? feedingSessionId;
  final String? sleepSessionId;
  final String? growthRecordId;
  
  // Baby context at time of photo
  final int? babyAgeInDays;
  final double? babyWeightKg; // Weight at time of photo
  final double? babyHeightCm;
  
  // Engagement
  final int viewCount;
  final int shareCount;
  final bool isFavorite;
  final DateTime? lastViewedAt;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isProcessing; // AI processing in progress

  PhotoModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.type,
    required this.source,
    required this.url,
    this.thumbnailUrl,
    this.originalUrl,
    required this.capturedAt,
    required this.uploadedAt,
    required this.fileSizeBytes,
    this.width,
    this.height,
    this.deviceModel,
    this.albumIds = const [],
    this.tagIds = const [],
    this.aiTags = const [],
    this.caption,
    this.location,
    this.aiLabels,
    this.faces,
    this.dominantColor,
    this.qualityScore,
    this.milestoneId,
    this.feedingSessionId,
    this.sleepSessionId,
    this.growthRecordId,
    this.babyAgeInDays,
    this.babyWeightKg,
    this.babyHeightCm,
    this.viewCount = 0,
    this.shareCount = 0,
    this.isFavorite = false,
    this.lastViewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isProcessing = false,
  });

  // Computed properties
  bool get isFromDevice => source == PhotoSource.esp32Cam;
  bool get hasAIData => aiLabels != null || faces != null;
  bool get isVideo => type == PhotoType.video;
  
  String get fileSizeDisplay {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'userId': userId,
      'type': type.name,
      'source': source.name,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'originalUrl': originalUrl,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'fileSizeBytes': fileSizeBytes,
      'width': width,
      'height': height,
      'deviceModel': deviceModel,
      'albumIds': albumIds,
      'tagIds': tagIds,
      'aiTags': aiTags,
      'caption': caption,
      'location': location,
      'aiLabels': aiLabels,
      'faces': faces?.map((f) => f.toMap()).toList(),
      'dominantColor': dominantColor,
      'qualityScore': qualityScore,
      'milestoneId': milestoneId,
      'feedingSessionId': feedingSessionId,
      'sleepSessionId': sleepSessionId,
      'growthRecordId': growthRecordId,
      'babyAgeInDays': babyAgeInDays,
      'babyWeightKg': babyWeightKg,
      'babyHeightCm': babyHeightCm,
      'viewCount': viewCount,
      'shareCount': shareCount,
      'isFavorite': isFavorite,
      'lastViewedAt': lastViewedAt != null ? Timestamp.fromDate(lastViewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'isProcessing': isProcessing,
    };
  }

  factory PhotoModel.fromMap(Map<String, dynamic> map) {
    return PhotoModel(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      type: PhotoType.values.firstWhere((e) => e.name == map['type']),
      source: PhotoSource.values.firstWhere((e) => e.name == map['source']),
      url: map['url'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      originalUrl: map['originalUrl'] as String?,
      capturedAt: (map['capturedAt'] as Timestamp).toDate(),
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
      fileSizeBytes: map['fileSizeBytes'] as int,
      width: map['width'] as int?,
      height: map['height'] as int?,
      deviceModel: map['deviceModel'] as String?,
      albumIds: (map['albumIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      tagIds: (map['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      aiTags: (map['aiTags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      caption: map['caption'] as String?,
      location: map['location'] as String?,
      aiLabels: map['aiLabels'] != null
          ? Map<String, double>.from(map['aiLabels'] as Map)
          : null,
      faces: (map['faces'] as List<dynamic>?)
          ?.map((f) => FaceDetection.fromMap(f as Map<String, dynamic>))
          .toList(),
      dominantColor: map['dominantColor'] as String?,
      qualityScore: map['qualityScore'] as double?,
      milestoneId: map['milestoneId'] as String?,
      feedingSessionId: map['feedingSessionId'] as String?,
      sleepSessionId: map['sleepSessionId'] as String?,
      growthRecordId: map['growthRecordId'] as String?,
      babyAgeInDays: map['babyAgeInDays'] as int?,
      babyWeightKg: map['babyWeightKg'] as double?,
      babyHeightCm: map['babyHeightCm'] as double?,
      viewCount: map['viewCount'] as int? ?? 0,
      shareCount: map['shareCount'] as int? ?? 0,
      isFavorite: map['isFavorite'] as bool? ?? false,
      lastViewedAt: map['lastViewedAt'] != null
          ? (map['lastViewedAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      isProcessing: map['isProcessing'] as bool? ?? false,
    );
  }

  factory PhotoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PhotoModel.fromMap({...data, 'id': doc.id});
  }

  PhotoModel copyWith({
    String? id,
    String? babyId,
    String? userId,
    PhotoType? type,
    PhotoSource? source,
    String? url,
    String? thumbnailUrl,
    String? originalUrl,
    DateTime? capturedAt,
    DateTime? uploadedAt,
    int? fileSizeBytes,
    int? width,
    int? height,
    String? deviceModel,
    List<String>? albumIds,
    List<String>? tagIds,
    List<String>? aiTags,
    String? caption,
    String? location,
    Map<String, double>? aiLabels,
    List<FaceDetection>? faces,
    String? dominantColor,
    double? qualityScore,
    String? milestoneId,
    String? feedingSessionId,
    String? sleepSessionId,
    String? growthRecordId,
    int? babyAgeInDays,
    double? babyWeightKg,
    double? babyHeightCm,
    int? viewCount,
    int? shareCount,
    bool? isFavorite,
    DateTime? lastViewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isProcessing,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      source: source ?? this.source,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      deviceModel: deviceModel ?? this.deviceModel,
      albumIds: albumIds ?? this.albumIds,
      tagIds: tagIds ?? this.tagIds,
      aiTags: aiTags ?? this.aiTags,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      aiLabels: aiLabels ?? this.aiLabels,
      faces: faces ?? this.faces,
      dominantColor: dominantColor ?? this.dominantColor,
      qualityScore: qualityScore ?? this.qualityScore,
      milestoneId: milestoneId ?? this.milestoneId,
      feedingSessionId: feedingSessionId ?? this.feedingSessionId,
      sleepSessionId: sleepSessionId ?? this.sleepSessionId,
      growthRecordId: growthRecordId ?? this.growthRecordId,
      babyAgeInDays: babyAgeInDays ?? this.babyAgeInDays,
      babyWeightKg: babyWeightKg ?? this.babyWeightKg,
      babyHeightCm: babyHeightCm ?? this.babyHeightCm,
      viewCount: viewCount ?? this.viewCount,
      shareCount: shareCount ?? this.shareCount,
      isFavorite: isFavorite ?? this.isFavorite,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Face detection data (from AI)
class FaceDetection {
  final String faceId; // Unique ID for this face
  final String? personId; // Matched person (baby, parent, etc.)
  final String? personName;
  final double confidence; // 0-1
  final Map<String, double> boundingBox; // {x, y, width, height}
  final Map<String, double>? emotions; // {"happy": 0.9, "surprised": 0.1}

  FaceDetection({
    required this.faceId,
    this.personId,
    this.personName,
    required this.confidence,
    required this.boundingBox,
    this.emotions,
  });

  Map<String, dynamic> toMap() {
    return {
      'faceId': faceId,
      'personId': personId,
      'personName': personName,
      'confidence': confidence,
      'boundingBox': boundingBox,
      'emotions': emotions,
    };
  }

  factory FaceDetection.fromMap(Map<String, dynamic> map) {
    return FaceDetection(
      faceId: map['faceId'] as String,
      personId: map['personId'] as String?,
      personName: map['personName'] as String?,
      confidence: map['confidence'] as double,
      boundingBox: Map<String, double>.from(map['boundingBox'] as Map),
      emotions: map['emotions'] != null
          ? Map<String, double>.from(map['emotions'] as Map)
          : null,
    );
  }
}
```

### 3.2 Flutter Model: `AlbumModel`

**File**: `lib/models/album_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AlbumType {
  manual,         // User-created album
  smart,          // AI-generated (Premium)
  milestone,      // Auto-created from milestones
  monthly,        // Auto-created monthly albums
}

class AlbumModel {
  final String id;
  final String babyId;
  final String userId;
  
  // Album info
  final String title;
  final String? description;
  final AlbumType type;
  final String? coverPhotoUrl; // First photo or user-selected
  
  // Smart album criteria (Premium only)
  final Map<String, dynamic>? smartCriteria; // {"tag": "smile", "minConfidence": 0.8}
  
  // Stats
  final int photoCount;
  final int videoCount;
  final DateTime? firstPhotoDate;
  final DateTime? lastPhotoDate;
  
  // Settings
  final bool isPrivate; // Not shared with family
  final bool isPinned; // Show at top
  final int sortOrder; // Manual ordering
  
  // Sharing
  final List<String> sharedWithUserIds;
  final String? shareCode; // Public share link code
  final DateTime? shareExpiresAt;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  AlbumModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.title,
    this.description,
    required this.type,
    this.coverPhotoUrl,
    this.smartCriteria,
    this.photoCount = 0,
    this.videoCount = 0,
    this.firstPhotoDate,
    this.lastPhotoDate,
    this.isPrivate = false,
    this.isPinned = false,
    this.sortOrder = 0,
    this.sharedWithUserIds = const [],
    this.shareCode,
    this.shareExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get isSmart => type == AlbumType.smart;
  bool get isShared => sharedWithUserIds.isNotEmpty || shareCode != null;
  int get totalMediaCount => photoCount + videoCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'userId': userId,
      'title': title,
      'description': description,
      'type': type.name,
      'coverPhotoUrl': coverPhotoUrl,
      'smartCriteria': smartCriteria,
      'photoCount': photoCount,
      'videoCount': videoCount,
      'firstPhotoDate': firstPhotoDate != null ? Timestamp.fromDate(firstPhotoDate!) : null,
      'lastPhotoDate': lastPhotoDate != null ? Timestamp.fromDate(lastPhotoDate!) : null,
      'isPrivate': isPrivate,
      'isPinned': isPinned,
      'sortOrder': sortOrder,
      'sharedWithUserIds': sharedWithUserIds,
      'shareCode': shareCode,
      'shareExpiresAt': shareExpiresAt != null ? Timestamp.fromDate(shareExpiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
    };
  }

  factory AlbumModel.fromMap(Map<String, dynamic> map) {
    return AlbumModel(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: AlbumType.values.firstWhere((e) => e.name == map['type']),
      coverPhotoUrl: map['coverPhotoUrl'] as String?,
      smartCriteria: map['smartCriteria'] as Map<String, dynamic>?,
      photoCount: map['photoCount'] as int? ?? 0,
      videoCount: map['videoCount'] as int? ?? 0,
      firstPhotoDate: map['firstPhotoDate'] != null
          ? (map['firstPhotoDate'] as Timestamp).toDate()
          : null,
      lastPhotoDate: map['lastPhotoDate'] != null
          ? (map['lastPhotoDate'] as Timestamp).toDate()
          : null,
      isPrivate: map['isPrivate'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
      sharedWithUserIds: (map['sharedWithUserIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      shareCode: map['shareCode'] as String?,
      shareExpiresAt: map['shareExpiresAt'] != null
          ? (map['shareExpiresAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  factory AlbumModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlbumModel.fromMap({...data, 'id': doc.id});
  }

  AlbumModel copyWith({
    String? id,
    String? babyId,
    String? userId,
    String? title,
    String? description,
    AlbumType? type,
    String? coverPhotoUrl,
    Map<String, dynamic>? smartCriteria,
    int? photoCount,
    int? videoCount,
    DateTime? firstPhotoDate,
    DateTime? lastPhotoDate,
    bool? isPrivate,
    bool? isPinned,
    int? sortOrder,
    List<String>? sharedWithUserIds,
    String? shareCode,
    DateTime? shareExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return AlbumModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      smartCriteria: smartCriteria ?? this.smartCriteria,
      photoCount: photoCount ?? this.photoCount,
      videoCount: videoCount ?? this.videoCount,
      firstPhotoDate: firstPhotoDate ?? this.firstPhotoDate,
      lastPhotoDate: lastPhotoDate ?? this.lastPhotoDate,
      isPrivate: isPrivate ?? this.isPrivate,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      shareCode: shareCode ?? this.shareCode,
      shareExpiresAt: shareExpiresAt ?? this.shareExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
```

### 3.3 Firestore Schema

#### Collection: `photos`

```
photos/{photoId}
├── id: string
├── babyId: string (indexed)
├── userId: string
├── type: string ('photo' | 'video' | 'burst')
├── source: string ('phoneCamera' | 'phoneGallery' | 'esp32Cam' | 'imported')
├── url: string
├── thumbnailUrl: string | null
├── originalUrl: string | null (Premium)
├── capturedAt: timestamp (indexed)
├── uploadedAt: timestamp
├── fileSizeBytes: number
├── width: number | null
├── height: number | null
├── deviceModel: string | null
├── albumIds: array<string>
├── tagIds: array<string>
├── aiTags: array<string> (Premium)
├── caption: string | null
├── location: string | null
├── aiLabels: object | null (Premium)
├── faces: array<object> | null (Premium)
├── dominantColor: string | null
├── qualityScore: number | null
├── milestoneId: string | null
├── feedingSessionId: string | null
├── sleepSessionId: string | null
├── growthRecordId: string | null
├── babyAgeInDays: number | null
├── babyWeightKg: number | null
├── babyHeightCm: number | null
├── viewCount: number
├── shareCount: number
├── isFavorite: boolean
├── lastViewedAt: timestamp | null
├── createdAt: timestamp
├── updatedAt: timestamp
├── isDeleted: boolean
└── isProcessing: boolean
```

**Firestore Indexes**:
```javascript
{
  collectionGroup: "photos",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "capturedAt", order: "DESCENDING" }
  ]
},
{
  collectionGroup: "photos",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "isFavorite", order: "DESCENDING" },
    { fieldPath: "capturedAt", order: "DESCENDING" }
  ]
},
{
  collectionGroup: "photos",
  fields: [
    { fieldPath: "userId", order: "ASCENDING" },
    { fieldPath: "capturedAt", order: "DESCENDING" }
  ]
}
```

#### Collection: `albums`

```
albums/{albumId}
├── id: string
├── babyId: string (indexed)
├── userId: string
├── title: string
├── description: string | null
├── type: string ('manual' | 'smart' | 'milestone' | 'monthly')
├── coverPhotoUrl: string | null
├── smartCriteria: object | null (Premium)
├── photoCount: number
├── videoCount: number
├── firstPhotoDate: timestamp | null
├── lastPhotoDate: timestamp | null
├── isPrivate: boolean
├── isPinned: boolean
├── sortOrder: number
├── sharedWithUserIds: array<string>
├── shareCode: string | null
├── shareExpiresAt: timestamp | null
├── createdAt: timestamp
├── updatedAt: timestamp
└── isDeleted: boolean
```

#### Collection: `user_storage_usage`

```
user_storage_usage/{userId}
├── userId: string
├── tier: string ('free' | 'premium' | 'premiumDevice')
├── totalPhotos: number
├── totalVideos: number
├── totalStorageBytes: number
├── lastCalculatedAt: timestamp
└── updatedAt: timestamp
```

---

## 4. Service Layer

### 4.1 PhotoService

**File**: `lib/services/photo_service.dart`

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../models/photo_model.dart';
import '../models/album_model.dart';
import '../models/baby_model.dart';
import 'feature_gate_service.dart';

class PhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PhotoFeatureAccess _featureAccess;

  PhotoService({
    required PhotoFeatureAccess featureAccess,
  }) : _featureAccess = featureAccess;

  CollectionReference get _photosCollection => _firestore.collection('photos');
  CollectionReference get _albumsCollection => _firestore.collection('albums');
  CollectionReference get _usageCollection => _firestore.collection('user_storage_usage');

  // ============================================================================
  // Photo Upload
  // ============================================================================

  /// Upload photo with storage quota check
  Future<PhotoModel> uploadPhoto({
    required String babyId,
    required String userId,
    required File imageFile,
    required BabyModel baby,
    PhotoSource source = PhotoSource.phoneGallery,
    String? caption,
    String? location,
    List<String>? albumIds,
    List<String>? tagIds,
    String? milestoneId,
  }) async {
    // Check storage quota
    final usage = await _getStorageUsage(userId);
    final quota = _featureAccess.storageQuota;
    
    if (!quota.canUploadPhoto) {
      throw StorageQuotaExceeded(
        'Photo limit reached (${quota.maxPhotos}). Upgrade to Premium for unlimited photos.',
      );
    }

    final fileSize = await imageFile.length();
    if (!quota.canUploadSize(fileSize)) {
      throw StorageQuotaExceeded(
        'Storage limit reached. Upgrade for more space.',
      );
    }

    final now = DateTime.now();
    final photoId = _photosCollection.doc().id;
    
    // Generate thumbnail
    final thumbnail = await _generateThumbnail(imageFile);
    
    // Upload original (Premium gets full res, Free gets compressed)
    final uploadedUrls = await _uploadToStorage(
      photoId: photoId,
      originalFile: imageFile,
      thumbnail: thumbnail,
      userId: userId,
      isPremium: _featureAccess.canExportHighRes,
    );

    // Get image dimensions
    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);
    
    final babyAgeInDays = now.difference(baby.dateOfBirth).inDays;

    final photo = PhotoModel(
      id: photoId,
      babyId: babyId,
      userId: userId,
      type: PhotoType.photo,
      source: source,
      url: uploadedUrls['url']!,
      thumbnailUrl: uploadedUrls['thumbnailUrl'],
      originalUrl: uploadedUrls['originalUrl'],
      capturedAt: now,
      uploadedAt: now,
      fileSizeBytes: fileSize,
      width: decodedImage?.width,
      height: decodedImage?.height,
      albumIds: albumIds ?? [],
      tagIds: tagIds ?? [],
      caption: caption,
      location: location,
      milestoneId: milestoneId,
      babyAgeInDays: babyAgeInDays,
      isProcessing: _featureAccess.canUseAITagging, // Start AI processing if premium
      createdAt: now,
      updatedAt: now,
    );

    await _photosCollection.doc(photoId).set(photo.toMap());

    // Update storage usage
    await _updateStorageUsage(userId, photoCount: 1, storageBytes: fileSize);

    // Update album photo counts
    if (albumIds != null && albumIds.isNotEmpty) {
      for (final albumId in albumIds) {
        await _incrementAlbumPhotoCount(albumId);
      }
    }

    // Trigger AI processing for Premium users
    if (_featureAccess.canUseAITagging) {
      await _triggerAIProcessing(photoId);
    }

    return photo;
  }

  /// Upload video (Premium only)
  Future<PhotoModel> uploadVideo({
    required String babyId,
    required String userId,
    required File videoFile,
    required BabyModel baby,
    String? caption,
    String? location,
    List<String>? albumIds,
  }) async {
    // Check premium access
    if (!_featureAccess.canUploadVideos) {
      throw FeatureLockedError(
        featureName: 'Video Upload',
        requiredTier: SubscriptionTier.premium,
        currentTier: _featureAccess.tier,
      );
    }

    // Check storage quota
    final usage = await _getStorageUsage(userId);
    final quota = _featureAccess.storageQuota;
    
    if (!quota.canUploadVideo) {
      throw StorageQuotaExceeded(
        'Video limit reached (${quota.maxVideos}).',
      );
    }

    final fileSize = await videoFile.length();
    if (!quota.canUploadSize(fileSize)) {
      throw StorageQuotaExceeded('Storage limit reached.');
    }

    final now = DateTime.now();
    final photoId = _photosCollection.doc().id;
    
    // Upload video
    final videoUrl = await _uploadVideoToStorage(
      photoId: photoId,
      videoFile: videoFile,
      userId: userId,
    );

    final babyAgeInDays = now.difference(baby.dateOfBirth).inDays;

    final video = PhotoModel(
      id: photoId,
      babyId: babyId,
      userId: userId,
      type: PhotoType.video,
      source: PhotoSource.phoneGallery,
      url: videoUrl,
      capturedAt: now,
      uploadedAt: now,
      fileSizeBytes: fileSize,
      albumIds: albumIds ?? [],
      caption: caption,
      location: location,
      babyAgeInDays: babyAgeInDays,
      createdAt: now,
      updatedAt: now,
    );

    await _photosCollection.doc(photoId).set(video.toMap());
    await _updateStorageUsage(userId, videoCount: 1, storageBytes: fileSize);

    if (albumIds != null && albumIds.isNotEmpty) {
      for (final albumId in albumIds) {
        await _incrementAlbumVideoCount(albumId);
      }
    }

    return video;
  }

  // ============================================================================
  // Photo Query
  // ============================================================================

  /// Get photos for baby
  Future<List<PhotoModel>> getPhotos({
    required String babyId,
    DateTime? startDate,
    DateTime? endDate,
    bool favoritesOnly = false,
    int? limit,
  }) async {
    Query query = _photosCollection
        .where('babyId', isEqualTo: babyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('capturedAt', descending: true);

    if (favoritesOnly) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    if (startDate != null) {
      query = query.where('capturedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('capturedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
  }

  /// Stream photos
  Stream<List<PhotoModel>> streamPhotos({
    required String babyId,
    String? albumId,
  }) {
    Query query = _photosCollection
        .where('babyId', isEqualTo: babyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('capturedAt', descending: true);

    if (albumId != null) {
      query = query.where('albumIds', arrayContains: albumId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList());
  }

  /// Search photos by AI tags (Premium only)
  Future<List<PhotoModel>> searchPhotosByAI({
    required String babyId,
    required String searchTerm,
  }) async {
    if (!_featureAccess.canUseAdvancedSearch) {
      throw FeatureLockedError(
        featureName: 'AI Search',
        requiredTier: SubscriptionTier.premium,
        currentTier: _featureAccess.tier,
      );
    }

    final snapshot = await _photosCollection
        .where('babyId', isEqualTo: babyId)
        .where('aiTags', arrayContains: searchTerm.toLowerCase())
        .where('isDeleted', isEqualTo: false)
        .orderBy('capturedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
  }

  // ============================================================================
  // Album Management
  // ============================================================================

  /// Create album
  Future<AlbumModel> createAlbum({
    required String babyId,
    required String userId,
    required String title,
    String? description,
    AlbumType type = AlbumType.manual,
    Map<String, dynamic>? smartCriteria,
  }) async {
    // Check album limit for free tier
    if (_featureAccess.maxAlbums != -1) {
      final existingAlbums = await _albumsCollection
          .where('babyId', isEqualTo: babyId)
          .where('isDeleted', isEqualTo: false)
          .get();
      
      if (existingAlbums.docs.length >= _featureAccess.maxAlbums) {
        throw FeatureLockedError(
          featureName: 'Create Album',
          requiredTier: SubscriptionTier.premium,
          currentTier: _featureAccess.tier,
        );
      }
    }

    // Smart albums require Premium
    if (type == AlbumType.smart && !_featureAccess.canUseSmartAlbums) {
      throw FeatureLockedError(
        featureName: 'Smart Albums',
        requiredTier: SubscriptionTier.premium,
        currentTier: _featureAccess.tier,
      );
    }

    final now = DateTime.now();
    final album = AlbumModel(
      id: '',
      babyId: babyId,
      userId: userId,
      title: title,
      description: description,
      type: type,
      smartCriteria: smartCriteria,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _albumsCollection.add(album.toMap());
    return album.copyWith(id: docRef.id);
  }

  /// Get albums
  Future<List<AlbumModel>> getAlbums({
    required String babyId,
    bool pinnedOnly = false,
  }) async {
    Query query = _albumsCollection
        .where('babyId', isEqualTo: babyId)
        .where('isDeleted', isEqualTo: false);

    if (pinnedOnly) {
      query = query.where('isPinned', isEqualTo: true);
    }

    query = query.orderBy('sortOrder');

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AlbumModel.fromFirestore(doc)).toList();
  }

  /// Add photo to album
  Future<void> addPhotoToAlbum({
    required String photoId,
    required String albumId,
  }) async {
    await _photosCollection.doc(photoId).update({
      'albumIds': FieldValue.arrayUnion([albumId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _incrementAlbumPhotoCount(albumId);
  }

  /// Remove photo from album
  Future<void> removePhotoFromAlbum({
    required String photoId,
    required String albumId,
  }) async {
    await _photosCollection.doc(photoId).update({
      'albumIds': FieldValue.arrayRemove([albumId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _decrementAlbumPhotoCount(albumId);
  }

  // ============================================================================
  // Photo Actions
  // ============================================================================

  /// Toggle favorite
  Future<void> toggleFavorite(String photoId, bool isFavorite) async {
    await _photosCollection.doc(photoId).update({
      'isFavorite': !isFavorite,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update caption
  Future<void> updateCaption(String photoId, String caption) async {
    await _photosCollection.doc(photoId).update({
      'caption': caption,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete photo
  Future<void> deletePhoto(String photoId) async {
    final photoDoc = await _photosCollection.doc(photoId).get();
    final photo = PhotoModel.fromFirestore(photoDoc);

    // Soft delete
    await _photosCollection.doc(photoId).update({
      'isDeleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update storage usage
    await _updateStorageUsage(
      photo.userId,
      photoCount: -1,
      storageBytes: -photo.fileSizeBytes,
    );

    // Update album counts
    for (final albumId in photo.albumIds) {
      if (photo.isVideo) {
        await _decrementAlbumVideoCount(albumId);
      } else {
        await _decrementAlbumPhotoCount(albumId);
      }
    }
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  Future<Map<String, String>> _uploadToStorage({
    required String photoId,
    required File originalFile,
    required File thumbnail,
    required String userId,
    required bool isPremium,
  }) async {
    final urls = <String, String>{};

    // Upload thumbnail (all tiers)
    final thumbnailRef = _storage.ref('photos/$userId/$photoId/thumbnail.jpg');
    await thumbnailRef.putFile(thumbnail);
    urls['thumbnailUrl'] = await thumbnailRef.getDownloadURL();

    if (isPremium) {
      // Premium: Upload original full resolution
      final originalRef = _storage.ref('photos/$userId/$photoId/original.jpg');
      await originalRef.putFile(originalFile);
      urls['originalUrl'] = await originalRef.getDownloadURL();
      
      // Also upload compressed for normal viewing
      final compressed = await _compressImage(originalFile, quality: 85);
      final compressedRef = _storage.ref('photos/$userId/$photoId/photo.jpg');
      await compressedRef.putFile(compressed);
      urls['url'] = await compressedRef.getDownloadURL();
    } else {
      // Free: Only upload compressed version
      final compressed = await _compressImage(originalFile, quality: 70);
      final compressedRef = _storage.ref('photos/$userId/$photoId/photo.jpg');
      await compressedRef.putFile(compressed);
      urls['url'] = await compressedRef.getDownloadURL();
    }

    return urls;
  }

  Future<File> _generateThumbnail(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    final thumbnail = img.copyResize(image, width: 200);
    final thumbnailFile = File('${imageFile.path}_thumb.jpg');
    await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 80));

    return thumbnailFile;
  }

  Future<File> _compressImage(File imageFile, {int quality = 85}) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Max width 1920px for compressed version
    final compressed = image.width > 1920
        ? img.copyResize(image, width: 1920)
        : image;

    final compressedFile = File('${imageFile.path}_compressed.jpg');
    await compressedFile.writeAsBytes(img.encodeJpg(compressed, quality: quality));

    return compressedFile;
  }

  Future<String> _uploadVideoToStorage({
    required String photoId,
    required File videoFile,
    required String userId,
  }) async {
    final videoRef = _storage.ref('videos/$userId/$photoId/video.mp4');
    await videoRef.putFile(videoFile);
    return await videoRef.getDownloadURL();
  }

  Future<StorageUsage> _getStorageUsage(String userId) async {
    final doc = await _usageCollection.doc(userId).get();
    if (!doc.exists) {
      return StorageUsage(
        userId: userId,
        tier: _featureAccess.tier.name,
        totalPhotos: 0,
        totalVideos: 0,
        totalStorageBytes: 0,
      );
    }
    return StorageUsage.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> _updateStorageUsage(
    String userId, {
    int photoCount = 0,
    int videoCount = 0,
    int storageBytes = 0,
  }) async {
    await _usageCollection.doc(userId).set({
      'userId': userId,
      'tier': _featureAccess.tier.name,
      'totalPhotos': FieldValue.increment(photoCount),
      'totalVideos': FieldValue.increment(videoCount),
      'totalStorageBytes': FieldValue.increment(storageBytes),
      'lastCalculatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _incrementAlbumPhotoCount(String albumId) async {
    await _albumsCollection.doc(albumId).update({
      'photoCount': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _decrementAlbumPhotoCount(String albumId) async {
    await _albumsCollection.doc(albumId).update({
      'photoCount': FieldValue.increment(-1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _incrementAlbumVideoCount(String albumId) async {
    await _albumsCollection.doc(albumId).update({
      'videoCount': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _decrementAlbumVideoCount(String albumId) async {
    await _albumsCollection.doc(albumId).update({
      'videoCount': FieldValue.increment(-1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _triggerAIProcessing(String photoId) async {
    // This will be handled by Cloud Functions
    // Just mark as processing
    await _photosCollection.doc(photoId).update({
      'isProcessing': true,
    });
  }
}

class StorageUsage {
  final String userId;
  final String tier;
  final int totalPhotos;
  final int totalVideos;
  final int totalStorageBytes;

  StorageUsage({
    required this.userId,
    required this.tier,
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalStorageBytes,
  });

  factory StorageUsage.fromMap(Map<String, dynamic> map) {
    return StorageUsage(
      userId: map['userId'] as String,
      tier: map['tier'] as String,
      totalPhotos: map['totalPhotos'] as int? ?? 0,
      totalVideos: map['totalVideos'] as int? ?? 0,
      totalStorageBytes: map['totalStorageBytes'] as int? ?? 0,
    );
  }
}

class StorageQuotaExceeded implements Exception {
  final String message;
  StorageQuotaExceeded(this.message);
  
  @override
  String toString() => message;
}
```

---

## 5. Cloud Functions

### 5.1 AI Photo Tagging (Premium Only)

**File**: `functions/src/photos/processPhotoAI.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import vision from '@google-cloud/vision';

const visionClient = new vision.ImageAnnotatorClient();

/**
 * Trigger: When photo is uploaded with isProcessing=true
 * Action: Run AI analysis (labels, faces, colors)
 * Requires: Premium subscription
 */
export const processPhotoAI = functions.firestore
  .document('photos/{photoId}')
  .onCreate(async (snapshot, context) => {
    const photo = snapshot.data();
    const photoId = context.params.photoId;

    // Skip if not processing or user not premium
    if (!photo.isProcessing) return null;

    const userDoc = await admin.firestore().collection('users').doc(photo.userId).get();
    if (!userDoc.exists) return null;

    const user = userDoc.data()!;
    if (user.subscriptionTier === 'free') {
      // Free tier doesn't get AI processing
      await snapshot.ref.update({ isProcessing: false });
      return null;
    }

    try {
      // Run Vision API analysis
      const [result] = await visionClient.annotateImage({
        image: { source: { imageUri: photo.url } },
        features: [
          { type: 'LABEL_DETECTION', maxResults: 10 },
          { type: 'FACE_DETECTION', maxResults: 5 },
          { type: 'IMAGE_PROPERTIES' },
          { type: 'SAFE_SEARCH_DETECTION' },
        ],
      });

      // Extract labels
      const aiLabels: { [key: string]: number } = {};
      if (result.labelAnnotations) {
        result.labelAnnotations.forEach(label => {
          aiLabels[label.description!.toLowerCase()] = label.score!;
        });
      }

      // Extract AI tags (high confidence labels)
      const aiTags = Object.entries(aiLabels)
        .filter(([_, score]) => score > 0.7)
        .map(([label, _]) => label);

      // Extract faces
      const faces: any[] = [];
      if (result.faceAnnotations) {
        result.faceAnnotations.forEach((face, index) => {
          const boundingPoly = face.boundingPoly!.vertices!;
          faces.push({
            faceId: `face_${photoId}_${index}`,
            confidence: face.detectionConfidence!,
            boundingBox: {
              x: boundingPoly[0].x || 0,
              y: boundingPoly[0].y || 0,
              width: (boundingPoly[1].x || 0) - (boundingPoly[0].x || 0),
              height: (boundingPoly[2].y || 0) - (boundingPoly[0].y || 0),
            },
            emotions: {
              joy: face.joyLikelihood === 'VERY_LIKELY' ? 0.9 : 
                   face.joyLikelihood === 'LIKELY' ? 0.7 : 0.3,
              surprise: face.surpriseLikelihood === 'VERY_LIKELY' ? 0.9 : 0.3,
            },
          });
        });
      }

      // Extract dominant color
      let dominantColor = null;
      if (result.imagePropertiesAnnotation?.dominantColors?.colors) {
        const topColor = result.imagePropertiesAnnotation.dominantColors.colors[0];
        dominantColor = rgbToHex(
          topColor.color!.red || 0,
          topColor.color!.green || 0,
          topColor.color!.blue || 0
        );
      }

      // Calculate quality score (based on various factors)
      const qualityScore = calculateQualityScore(result);

      // Update photo with AI data
      await snapshot.ref.update({
        aiLabels,
        aiTags,
        faces: faces.length > 0 ? faces : null,
        dominantColor,
        qualityScore,
        isProcessing: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`AI processing complete for photo ${photoId}`);
      console.log(`Tags: ${aiTags.join(', ')}`);
      console.log(`Faces detected: ${faces.length}`);

    } catch (error) {
      console.error(`Error processing photo ${photoId}:`, error);
      await snapshot.ref.update({
        isProcessing: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return null;
  });

function rgbToHex(r: number, g: number, b: number): string {
  return '#' + [r, g, b].map(x => {
    const hex = Math.round(x).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  }).join('');
}

function calculateQualityScore(result: any): number {
  let score = 1.0;

  // Penalize if blurry (no direct metric, use sharpness heuristic)
  // Penalize if too dark/bright
  // Reward if faces detected with high confidence
  
  if (result.faceAnnotations && result.faceAnnotations.length > 0) {
    const avgFaceConfidence = result.faceAnnotations.reduce(
      (sum: number, face: any) => sum + face.detectionConfidence,
      0
    ) / result.faceAnnotations.length;
    score *= (0.7 + avgFaceConfidence * 0.3); // Boost if clear faces
  }

  return Math.min(score, 1.0);
}
```

### 5.2 Auto-Create Monthly Albums

**File**: `functions/src/photos/createMonthlyAlbums.ts`

```typescript
/**
 * Trigger: When photo is uploaded
 * Action: Auto-add to monthly album
 * Tier: All tiers (automatic organization)
 */
export const addToMonthlyAlbum = functions.firestore
  .document('photos/{photoId}')
  .onCreate(async (snapshot, context) => {
    const photo = snapshot.data();
    
    const capturedDate = photo.capturedAt.toDate();
    const monthKey = `${capturedDate.getFullYear()}-${String(capturedDate.getMonth() + 1).padStart(2, '0')}`;
    const albumTitle = capturedDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

    // Check if monthly album exists
    const albumSnapshot = await admin.firestore()
      .collection('albums')
      .where('babyId', '==', photo.babyId)
      .where('type', '==', 'monthly')
      .where('title', '==', albumTitle)
      .limit(1)
      .get();

    let albumId: string;

    if (albumSnapshot.empty) {
      // Create monthly album
      const newAlbum = {
        babyId: photo.babyId,
        userId: photo.userId,
        title: albumTitle,
        type: 'monthly',
        photoCount: 0,
        videoCount: 0,
        isPrivate: false,
        isPinned: false,
        sortOrder: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isDeleted: false,
      };

      const albumRef = await admin.firestore().collection('albums').add(newAlbum);
      albumId = albumRef.id;
    } else {
      albumId = albumSnapshot.docs[0].id;
    }

    // Add photo to album
    await snapshot.ref.update({
      albumIds: admin.firestore.FieldValue.arrayUnion(albumId),
    });

    // Update album count
    await admin.firestore().collection('albums').doc(albumId).update({
      photoCount: admin.firestore.FieldValue.increment(photo.type === 'video' ? 0 : 1),
      videoCount: admin.firestore.FieldValue.increment(photo.type === 'video' ? 1 : 0),
      lastPhotoDate: photo.capturedAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });
```

---

## 6. UI Components

### 6.1 Photo Grid with Storage Indicator

**File**: `lib/widgets/photo/photo_grid.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';
import '../../services/photo_service.dart';

class PhotoGrid extends StatelessWidget {
  final List<PhotoModel> photos;
  final StorageQuota quota;
  final VoidCallback onUpload;
  final Function(PhotoModel) onPhotoTap;

  const PhotoGrid({
    Key? key,
    required this.photos,
    required this.quota,
    required this.onUpload,
    required this.onPhotoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Storage indicator
        _buildStorageIndicator(context),
        
        // Photo grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: photos.length + 1, // +1 for upload button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildUploadButton(context);
              }
              
              final photo = photos[index - 1];
              return _buildPhotoTile(photo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStorageIndicator(BuildContext context) {
    final percentage = quota.usagePercentage;
    final isNearLimit = percentage > 80;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: isNearLimit ? Colors.orange.shade50 : Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library,
                color: isNearLimit ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quota.maxPhotos == -1
                          ? '${quota.currentPhotos} photos'
                          : '${quota.currentPhotos} / ${quota.maxPhotos} photos',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(quota.currentStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB used',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (quota.maxPhotos != -1 && percentage > 50)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/subscription');
                  },
                  child: const Text('Upgrade'),
                ),
            ],
          ),
          if (quota.maxPhotos != -1) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? Colors.orange : Colors.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadButton(BuildContext context) {
    final canUpload = quota.canUploadPhoto;
    
    return GestureDetector(
      onTap: canUpload ? onUpload : () {
        _showUpgradeDialog(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: canUpload ? Colors.blue.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canUpload ? Colors.blue : Colors.grey,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canUpload ? Icons.add_photo_alternate : Icons.lock,
              size: 32,
              color: canUpload ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              canUpload ? 'Upload' : 'Limit',
              style: TextStyle(
                fontSize: 12,
                color: canUpload ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(PhotoModel photo) {
    return GestureDetector(
      onTap: () => onPhotoTap(photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo.thumbnailUrl ?? photo.url,
              fit: BoxFit.cover,
            ),
          ),
          
          // Video indicator
          if (photo.isVideo)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          
          // Favorite indicator
          if (photo.isFavorite)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.favorite,
                color: Colors.red.shade400,
                size: 20,
              ),
            ),
          
          // AI processing indicator
          if (photo.isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Limit Reached'),
        content: Text(
          'You\'ve reached your photo limit (${quota.maxPhotos}). '
          'Upgrade to Premium for unlimited photos!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}
```

---

## 7. AI Tagging & Search

### 7.1 AI Tag Categories

**Common AI Tags** (Premium users):
- **Emotions**: smile, laugh, happy, sad, crying, surprised
- **Activities**: sleeping, eating, playing, bath, tummy time
- **People**: baby, mother, father, family, siblings
- **Objects**: toy, bottle, pacifier, blanket, crib
- **Scenes**: indoor, outdoor, park, home, hospital
- **Events**: birthday, holiday, milestone, first time

### 7.2 Search Implementation

```dart
/// Advanced AI search (Premium only)
Future<List<PhotoModel>> advancedSearch({
  required String babyId,
  String? searchText, // Search caption, tags
  List<String>? aiTags, // AI-detected tags
  List<String>? albums,
  DateTime? dateFrom,
  DateTime? dateTo,
  bool? hasFaces,
  String? milestoneId,
}) async {
  // Build complex query
  // Combine manual tags, AI tags, captions, dates
  // Return ranked results
}
```

---

## 8. Implementation Roadmap

### Phase 1: Core Upload & Storage (Week 1) - ALL TIERS

**Week 1: Basic Photo Upload**
- [ ] Create `PhotoModel` and `AlbumModel`
- [ ] Implement `PhotoService` upload methods
- [ ] Set up Firebase Storage structure
- [ ] Implement storage quota tracking
- [ ] Build photo upload UI
- [ ] Create photo grid view
- [ ] Implement thumbnail generation

### Phase 2: Album Management (Week 2) - ALL TIERS

**Week 2: Albums & Organization**
- [ ] Build album creation UI
- [ ] Implement album photo assignment
- [ ] Create auto-monthly albums
- [ ] Build album grid view
- [ ] Add drag-and-drop to albums
- [ ] Implement album sharing (basic)

### Phase 3: AI Features (Week 3) - PREMIUM ONLY

**Week 3: AI Tagging & Search**
- [ ] Deploy Vision API Cloud Function
- [ ] Implement AI label detection
- [ ] Add facial recognition
- [ ] Build AI search UI
- [ ] Create smart albums
- [ ] Add color-based search

### Phase 4: Device Integration (Week 4) - PREMIUM + DEVICE

**Week 4: ESP32-CAM Integration**
- [ ] ESP32-CAM photo capture trigger
- [ ] Auto-upload from device to Firebase
- [ ] Milestone-triggered capture
- [ ] Timeline integration with vitals
- [ ] Build device photo management UI

### Phase 5: Advanced Features (Week 5) - PREMIUM

**Week 5: Memory Books & Export**
- [ ] PDF memory book generation
- [ ] High-res photo downloads
- [ ] Shareable album links
- [ ] Photo print ordering integration
- [ ] Timeline with contextual data

---

**Next Steps**:
1. Review and approve Photo Memory System LLD
2. Set up Firebase Storage buckets
3. Configure Google Cloud Vision API
4. Begin Phase 1 implementation
5. Design celebration/memory book templates

