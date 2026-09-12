# Milestone System - Low-Level Design (LLD)

**Document ID**: LLD-MILESTONE-001  
**Version**: 1.0.0  
**Status**: 🟢 Ready for Implementation  
**Last Updated**: February 2, 2026  
**Feature**: Developmental Milestone Tracking with Auto-Detection

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Feature Gating & Subscription Tiers](#feature-gating--subscription-tiers)
3. [Data Models](#data-models)
4. [Service Layer](#service-layer)
5. [Cloud Functions](#cloud-functions)
6. [UI Components](#ui-components)
7. [Auto-Detection Rules](#auto-detection-rules)
8. [Implementation Roadmap](#implementation-roadmap)

---

## 1. Overview

### 1.1 Purpose

The Milestone System tracks developmental progress across multiple domains:
- **Physical** - Rolling over, sitting, crawling, walking
- **Cognitive** - Object permanence, problem-solving, memory
- **Language** - Cooing, babbling, first words, sentences
- **Social** - Smiling, stranger anxiety, playing with others
- **Emotional** - Self-soothing, expressing emotions
- **Feeding** - Solid foods, self-feeding, using utensils
- **Sleep** - Sleeping through night, sleep schedule
- **Other** - Custom parent-defined milestones

### 1.2 Key Features

| Feature | Free Tier | Premium Tier | Device Required |
|---------|-----------|--------------|-----------------|
| Manual milestone logging | ✅ | ✅ | None |
| Photo attachments | ✅ (1 per milestone) | ✅ (Unlimited) | None |
| Basic milestone library (50) | ✅ | ✅ | None |
| Milestone timeline view | ✅ | ✅ | None |
| Age-appropriate suggestions | ❌ | ✅ | None |
| **Auto-detection from data** | ❌ | ✅ | AnvayaPod |
| **AI milestone predictions** | ❌ | ✅ | AnvayaPod |
| **Celebration animations** | ❌ | ✅ | None |
| **Milestone certificates** | ❌ | ✅ | None |
| **CDC percentile comparison** | ❌ | ✅ | None |
| **Export to pediatrician** | ❌ | ✅ | None |
| **Weekly progress reports** | ❌ | ✅ | AnvayaPod |

### 1.3 Device Dependencies

**Without AnvayaPod** (App-Only Mode):
- Manual milestone logging only
- No auto-detection
- Parent must observe and log milestones

**With AnvayaPod** (Premium + Device):
- Auto-detection from sensor data:
  - Sleep milestones (from sleep tracking)
  - Movement milestones (from mmWave motion detection)
  - Feeding milestones (from feeding logs)
  - Vital signs stability
- AI predictions based on patterns
- Weekly automated progress reports

---

## 2. Feature Gating & Subscription Tiers

### 2.1 Subscription Model

```dart
enum SubscriptionTier {
  free,           // Free tier - basic features
  premium,        // Premium subscription - all features
  premiumDevice,  // Premium + AnvayaPod device
}

enum DeviceType {
  none,           // App-only, no device
  anvayaPod,      // Full AnvayaPod with all sensors
}

class FeatureAccess {
  final SubscriptionTier tier;
  final DeviceType deviceType;

  FeatureAccess({
    required this.tier,
    required this.deviceType,
  });

  // Feature checks
  bool get canAutoDetect => tier != SubscriptionTier.free && deviceType == DeviceType.anvayaPod;
  bool get canUseCelebrations => tier != SubscriptionTier.free;
  bool get canExportReports => tier != SubscriptionTier.free;
  bool get canViewPredictions => tier != SubscriptionTier.free && deviceType == DeviceType.anvayaPod;
  bool get canAttachMultiplePhotos => tier != SubscriptionTier.free;
  bool get canViewCDCPercentiles => tier != SubscriptionTier.free;
  
  int get maxPhotosPerMilestone => tier == SubscriptionTier.free ? 1 : 10;
}
```

### 2.2 Feature Gate Implementation

**File**: `lib/services/feature_gate_service.dart`

```dart
import '../models/subscription_model.dart';

class FeatureGateService {
  final SubscriptionTier _currentTier;
  final DeviceType _deviceType;

  FeatureGateService({
    required SubscriptionTier tier,
    required DeviceType deviceType,
  })  : _currentTier = tier,
        _deviceType = deviceType;

  FeatureAccess get access => FeatureAccess(
        tier: _currentTier,
        deviceType: _deviceType,
      );

  /// Check if feature is available, throw upgrade prompt if not
  void requireFeature(String featureName, bool isAvailable) {
    if (!isAvailable) {
      throw FeatureLockedError(
        featureName: featureName,
        requiredTier: SubscriptionTier.premium,
        currentTier: _currentTier,
      );
    }
  }

  /// Get upgrade message for locked feature
  String getUpgradeMessage(String featureName) {
    if (_currentTier == SubscriptionTier.free) {
      return 'Upgrade to Premium to unlock $featureName';
    }
    if (_deviceType == DeviceType.none) {
      return 'Get AnvayaPod device to unlock $featureName';
    }
    return 'This feature is not available';
  }
}

class FeatureLockedError extends Error {
  final String featureName;
  final SubscriptionTier requiredTier;
  final SubscriptionTier currentTier;

  FeatureLockedError({
    required this.featureName,
    required this.requiredTier,
    required this.currentTier,
  });

  @override
  String toString() =>
      'Feature "$featureName" requires ${requiredTier.name} tier. Current: ${currentTier.name}';
}
```

---

## 3. Data Models

### 3.1 Flutter Model: `MilestoneModel`

**File**: `lib/models/milestone_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MilestoneCategory {
  physical,
  cognitive,
  language,
  social,
  emotional,
  feeding,
  sleep,
  other;

  String get displayName {
    switch (this) {
      case MilestoneCategory.physical:
        return 'Physical';
      case MilestoneCategory.cognitive:
        return 'Cognitive';
      case MilestoneCategory.language:
        return 'Language';
      case MilestoneCategory.social:
        return 'Social';
      case MilestoneCategory.emotional:
        return 'Emotional';
      case MilestoneCategory.feeding:
        return 'Feeding';
      case MilestoneCategory.sleep:
        return 'Sleep';
      case MilestoneCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case MilestoneCategory.physical:
        return Icons.directions_run;
      case MilestoneCategory.cognitive:
        return Icons.psychology;
      case MilestoneCategory.language:
        return Icons.chat_bubble;
      case MilestoneCategory.social:
        return Icons.people;
      case MilestoneCategory.emotional:
        return Icons.favorite;
      case MilestoneCategory.feeding:
        return Icons.restaurant;
      case MilestoneCategory.sleep:
        return Icons.bedtime;
      case MilestoneCategory.other:
        return Icons.star;
    }
  }

  Color get color {
    switch (this) {
      case MilestoneCategory.physical:
        return Colors.blue;
      case MilestoneCategory.cognitive:
        return Colors.purple;
      case MilestoneCategory.language:
        return Colors.green;
      case MilestoneCategory.social:
        return Colors.orange;
      case MilestoneCategory.emotional:
        return Colors.pink;
      case MilestoneCategory.feeding:
        return Colors.amber;
      case MilestoneCategory.sleep:
        return Colors.indigo;
      case MilestoneCategory.other:
        return Colors.grey;
    }
  }
}

enum MilestoneSource {
  manual,           // Parent logged manually
  autoDetected,     // Auto-detected from sensor data
  predicted,        // AI predicted (not yet achieved)
  imported,         // Imported from another system
}

class MilestoneModel {
  final String id;
  final String babyId;
  final String userId;
  
  // Milestone info
  final String title; // "First smile", "Rolled over", "First steps"
  final String? description;
  final MilestoneCategory category;
  final MilestoneSource source;
  
  // Timing
  final DateTime achievedAt; // When milestone was achieved
  final int babyAgeInDays; // Age when achieved
  
  // CDC data (for comparison)
  final int? cdcTypicalAgeMonths; // Typical age for this milestone
  final int? cdcEarlyAgeMonths; // Early achievement (25th percentile)
  final int? cdcLateAgeMonths; // Late achievement (75th percentile)
  
  // Media
  final List<String> photoUrls; // Up to 10 photos (1 for free tier)
  final String? videoUrl;
  
  // Auto-detection metadata (if auto-detected)
  final String? detectionRuleId; // Which rule detected it
  final double? confidenceScore; // 0-1, how confident the detection was
  final Map<String, dynamic>? detectionMetadata; // Additional context
  
  // Celebration
  final bool wasCelebrated; // Has celebration animation played
  final DateTime? celebratedAt;
  
  // Notes
  final String? notes; // Parent's notes about the milestone
  final List<String>? tags; // Custom tags
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  MilestoneModel({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.source,
    required this.achievedAt,
    required this.babyAgeInDays,
    this.cdcTypicalAgeMonths,
    this.cdcEarlyAgeMonths,
    this.cdcLateAgeMonths,
    this.photoUrls = const [],
    this.videoUrl,
    this.detectionRuleId,
    this.confidenceScore,
    this.detectionMetadata,
    this.wasCelebrated = false,
    this.celebratedAt,
    this.notes,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  // Computed properties
  bool get isAutoDetected => source == MilestoneSource.autoDetected;
  bool get isPredicted => source == MilestoneSource.predicted;
  bool get isManual => source == MilestoneSource.manual;
  
  int get babyAgeInMonths => (babyAgeInDays / 30.44).floor();
  
  String get ageAchievedDisplay {
    if (babyAgeInDays < 30) {
      return '$babyAgeInDays days';
    } else if (babyAgeInMonths < 12) {
      return '$babyAgeInMonths months';
    } else {
      final years = babyAgeInMonths ~/ 12;
      final months = babyAgeInMonths % 12;
      if (months == 0) {
        return '$years ${years == 1 ? 'year' : 'years'}';
      }
      return '$years yr $months mo';
    }
  }

  /// Check if milestone was achieved early, typical, or late
  String? get achievementTiming {
    if (cdcTypicalAgeMonths == null) return null;
    
    if (babyAgeInMonths < (cdcEarlyAgeMonths ?? cdcTypicalAgeMonths!)) {
      return 'early'; // Before 25th percentile
    } else if (babyAgeInMonths > (cdcLateAgeMonths ?? cdcTypicalAgeMonths!)) {
      return 'late'; // After 75th percentile
    } else {
      return 'typical'; // Within normal range
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category.name,
      'source': source.name,
      'achievedAt': Timestamp.fromDate(achievedAt),
      'babyAgeInDays': babyAgeInDays,
      'cdcTypicalAgeMonths': cdcTypicalAgeMonths,
      'cdcEarlyAgeMonths': cdcEarlyAgeMonths,
      'cdcLateAgeMonths': cdcLateAgeMonths,
      'photoUrls': photoUrls,
      'videoUrl': videoUrl,
      'detectionRuleId': detectionRuleId,
      'confidenceScore': confidenceScore,
      'detectionMetadata': detectionMetadata,
      'wasCelebrated': wasCelebrated,
      'celebratedAt': celebratedAt != null ? Timestamp.fromDate(celebratedAt!) : null,
      'notes': notes,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
    };
  }

  factory MilestoneModel.fromMap(Map<String, dynamic> map) {
    return MilestoneModel(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: MilestoneCategory.values.firstWhere(
        (e) => e.name == map['category'],
      ),
      source: MilestoneSource.values.firstWhere(
        (e) => e.name == map['source'],
      ),
      achievedAt: (map['achievedAt'] as Timestamp).toDate(),
      babyAgeInDays: map['babyAgeInDays'] as int,
      cdcTypicalAgeMonths: map['cdcTypicalAgeMonths'] as int?,
      cdcEarlyAgeMonths: map['cdcEarlyAgeMonths'] as int?,
      cdcLateAgeMonths: map['cdcLateAgeMonths'] as int?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      videoUrl: map['videoUrl'] as String?,
      detectionRuleId: map['detectionRuleId'] as String?,
      confidenceScore: map['confidenceScore'] as double?,
      detectionMetadata: map['detectionMetadata'] as Map<String, dynamic>?,
      wasCelebrated: map['wasCelebrated'] as bool? ?? false,
      celebratedAt: map['celebratedAt'] != null
          ? (map['celebratedAt'] as Timestamp).toDate()
          : null,
      notes: map['notes'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  factory MilestoneModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneModel.fromMap({...data, 'id': doc.id});
  }

  MilestoneModel copyWith({
    String? id,
    String? babyId,
    String? userId,
    String? title,
    String? description,
    MilestoneCategory? category,
    MilestoneSource? source,
    DateTime? achievedAt,
    int? babyAgeInDays,
    int? cdcTypicalAgeMonths,
    int? cdcEarlyAgeMonths,
    int? cdcLateAgeMonths,
    List<String>? photoUrls,
    String? videoUrl,
    String? detectionRuleId,
    double? confidenceScore,
    Map<String, dynamic>? detectionMetadata,
    bool? wasCelebrated,
    DateTime? celebratedAt,
    String? notes,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return MilestoneModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      source: source ?? this.source,
      achievedAt: achievedAt ?? this.achievedAt,
      babyAgeInDays: babyAgeInDays ?? this.babyAgeInDays,
      cdcTypicalAgeMonths: cdcTypicalAgeMonths ?? this.cdcTypicalAgeMonths,
      cdcEarlyAgeMonths: cdcEarlyAgeMonths ?? this.cdcEarlyAgeMonths,
      cdcLateAgeMonths: cdcLateAgeMonths ?? this.cdcLateAgeMonths,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      detectionRuleId: detectionRuleId ?? this.detectionRuleId,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      detectionMetadata: detectionMetadata ?? this.detectionMetadata,
      wasCelebrated: wasCelebrated ?? this.wasCelebrated,
      celebratedAt: celebratedAt ?? this.celebratedAt,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
```

### 3.2 Flutter Model: `MilestoneDefinition`

**File**: `lib/models/milestone_definition_model.dart`

```dart
/// Predefined milestone definitions from CDC/WHO guidelines
class MilestoneDefinition {
  final String id;
  final String title;
  final String description;
  final MilestoneCategory category;
  
  // Age ranges (in months)
  final int typicalAgeMonths;
  final int earlyAgeMonths; // 25th percentile
  final int lateAgeMonths; // 75th percentile
  
  // Detection rules
  final String? autoDetectionRule; // Rule ID for auto-detection
  final List<String> keywords; // Keywords for manual search
  
  // Display
  final String? iconName;
  final bool isPremiumOnly;

  MilestoneDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.typicalAgeMonths,
    required this.earlyAgeMonths,
    required this.lateAgeMonths,
    this.autoDetectionRule,
    this.keywords = const [],
    this.iconName,
    this.isPremiumOnly = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'typicalAgeMonths': typicalAgeMonths,
      'earlyAgeMonths': earlyAgeMonths,
      'lateAgeMonths': lateAgeMonths,
      'autoDetectionRule': autoDetectionRule,
      'keywords': keywords,
      'iconName': iconName,
      'isPremiumOnly': isPremiumOnly,
    };
  }

  factory MilestoneDefinition.fromMap(Map<String, dynamic> map) {
    return MilestoneDefinition(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: MilestoneCategory.values.firstWhere(
        (e) => e.name == map['category'],
      ),
      typicalAgeMonths: map['typicalAgeMonths'] as int,
      earlyAgeMonths: map['earlyAgeMonths'] as int,
      lateAgeMonths: map['lateAgeMonths'] as int,
      autoDetectionRule: map['autoDetectionRule'] as String?,
      keywords: (map['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      iconName: map['iconName'] as String?,
      isPremiumOnly: map['isPremiumOnly'] as bool? ?? false,
    );
  }
}
```

### 3.3 Firestore Schema

#### Collection: `milestones`

```
milestones/{milestoneId}
├── id: string
├── babyId: string (indexed)
├── userId: string
├── title: string
├── description: string | null
├── category: string ('physical' | 'cognitive' | 'language' | 'social' | 'emotional' | 'feeding' | 'sleep' | 'other')
├── source: string ('manual' | 'autoDetected' | 'predicted' | 'imported')
├── achievedAt: timestamp (indexed)
├── babyAgeInDays: number
├── cdcTypicalAgeMonths: number | null
├── cdcEarlyAgeMonths: number | null
├── cdcLateAgeMonths: number | null
├── photoUrls: array<string>
├── videoUrl: string | null
├── detectionRuleId: string | null
├── confidenceScore: number | null
├── detectionMetadata: object | null
├── wasCelebrated: boolean
├── celebratedAt: timestamp | null
├── notes: string | null
├── tags: array<string> | null
├── createdAt: timestamp
├── updatedAt: timestamp
└── isDeleted: boolean
```

**Firestore Indexes**:
```javascript
{
  collectionGroup: "milestones",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "achievedAt", order: "DESCENDING" }
  ]
},
{
  collectionGroup: "milestones",
  fields: [
    { fieldPath: "babyId", order: "ASCENDING" },
    { fieldPath: "category", order: "ASCENDING" },
    { fieldPath: "achievedAt", order: "DESCENDING" }
  ]
}
```

#### Collection: `milestone_definitions` (Seeded Data)

```
milestone_definitions/{definitionId}
├── id: string
├── title: string
├── description: string
├── category: string
├── typicalAgeMonths: number
├── earlyAgeMonths: number
├── lateAgeMonths: number
├── autoDetectionRule: string | null
├── keywords: array<string>
├── iconName: string | null
└── isPremiumOnly: boolean
```

---

## 4. Service Layer

### 4.1 MilestoneService

**File**: `lib/services/milestone_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/milestone_model.dart';
import '../models/milestone_definition_model.dart';
import '../models/baby_model.dart';
import 'feature_gate_service.dart';

class MilestoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FeatureGateService _featureGate;

  MilestoneService({
    required FeatureGateService featureGate,
  }) : _featureGate = featureGate;

  CollectionReference get _milestonesCollection =>
      _firestore.collection('milestones');

  CollectionReference get _definitionsCollection =>
      _firestore.collection('milestone_definitions');

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Log a milestone manually
  Future<MilestoneModel> logMilestone({
    required String babyId,
    required String userId,
    required String title,
    String? description,
    required MilestoneCategory category,
    required DateTime achievedAt,
    required BabyModel baby, // For age calculation
    List<String>? photoUrls,
    String? videoUrl,
    String? notes,
    List<String>? tags,
    String? definitionId, // If selected from library
  }) async {
    // Validate photo count based on tier
    if (photoUrls != null && photoUrls.length > _featureGate.access.maxPhotosPerMilestone) {
      throw Exception(
        'Free tier allows only 1 photo per milestone. Upgrade to Premium for unlimited photos.',
      );
    }

    final now = DateTime.now();
    final babyAgeInDays = achievedAt.difference(baby.dateOfBirth).inDays;

    // Get CDC data if from definition
    int? cdcTypical, cdcEarly, cdcLate;
    if (definitionId != null) {
      final defDoc = await _definitionsCollection.doc(definitionId).get();
      if (defDoc.exists) {
        final def = MilestoneDefinition.fromMap(defDoc.data() as Map<String, dynamic>);
        cdcTypical = def.typicalAgeMonths;
        cdcEarly = def.earlyAgeMonths;
        cdcLate = def.lateAgeMonths;
      }
    }

    final milestone = MilestoneModel(
      id: '',
      babyId: babyId,
      userId: userId,
      title: title,
      description: description,
      category: category,
      source: MilestoneSource.manual,
      achievedAt: achievedAt,
      babyAgeInDays: babyAgeInDays,
      cdcTypicalAgeMonths: cdcTypical,
      cdcEarlyAgeMonths: cdcEarly,
      cdcLateAgeMonths: cdcLate,
      photoUrls: photoUrls ?? [],
      videoUrl: videoUrl,
      notes: notes,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _milestonesCollection.add(milestone.toMap());

    return milestone.copyWith(id: docRef.id);
  }

  /// Auto-detect milestone from sensor data (Premium + Device only)
  Future<MilestoneModel> autoDetectMilestone({
    required String babyId,
    required String userId,
    required String title,
    required String description,
    required MilestoneCategory category,
    required DateTime achievedAt,
    required BabyModel baby,
    required String detectionRuleId,
    required double confidenceScore,
    Map<String, dynamic>? detectionMetadata,
    int? cdcTypicalAgeMonths,
    int? cdcEarlyAgeMonths,
    int? cdcLateAgeMonths,
  }) async {
    // Check premium + device access
    _featureGate.requireFeature(
      'Auto-detection',
      _featureGate.access.canAutoDetect,
    );

    final now = DateTime.now();
    final babyAgeInDays = achievedAt.difference(baby.dateOfBirth).inDays;

    final milestone = MilestoneModel(
      id: '',
      babyId: babyId,
      userId: userId,
      title: title,
      description: description,
      category: category,
      source: MilestoneSource.autoDetected,
      achievedAt: achievedAt,
      babyAgeInDays: babyAgeInDays,
      cdcTypicalAgeMonths: cdcTypicalAgeMonths,
      cdcEarlyAgeMonths: cdcEarlyAgeMonths,
      cdcLateAgeMonths: cdcLateAgeMonths,
      detectionRuleId: detectionRuleId,
      confidenceScore: confidenceScore,
      detectionMetadata: detectionMetadata,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _milestonesCollection.add(milestone.toMap());

    // Trigger celebration for premium users
    if (_featureGate.access.canUseCelebrations) {
      await _triggerCelebration(docRef.id);
    }

    return milestone.copyWith(id: docRef.id);
  }

  /// Update milestone
  Future<void> updateMilestone({
    required String milestoneId,
    String? title,
    String? description,
    MilestoneCategory? category,
    DateTime? achievedAt,
    List<String>? photoUrls,
    String? videoUrl,
    String? notes,
    List<String>? tags,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category.name;
    if (achievedAt != null) updates['achievedAt'] = Timestamp.fromDate(achievedAt);
    if (photoUrls != null) {
      // Check photo limit
      if (photoUrls.length > _featureGate.access.maxPhotosPerMilestone) {
        throw Exception('Photo limit exceeded for your tier');
      }
      updates['photoUrls'] = photoUrls;
    }
    if (videoUrl != null) updates['videoUrl'] = videoUrl;
    if (notes != null) updates['notes'] = notes;
    if (tags != null) updates['tags'] = tags;

    await _milestonesCollection.doc(milestoneId).update(updates);
  }

  /// Mark milestone as celebrated
  Future<void> markCelebrated(String milestoneId) async {
    await _milestonesCollection.doc(milestoneId).update({
      'wasCelebrated': true,
      'celebratedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete milestone (soft delete)
  Future<void> deleteMilestone(String milestoneId) async {
    await _milestonesCollection.doc(milestoneId).update({
      'isDeleted': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /// Get all milestones for baby
  Future<List<MilestoneModel>> getMilestones({
    required String babyId,
    MilestoneCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _milestonesCollection
        .where('babyId', isEqualTo: babyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('achievedAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (startDate != null) {
      query = query.where('achievedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('achievedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MilestoneModel.fromFirestore(doc))
        .toList();
  }

  /// Stream milestones
  Stream<List<MilestoneModel>> streamMilestones({
    required String babyId,
    MilestoneCategory? category,
  }) {
    Query query = _milestonesCollection
        .where('babyId', isEqualTo: babyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('achievedAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MilestoneModel.fromFirestore(doc)).toList());
  }

  /// Get recent milestones (last 10)
  Future<List<MilestoneModel>> getRecentMilestones(String babyId) async {
    return getMilestones(babyId: babyId, limit: 10);
  }

  /// Get milestones by category
  Future<Map<MilestoneCategory, List<MilestoneModel>>> getMilestonesByCategory(
    String babyId,
  ) async {
    final allMilestones = await getMilestones(babyId: babyId);
    
    final Map<MilestoneCategory, List<MilestoneModel>> grouped = {};
    for (final category in MilestoneCategory.values) {
      grouped[category] = [];
    }

    for (final milestone in allMilestones) {
      grouped[milestone.category]!.add(milestone);
    }

    return grouped;
  }

  // ============================================================================
  // Milestone Definitions (Library)
  // ============================================================================

  /// Get all milestone definitions
  Future<List<MilestoneDefinition>> getMilestoneDefinitions({
    MilestoneCategory? category,
    int? ageMonths, // Get age-appropriate milestones
  }) async {
    Query query = _definitionsCollection;

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    final snapshot = await query.get();
    var definitions = snapshot.docs
        .map((doc) => MilestoneDefinition.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    // Filter by age if provided
    if (ageMonths != null) {
      definitions = definitions.where((def) {
        // Show milestones within ±2 months of baby's age
        return def.typicalAgeMonths >= ageMonths - 2 &&
               def.typicalAgeMonths <= ageMonths + 2;
      }).toList();
    }

    // Filter premium-only definitions for free users
    if (!_featureGate.access.canViewPredictions) {
      definitions = definitions.where((def) => !def.isPremiumOnly).toList();
    }

    return definitions;
  }

  /// Search milestone definitions
  Future<List<MilestoneDefinition>> searchMilestoneDefinitions(String query) async {
    final allDefinitions = await getMilestoneDefinitions();
    
    final lowerQuery = query.toLowerCase();
    return allDefinitions.where((def) {
      return def.title.toLowerCase().contains(lowerQuery) ||
             def.description.toLowerCase().contains(lowerQuery) ||
             def.keywords.any((k) => k.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // ============================================================================
  // Statistics & Insights (Premium Only)
  // ============================================================================

  /// Get milestone statistics
  Future<MilestoneStats> getMilestoneStats(String babyId) async {
    _featureGate.requireFeature(
      'Milestone Statistics',
      _featureGate.access.canViewCDCPercentiles,
    );

    final milestones = await getMilestones(babyId: babyId);
    final byCategory = await getMilestonesByCategory(babyId);

    int earlyCount = 0;
    int typicalCount = 0;
    int lateCount = 0;

    for (final milestone in milestones) {
      final timing = milestone.achievementTiming;
      if (timing == 'early') earlyCount++;
      if (timing == 'typical') typicalCount++;
      if (timing == 'late') lateCount++;
    }

    return MilestoneStats(
      totalMilestones: milestones.length,
      byCategory: byCategory.map((k, v) => MapEntry(k, v.length)),
      earlyCount: earlyCount,
      typicalCount: typicalCount,
      lateCount: lateCount,
      mostRecentDate: milestones.isNotEmpty ? milestones.first.achievedAt : null,
    );
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /// Trigger celebration animation (Premium only)
  Future<void> _triggerCelebration(String milestoneId) async {
    // This will be handled by UI layer
    // Just mark as needing celebration
    await _milestonesCollection.doc(milestoneId).update({
      'needsCelebration': true,
    });
  }
}

/// Milestone statistics model
class MilestoneStats {
  final int totalMilestones;
  final Map<MilestoneCategory, int> byCategory;
  final int earlyCount;
  final int typicalCount;
  final int lateCount;
  final DateTime? mostRecentDate;

  MilestoneStats({
    required this.totalMilestones,
    required this.byCategory,
    required this.earlyCount,
    required this.typicalCount,
    required this.lateCount,
    this.mostRecentDate,
  });
}
```

---

## 5. Cloud Functions

### 5.1 Auto-Detection from Sleep Data

**File**: `functions/src/milestones/detectSleepMilestones.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Trigger: When sleep stats are updated
 * Action: Auto-detect sleep-related milestones
 * Requires: Premium subscription + AnvayaPod device
 */
export const detectSleepMilestones = functions.firestore
  .document('sleep_stats/{babyId}/daily/{dateStr}')
  .onCreate(async (snapshot, context) => {
    const stats = snapshot.data();
    const babyId = context.params.babyId;

    // Check if baby has premium + device
    const babyDoc = await admin.firestore().collection('babies').doc(babyId).get();
    if (!babyDoc.exists) return null;

    const baby = babyDoc.data()!;
    const userDoc = await admin.firestore().collection('users').doc(baby.parentUserId).get();
    if (!userDoc.exists) return null;

    const user = userDoc.data()!;
    if (user.subscriptionTier !== 'premium' && user.subscriptionTier !== 'premiumDevice') {
      return null; // Not premium, skip auto-detection
    }

    if (user.deviceType !== 'anvayaPod') {
      return null; // No device, skip
    }

    const milestones: Array<Promise<any>> = [];

    // Rule 1: First 6-hour sleep
    if (stats.longestNightSleepMinutes >= 360) {
      const exists = await checkMilestoneExists(babyId, 'first_6hr_sleep');
      if (!exists) {
        milestones.push(
          createAutoMilestone({
            babyId,
            userId: baby.parentUserId,
            title: 'First 6-Hour Sleep! 🌙',
            description: 'Baby slept for 6 hours straight for the first time!',
            category: 'sleep',
            achievedAt: new Date(stats.date._seconds * 1000),
            detectionRuleId: 'first_6hr_sleep',
            confidenceScore: 1.0,
            detectionMetadata: {
              sleepDuration: stats.longestNightSleepMinutes,
            },
            cdcTypicalAgeMonths: 3,
            cdcEarlyAgeMonths: 2,
            cdcLateAgeMonths: 6,
          })
        );
      }
    }

    // Rule 2: First 8-hour sleep
    if (stats.longestNightSleepMinutes >= 480) {
      const exists = await checkMilestoneExists(babyId, 'first_8hr_sleep');
      if (!exists) {
        milestones.push(
          createAutoMilestone({
            babyId,
            userId: baby.parentUserId,
            title: 'Sleeping Through the Night! 🎉',
            description: 'Baby slept for 8 hours straight!',
            category: 'sleep',
            achievedAt: new Date(stats.date._seconds * 1000),
            detectionRuleId: 'first_8hr_sleep',
            confidenceScore: 1.0,
            detectionMetadata: {
              sleepDuration: stats.longestNightSleepMinutes,
            },
            cdcTypicalAgeMonths: 4,
            cdcEarlyAgeMonths: 3,
            cdcLateAgeMonths: 8,
          })
        );
      }
    }

    // Rule 3: Consistent sleep schedule (7 days of 90+ sleep score)
    if (stats.dailySleepScore >= 90) {
      const past7Days = await get7DaysSleepScores(babyId, stats.date._seconds * 1000);
      const allHighScores = past7Days.every(s => s.dailySleepScore >= 90);
      
      if (allHighScores) {
        const exists = await checkMilestoneExists(babyId, 'consistent_sleep_schedule');
        if (!exists) {
          milestones.push(
            createAutoMilestone({
              babyId,
              userId: baby.parentUserId,
              title: 'Consistent Sleep Schedule! 📅',
              description: '7 days in a row with excellent sleep quality!',
              category: 'sleep',
              achievedAt: new Date(stats.date._seconds * 1000),
              detectionRuleId: 'consistent_sleep_schedule',
              confidenceScore: 0.95,
              detectionMetadata: {
                avgScore: past7Days.reduce((sum, s) => sum + s.dailySleepScore, 0) / 7,
              },
              cdcTypicalAgeMonths: 6,
              cdcEarlyAgeMonths: 4,
              cdcLateAgeMonths: 12,
            })
          );
        }
      }
    }

    await Promise.all(milestones);
    console.log(`Detected ${milestones.length} sleep milestones for baby ${babyId}`);
    
    return null;
  });

async function checkMilestoneExists(babyId: string, ruleId: string): Promise<boolean> {
  const snapshot = await admin.firestore()
    .collection('milestones')
    .where('babyId', '==', babyId)
    .where('detectionRuleId', '==', ruleId)
    .where('isDeleted', '==', false)
    .limit(1)
    .get();
  
  return !snapshot.empty;
}

async function createAutoMilestone(params: {
  babyId: string;
  userId: string;
  title: string;
  description: string;
  category: string;
  achievedAt: Date;
  detectionRuleId: string;
  confidenceScore: number;
  detectionMetadata: any;
  cdcTypicalAgeMonths: number;
  cdcEarlyAgeMonths: number;
  cdcLateAgeMonths: number;
}): Promise<void> {
  const { babyId, userId, ...rest } = params;
  
  // Calculate baby age
  const babyDoc = await admin.firestore().collection('babies').doc(babyId).get();
  const baby = babyDoc.data()!;
  const babyAgeInDays = Math.floor(
    (params.achievedAt.getTime() - baby.dateOfBirth._seconds * 1000) / (1000 * 60 * 60 * 24)
  );

  await admin.firestore().collection('milestones').add({
    babyId,
    userId,
    ...rest,
    source: 'autoDetected',
    babyAgeInDays,
    photoUrls: [],
    wasCelebrated: false,
    needsCelebration: true, // Trigger celebration in UI
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send notification
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const user = userDoc.data()!;
  
  if (user.fcmToken) {
    await admin.messaging().send({
      token: user.fcmToken,
      notification: {
        title: '🎉 New Milestone Detected!',
        body: params.title,
      },
      data: {
        type: 'milestone_detected',
        babyId,
        title: params.title,
      },
    });
  }
}

async function get7DaysSleepScores(babyId: string, endDateMs: number): Promise<any[]> {
  const endDate = new Date(endDateMs);
  const startDate = new Date(endDateMs - 7 * 24 * 60 * 60 * 1000);
  
  const snapshot = await admin.firestore()
    .collection('sleep_stats')
    .doc(babyId)
    .collection('daily')
    .where('date', '>=', admin.firestore.Timestamp.fromDate(startDate))
    .where('date', '<=', admin.firestore.Timestamp.fromDate(endDate))
    .orderBy('date', 'desc')
    .get();
  
  return snapshot.docs.map(doc => doc.data());
}
```

### 5.2 Auto-Detection from Feeding Data

**File**: `functions/src/milestones/detectFeedingMilestones.ts`

```typescript
/**
 * Trigger: When feeding session is logged
 * Action: Auto-detect feeding milestones
 */
export const detectFeedingMilestones = functions.firestore
  .document('feeding_sessions/{sessionId}')
  .onCreate(async (snapshot, context) => {
    const feeding = snapshot.data();
    const babyId = feeding.babyId;

    // Check premium + device access
    const hasAccess = await checkPremiumDevice(feeding.userId);
    if (!hasAccess) return null;

    const milestones: Array<Promise<any>> = [];

    // Rule 1: First solid food
    if (feeding.feedingType === 'solid' || feeding.foodType === 'solid') {
      const exists = await checkMilestoneExists(babyId, 'first_solid_food');
      if (!exists) {
        milestones.push(
          createAutoMilestone({
            babyId,
            userId: feeding.userId,
            title: 'First Solid Food! 🥄',
            description: 'Baby tried solid food for the first time!',
            category: 'feeding',
            achievedAt: feeding.startTime.toDate(),
            detectionRuleId: 'first_solid_food',
            confidenceScore: 1.0,
            detectionMetadata: {
              foodName: feeding.notes || 'solid food',
            },
            cdcTypicalAgeMonths: 6,
            cdcEarlyAgeMonths: 4,
            cdcLateAgeMonths: 8,
          })
        );
      }
    }

    // Rule 2: Self-feeding (if notes indicate)
    const selfFeedingKeywords = ['self', 'hold', 'grab', 'finger food'];
    if (feeding.notes && selfFeedingKeywords.some(k => feeding.notes.toLowerCase().includes(k))) {
      const exists = await checkMilestoneExists(babyId, 'self_feeding');
      if (!exists) {
        milestones.push(
          createAutoMilestone({
            babyId,
            userId: feeding.userId,
            title: 'Self-Feeding! 🙌',
            description: 'Baby is feeding themselves!',
            category: 'feeding',
            achievedAt: feeding.startTime.toDate(),
            detectionRuleId: 'self_feeding',
            confidenceScore: 0.8,
            detectionMetadata: {
              notes: feeding.notes,
            },
            cdcTypicalAgeMonths: 9,
            cdcEarlyAgeMonths: 7,
            cdcLateAgeMonths: 12,
          })
        );
      }
    }

    await Promise.all(milestones);
    return null;
  });
```

---

## 6. UI Components

### 6.1 Milestone Card with Feature Gating

**File**: `lib/widgets/milestone/milestone_card.dart`

```dart
import 'package:flutter/material.dart';
import '../../models/milestone_model.dart';
import '../../services/feature_gate_service.dart';

class MilestoneCard extends StatelessWidget {
  final MilestoneModel milestone;
  final FeatureAccess featureAccess;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MilestoneCard({
    Key? key,
    required this.milestone,
    required this.featureAccess,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: milestone.category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      milestone.category.icon,
                      color: milestone.category.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Title and age
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                milestone.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Auto-detect badge (Premium only)
                            if (milestone.isAutoDetected && featureAccess.canAutoDetect)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.purple.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 12,
                                      color: Colors.purple.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Auto',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'At ${milestone.ageAchievedDisplay}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Delete button
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      color: Colors.grey,
                    ),
                ],
              ),
              
              // Description
              if (milestone.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  milestone.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              
              // CDC comparison (Premium only)
              if (featureAccess.canViewCDCPercentiles &&
                  milestone.achievementTiming != null) ...[
                const SizedBox(height: 12),
                _buildCDCComparison(milestone.achievementTiming!),
              ],
              
              // Photos
              if (milestone.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: milestone.photoUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(milestone.photoUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // Notes
              if (milestone.notes != null && milestone.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    milestone.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCDCComparison(String timing) {
    Color color;
    IconData icon;
    String label;

    switch (timing) {
      case 'early':
        color = Colors.green;
        icon = Icons.trending_up;
        label = 'Early (ahead of schedule)';
        break;
      case 'late':
        color = Colors.orange;
        icon = Icons.trending_down;
        label = 'Later than typical';
        break;
      default:
        color = Colors.blue;
        icon = Icons.check_circle;
        label = 'On schedule';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 6.2 Premium Upsell Dialog

**File**: `lib/widgets/milestone/premium_upsell_dialog.dart`

```dart
import 'package:flutter/material.dart';

class PremiumUpsellDialog extends StatelessWidget {
  final String featureName;
  final bool needsDevice;

  const PremiumUpsellDialog({
    Key? key,
    required this.featureName,
    this.needsDevice = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 320,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Premium Feature',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    featureName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Features list
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (needsDevice)
                    _buildFeatureItem(
                      Icons.sensors,
                      'Auto-detect milestones',
                      'With AnvayaPod device',
                    )
                  else
                    _buildFeatureItem(
                      Icons.auto_awesome,
                      'Unlock $featureName',
                      'Available with Premium',
                    ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.celebration,
                    'Celebration animations',
                    'Make memories special',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.analytics,
                    'CDC percentile tracking',
                    'Compare development',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.photo_library,
                    'Unlimited photos',
                    'Capture every moment',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Maybe Later'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to subscription screen
                            Navigator.pushNamed(context, '/subscription');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Upgrade Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

---

## 7. Auto-Detection Rules

### 7.1 Sleep Milestones

| Rule ID | Title | Trigger | Confidence | CDC Age |
|---------|-------|---------|------------|---------|
| `first_6hr_sleep` | First 6-Hour Sleep | Longest night sleep ≥ 360 min | 1.0 | 3 mo |
| `first_8hr_sleep` | Sleeping Through Night | Longest night sleep ≥ 480 min | 1.0 | 4 mo |
| `consistent_schedule` | Consistent Sleep | 7 days with sleep score ≥ 90 | 0.95 | 6 mo |
| `reduced_night_waking` | Fewer Night Wakings | < 2 interruptions for 3 nights | 0.9 | 6 mo |

### 7.2 Feeding Milestones

| Rule ID | Title | Trigger | Confidence | CDC Age |
|---------|-------|---------|------------|---------|
| `first_solid_food` | First Solid Food | feeding.type === 'solid' | 1.0 | 6 mo |
| `self_feeding` | Self-Feeding | Keywords in notes | 0.8 | 9 mo |
| `three_meals_daily` | Regular Meal Pattern | 3+ solid feeds/day for 3 days | 0.9 | 8 mo |
| `sippy_cup` | Using Sippy Cup | Keywords: 'cup', 'sippy' | 0.85 | 12 mo |

### 7.3 Growth Milestones

| Rule ID | Title | Trigger | Confidence | CDC Age |
|---------|-------|---------|------------|---------|
| `doubled_birth_weight` | Doubled Birth Weight | Weight ≥ 2× birth weight | 1.0 | 5 mo |
| `tripled_birth_weight` | Tripled Birth Weight | Weight ≥ 3× birth weight | 1.0 | 12 mo |
| `growth_spurt` | Growth Spurt | Weight gain > 200g in 1 week | 0.85 | Varies |

### 7.4 Physical Milestones (Future - with mmWave motion)

| Rule ID | Title | Trigger | Confidence | CDC Age |
|---------|-------|---------|------------|---------|
| `rolling_over` | Rolling Over | Motion pattern detected | 0.75 | 4 mo |
| `sitting_unsupported` | Sitting Up | Posture pattern | 0.7 | 6 mo |
| `crawling` | Crawling Detected | Movement pattern | 0.8 | 8 mo |

---

## 8. Implementation Roadmap

### Phase 1: Core Manual Tracking (Week 1-2) - FREE TIER

**Week 1: Data Layer**
- [ ] Create `MilestoneModel` with all enums
- [ ] Create `MilestoneDefinition` model
- [ ] Implement `MilestoneService` CRUD (manual logging only)
- [ ] Seed Firestore with 50 milestone definitions
- [ ] Write unit tests for models and service
- [ ] Set up Firestore collections and indexes

**Week 2: UI - Basic**
- [ ] Build `MilestoneCard` widget (free tier view)
- [ ] Create "Add Milestone" form (manual)
- [ ] Build milestone timeline screen
- [ ] Implement category filtering
- [ ] Add single photo attachment (free tier limit)

### Phase 2: Premium Features (Week 3) - PREMIUM TIER

**Week 3: Feature Gating & Premium UI**
- [ ] Implement `FeatureGateService`
- [ ] Build `PremiumUpsellDialog`
- [ ] Add CDC percentile comparison UI
- [ ] Implement celebration animations (Lottie/Rive)
- [ ] Enable unlimited photo attachments
- [ ] Build milestone certificates (PDF generation)

### Phase 3: Auto-Detection (Week 4) - PREMIUM + DEVICE

**Week 4: Cloud Functions**
- [ ] Deploy `detectSleepMilestones` Cloud Function
- [ ] Deploy `detectFeedingMilestones` Cloud Function
- [ ] Deploy `detectGrowthMilestones` Cloud Function
- [ ] Implement auto-detection from sensor data
- [ ] Add FCM notifications for detected milestones
- [ ] Build confidence scoring system

### Phase 4: Analytics & Insights (Week 5) - PREMIUM

**Week 5: Advanced Features**
- [ ] Build milestone statistics dashboard
- [ ] Implement developmental progress charts
- [ ] Create weekly progress reports
- [ ] Add export to PDF for pediatrician
- [ ] Build AI prediction model (future milestones)

---

## 9. Success Metrics

| Metric | Free Tier Target | Premium Target | Measurement |
|--------|------------------|----------------|-------------|
| Milestone Logging Rate | 2 per month | 5 per month | Avg milestones/user/month |
| Auto-Detection Accuracy | N/A | >85% | Confirmed vs total detected |
| Premium Conversion | 15% | N/A | Free → Premium upgrade rate |
| Device Attach Rate | N/A | 40% | Premium users with device |
| Celebration View Rate | N/A | >90% | Users who watch animations |
| CDC Comparison Usage | N/A | >70% | Premium users viewing percentiles |

---

**Next Steps**:
1. Review and approve this LLD with feature gating
2. Set up subscription tier system (Free/Premium/Premium+Device)
3. Begin Phase 1 implementation (Free tier manual logging)
4. Create celebration animations assets
5. Build auto-detection rules engine

