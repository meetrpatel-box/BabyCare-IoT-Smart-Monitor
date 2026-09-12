# 🍼 Feeding Tracking - Low-Level Design

**Date:** February 2, 2026  
**Feature:** Manual Feeding Tracking (Breast, Bottle, Solids)  
**Type:** App-based Manual Entry (No Device Sensors)

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Data Models](#data-models)
3. [Cloud Functions](#cloud-functions)
4. [Flutter Implementation](#flutter-implementation)
5. [Analytics & Insights](#analytics--insights)
6. [Implementation Roadmap](#implementation-roadmap)

---

## 1️⃣ SYSTEM OVERVIEW

### **1.1 Feature Scope**

| Feature | Description | Age Range |
|---------|-------------|-----------|
| **Breastfeeding Timer** | Track left/right breast, duration | 0-12+ months |
| **Bottle Feeding** | Record amount (ml/oz), formula type | 0-12+ months |
| **Solid Food** | Log food type, texture, portion | 6+ months |
| **Feeding Schedule** | Auto-detect patterns, predict next feeding | All ages |
| **Feeding Insights** | Cluster feeding, growth spurts, trends | All ages |
| **Export Reports** | Daily/weekly summaries for pediatrician | All ages |

### **1.2 Data Flow Architecture**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          FEEDING TRACKING FLOW                           │
└─────────────────────────────────────────────────────────────────────────┘

Flutter App                    Firebase Cloud              Analytics
┌────────────────┐            ┌──────────────────┐         ┌─────────────┐
│                │            │                  │         │             │
│  Quick Log UI  │            │  Cloud Function  │         │  Insights   │
│  ────────────  │   Write    │  ──────────────  │ Trigger │  ─────────  │
│                │  Firestore │                  │ ──────> │             │
│  Breast Timer  │ ────────> │  onFeedingCreate │         │  Pattern    │
│  - Left: 8min  │            │  - Validate      │         │  Detection  │
│  - Right: 7min │            │  - Calculate     │         │  - Cluster  │
│  [Save]        │            │  - Update stats  │         │  - Regular  │
│                │            │                  │         │  - Demand   │
│  Bottle Log    │            │  Daily Stats     │         │             │
│  - Amount: 120 │            │  ──────────────  │         │  Predict    │
│  - Type: Formula│           │  Total ml/day    │         │  Next Feed  │
│  [Save]        │            │  Feed count      │         │  - Based on │
│                │            │  Avg interval    │         │    history  │
│  Solid Food    │            │                  │         │             │
│  - Food: Banana│            │  Weekly Trend    │         │  Growth     │
│  - Portion: 2oz│            │  ──────────────  │         │  Spurt      │
│  [Save]        │            │  Chart data      │         │  Detection  │
│                │            │  Comparisons     │         │             │
│  History       │   Read     │                  │         │  Alerts     │
│  ────────────  │  Firestore │  Firestore       │         │  ─────────  │
│  Timeline      │ <───────── │  /feedings       │         │  - Long gap │
│  - Today: 8    │            │  /daily_stats    │         │  - Low intake│
│  - Chart       │            │  /insights       │         │             │
└────────────────┘            └──────────────────┘         └─────────────┘
```

### **1.3 Storage Strategy**

```
Firestore Collections:
├─ babies/{babyId}/feedings/{feedingId}           (Individual feeding records)
├─ babies/{babyId}/feeding_stats/daily/{date}     (Daily aggregates)
├─ babies/{babyId}/feeding_stats/weekly/{week}    (Weekly summaries)
├─ babies/{babyId}/feeding_insights/{date}        (AI-detected patterns)
└─ babies/{babyId}/feeding_reminders/{reminderId} (Scheduled reminders)

Data Retention:
- Individual feedings: Permanent
- Daily stats: Permanent
- Weekly stats: Permanent
- Insights: 90 days
```

---

## 2️⃣ DATA MODELS

### **2.1 Firestore Schema**

```typescript
// ═══════════════════════════════════════════════════════════
// Firestore Document Schemas
// ═══════════════════════════════════════════════════════════

// Collection: babies/{babyId}/feedings/{feedingId}
interface FeedingDocument {
  id: string;
  babyId: string;
  
  // Feeding type
  type: 'breast' | 'bottle' | 'solids' | 'mixed';
  
  // Timing
  startTime: FirebaseFirestore.Timestamp;
  endTime?: FirebaseFirestore.Timestamp;
  duration?: number;  // seconds
  
  // Breastfeeding specific
  breastfeeding?: {
    leftDuration: number;   // seconds
    rightDuration: number;  // seconds
    startSide: 'left' | 'right';
    endSide: 'left' | 'right';
    switchCount: number;
  };
  
  // Bottle feeding specific
  bottleFeeding?: {
    amountMl: number;
    amountOz: number;
    feedingType: 'breast_milk' | 'formula' | 'mixed';
    formulaBrand?: string;
    temperature?: 'cold' | 'room_temp' | 'warm';
  };
  
  // Solid food specific
  solidFood?: {
    foods: Array<{
      name: string;
      category: 'fruit' | 'vegetable' | 'grain' | 'protein' | 'dairy' | 'other';
      portionOz?: number;
      portionGrams?: number;
      texture: 'puree' | 'mashed' | 'soft_chunks' | 'finger_food';
    }>;
    waterMl?: number;
    selfFed: boolean;
  };
  
  // Context
  location?: 'home' | 'outside' | 'daycare' | 'other';
  mood?: 'hungry' | 'content' | 'fussy' | 'sleepy';
  
  // Completion status
  completed: boolean;
  completionReason?: 'full' | 'refused' | 'distracted' | 'fell_asleep';
  
  // Notes
  notes?: string;
  
  // Logged by
  loggedBy: string;  // userId
  loggedAt: FirebaseFirestore.Timestamp;
  
  // Metadata
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/feeding_stats/daily/{date}
interface DailyFeedingStats {
  babyId: string;
  date: string;  // YYYY-MM-DD
  
  // Counts
  totalFeedings: number;
  breastFeedingCount: number;
  bottleFeedingCount: number;
  solidFoodCount: number;
  
  // Breastfeeding totals
  breastfeeding: {
    totalDuration: number;  // seconds
    leftDuration: number;
    rightDuration: number;
    averagePerFeed: number;
    longestGap: number;     // seconds between feedings
  };
  
  // Bottle totals
  bottleFeeding: {
    totalMl: number;
    totalOz: number;
    averageMl: number;
    largestFeed: number;
    smallestFeed: number;
  };
  
  // Solid food
  solidFood: {
    mealCount: number;
    uniqueFoods: string[];
    totalPortionOz: number;
  };
  
  // Timing patterns
  feedingIntervals: number[];  // seconds between each feeding
  averageInterval: number;
  shortestInterval: number;
  longestInterval: number;
  
  // Time distribution (hour of day)
  hourlyDistribution: Record<string, number>;  // {"0": 2, "3": 1, "6": 2, ...}
  
  // Detected patterns
  patterns: ('cluster_feeding' | 'regular_schedule' | 'demand_feeding' | 'growth_spurt')[];
  
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/feeding_insights/{date}
interface FeedingInsight {
  babyId: string;
  date: string;
  
  // Insight type
  type: 'pattern_detected' | 'milestone' | 'recommendation' | 'alert';
  category: 'breastfeeding' | 'bottle' | 'solids' | 'general';
  
  // Content
  title: string;
  message: string;
  severity: 'info' | 'tip' | 'warning' | 'success';
  
  // Data backing the insight
  data?: {
    avgInterval?: number;
    totalIntake?: number;
    comparison?: {
      today: number;
      yesterday: number;
      percentChange: number;
    };
  };
  
  // Actions
  actionRequired: boolean;
  actionText?: string;  // e.g., "Consult pediatrician if continues"
  
  // User interaction
  isDismissed: boolean;
  dismissedAt?: FirebaseFirestore.Timestamp;
  
  createdAt: FirebaseFirestore.Timestamp;
}
```

### **2.2 Flutter Dart Models**

```dart
// ═══════════════════════════════════════════════════════════
// lib/models/feeding_model.dart
// ═══════════════════════════════════════════════════════════

enum FeedingType { breast, bottle, solids, mixed }

enum FeedingSide { left, right }

enum BottleFeedingType { breastMilk, formula, mixed }

enum FoodTexture { puree, mashed, softChunks, fingerFood }

enum FoodCategory { fruit, vegetable, grain, protein, dairy, other }

class FeedingModel {
  final String id;
  final String babyId;
  final FeedingType type;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  
  // Type-specific data
  final BreastfeedingData? breastfeeding;
  final BottleFeedingData? bottleFeeding;
  final SolidFoodData? solidFood;
  
  // Context
  final String? location;
  final String? mood;
  final bool completed;
  final String? completionReason;
  final String? notes;
  
  // Metadata
  final String loggedBy;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  FeedingModel({
    required this.id,
    required this.babyId,
    required this.type,
    required this.startTime,
    this.endTime,
    this.duration,
    this.breastfeeding,
    this.bottleFeeding,
    this.solidFood,
    this.location,
    this.mood,
    required this.completed,
    this.completionReason,
    this.notes,
    required this.loggedBy,
    required this.loggedAt,
    required this.createdAt,
    this.updatedAt,
  });
  
  // Computed properties
  bool get isBreastfeeding => type == FeedingType.breast;
  bool get isBottleFeeding => type == FeedingType.bottle;
  bool get isSolidFood => type == FeedingType.solids;
  bool get isInProgress => endTime == null && !completed;
  
  String get displayType {
    switch (type) {
      case FeedingType.breast:
        return 'Breastfeeding';
      case FeedingType.bottle:
        return 'Bottle';
      case FeedingType.solids:
        return 'Solid Food';
      case FeedingType.mixed:
        return 'Mixed';
    }
  }
  
  String get durationText {
    if (duration == null) return '--';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
  
  factory FeedingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FeedingModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      type: FeedingType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => FeedingType.breast,
      ),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null 
          ? (data['endTime'] as Timestamp).toDate() 
          : null,
      duration: data['duration'] != null 
          ? Duration(seconds: data['duration']) 
          : null,
      breastfeeding: data['breastfeeding'] != null
          ? BreastfeedingData.fromMap(data['breastfeeding'])
          : null,
      bottleFeeding: data['bottleFeeding'] != null
          ? BottleFeedingData.fromMap(data['bottleFeeding'])
          : null,
      solidFood: data['solidFood'] != null
          ? SolidFoodData.fromMap(data['solidFood'])
          : null,
      location: data['location'],
      mood: data['mood'],
      completed: data['completed'] ?? false,
      completionReason: data['completionReason'],
      notes: data['notes'],
      loggedBy: data['loggedBy'] ?? '',
      loggedAt: (data['loggedAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'babyId': babyId,
      'type': type.name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration?.inSeconds,
      'breastfeeding': breastfeeding?.toMap(),
      'bottleFeeding': bottleFeeding?.toMap(),
      'solidFood': solidFood?.toMap(),
      'location': location,
      'mood': mood,
      'completed': completed,
      'completionReason': completionReason,
      'notes': notes,
      'loggedBy': loggedBy,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Breastfeeding Data
// ═══════════════════════════════════════════════════════════

class BreastfeedingData {
  final Duration leftDuration;
  final Duration rightDuration;
  final FeedingSide startSide;
  final FeedingSide endSide;
  final int switchCount;
  
  BreastfeedingData({
    required this.leftDuration,
    required this.rightDuration,
    required this.startSide,
    required this.endSide,
    required this.switchCount,
  });
  
  Duration get totalDuration => leftDuration + rightDuration;
  
  String get summary {
    final left = leftDuration.inMinutes;
    final right = rightDuration.inMinutes;
    return 'L: ${left}m, R: ${right}m';
  }
  
  factory BreastfeedingData.fromMap(Map<String, dynamic> map) {
    return BreastfeedingData(
      leftDuration: Duration(seconds: map['leftDuration'] ?? 0),
      rightDuration: Duration(seconds: map['rightDuration'] ?? 0),
      startSide: map['startSide'] == 'left' ? FeedingSide.left : FeedingSide.right,
      endSide: map['endSide'] == 'left' ? FeedingSide.left : FeedingSide.right,
      switchCount: map['switchCount'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'leftDuration': leftDuration.inSeconds,
      'rightDuration': rightDuration.inSeconds,
      'startSide': startSide.name,
      'endSide': endSide.name,
      'switchCount': switchCount,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Bottle Feeding Data
// ═══════════════════════════════════════════════════════════

class BottleFeedingData {
  final double amountMl;
  final double amountOz;
  final BottleFeedingType feedingType;
  final String? formulaBrand;
  final String? temperature;
  
  BottleFeedingData({
    required this.amountMl,
    required this.amountOz,
    required this.feedingType,
    this.formulaBrand,
    this.temperature,
  });
  
  String get displayAmount => '${amountMl.toInt()} ml / ${amountOz.toStringAsFixed(1)} oz';
  
  factory BottleFeedingData.fromMap(Map<String, dynamic> map) {
    return BottleFeedingData(
      amountMl: (map['amountMl'] ?? 0).toDouble(),
      amountOz: (map['amountOz'] ?? 0).toDouble(),
      feedingType: BottleFeedingType.values.firstWhere(
        (e) => e.name == map['feedingType'],
        orElse: () => BottleFeedingType.formula,
      ),
      formulaBrand: map['formulaBrand'],
      temperature: map['temperature'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'amountMl': amountMl,
      'amountOz': amountOz,
      'feedingType': feedingType.name,
      'formulaBrand': formulaBrand,
      'temperature': temperature,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Solid Food Data
// ═══════════════════════════════════════════════════════════

class SolidFoodData {
  final List<FoodItem> foods;
  final double? waterMl;
  final bool selfFed;
  
  SolidFoodData({
    required this.foods,
    this.waterMl,
    required this.selfFed,
  });
  
  String get foodList => foods.map((f) => f.name).join(', ');
  
  factory SolidFoodData.fromMap(Map<String, dynamic> map) {
    final foodsList = (map['foods'] as List?)?.map((f) => FoodItem.fromMap(f)).toList() ?? [];
    
    return SolidFoodData(
      foods: foodsList,
      waterMl: map['waterMl']?.toDouble(),
      selfFed: map['selfFed'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'foods': foods.map((f) => f.toMap()).toList(),
      'waterMl': waterMl,
      'selfFed': selfFed,
    };
  }
}

class FoodItem {
  final String name;
  final FoodCategory category;
  final double? portionOz;
  final double? portionGrams;
  final FoodTexture texture;
  
  FoodItem({
    required this.name,
    required this.category,
    this.portionOz,
    this.portionGrams,
    required this.texture,
  });
  
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'] ?? '',
      category: FoodCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => FoodCategory.other,
      ),
      portionOz: map['portionOz']?.toDouble(),
      portionGrams: map['portionGrams']?.toDouble(),
      texture: FoodTexture.values.firstWhere(
        (e) => e.name == map['texture'],
        orElse: () => FoodTexture.puree,
      ),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'portionOz': portionOz,
      'portionGrams': portionGrams,
      'texture': texture.name,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Daily Stats Model
// ═══════════════════════════════════════════════════════════

class DailyFeedingStats {
  final String babyId;
  final String date;
  final int totalFeedings;
  final int breastFeedingCount;
  final int bottleFeedingCount;
  final int solidFoodCount;
  
  final BreastfeedingStats? breastfeeding;
  final BottleFeedingStats? bottleFeeding;
  final SolidFoodStats? solidFood;
  
  final Duration averageInterval;
  final List<String> patterns;
  
  DailyFeedingStats({
    required this.babyId,
    required this.date,
    required this.totalFeedings,
    required this.breastFeedingCount,
    required this.bottleFeedingCount,
    required this.solidFoodCount,
    this.breastfeeding,
    this.bottleFeeding,
    this.solidFood,
    required this.averageInterval,
    required this.patterns,
  });
  
  bool get hasClusterFeeding => patterns.contains('cluster_feeding');
  bool get hasRegularSchedule => patterns.contains('regular_schedule');
  
  factory DailyFeedingStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DailyFeedingStats(
      babyId: data['babyId'] ?? '',
      date: data['date'] ?? '',
      totalFeedings: data['totalFeedings'] ?? 0,
      breastFeedingCount: data['breastFeedingCount'] ?? 0,
      bottleFeedingCount: data['bottleFeedingCount'] ?? 0,
      solidFoodCount: data['solidFoodCount'] ?? 0,
      breastfeeding: data['breastfeeding'] != null
          ? BreastfeedingStats.fromMap(data['breastfeeding'])
          : null,
      bottleFeeding: data['bottleFeeding'] != null
          ? BottleFeedingStats.fromMap(data['bottleFeeding'])
          : null,
      solidFood: data['solidFood'] != null
          ? SolidFoodStats.fromMap(data['solidFood'])
          : null,
      averageInterval: Duration(seconds: data['averageInterval'] ?? 0),
      patterns: List<String>.from(data['patterns'] ?? []),
    );
  }
}

class BreastfeedingStats {
  final Duration totalDuration;
  final Duration leftDuration;
  final Duration rightDuration;
  final Duration averagePerFeed;
  
  BreastfeedingStats({
    required this.totalDuration,
    required this.leftDuration,
    required this.rightDuration,
    required this.averagePerFeed,
  });
  
  factory BreastfeedingStats.fromMap(Map<String, dynamic> map) {
    return BreastfeedingStats(
      totalDuration: Duration(seconds: map['totalDuration'] ?? 0),
      leftDuration: Duration(seconds: map['leftDuration'] ?? 0),
      rightDuration: Duration(seconds: map['rightDuration'] ?? 0),
      averagePerFeed: Duration(seconds: map['averagePerFeed'] ?? 0),
    );
  }
}

class BottleFeedingStats {
  final double totalMl;
  final double totalOz;
  final double averageMl;
  
  BottleFeedingStats({
    required this.totalMl,
    required this.totalOz,
    required this.averageMl,
  });
  
  factory BottleFeedingStats.fromMap(Map<String, dynamic> map) {
    return BottleFeedingStats(
      totalMl: (map['totalMl'] ?? 0).toDouble(),
      totalOz: (map['totalOz'] ?? 0).toDouble(),
      averageMl: (map['averageMl'] ?? 0).toDouble(),
    );
  }
}

class SolidFoodStats {
  final int mealCount;
  final List<String> uniqueFoods;
  final double totalPortionOz;
  
  SolidFoodStats({
    required this.mealCount,
    required this.uniqueFoods,
    required this.totalPortionOz,
  });
  
  factory SolidFoodStats.fromMap(Map<String, dynamic> map) {
    return SolidFoodStats(
      mealCount: map['mealCount'] ?? 0,
      uniqueFoods: List<String>.from(map['uniqueFoods'] ?? []),
      totalPortionOz: (map['totalPortionOz'] ?? 0).toDouble(),
    );
  }
}
```

---

## 3️⃣ CLOUD FUNCTIONS

### **3.1 On Feeding Create - Auto Analytics**

```typescript
// ═══════════════════════════════════════════════════════════
// functions/src/onFeedingCreate.ts
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export const onFeedingCreate = functions.firestore
  .document('babies/{babyId}/feedings/{feedingId}')
  .onCreate(async (snap, context) => {
    
    const feeding = snap.data();
    const { babyId } = context.params;
    
    console.log(`[onFeedingCreate] Baby: ${babyId}, Type: ${feeding.type}`);
    
    try {
      // Update daily stats
      await updateDailyStats(babyId, feeding);
      
      // Check for patterns
      await detectFeedingPatterns(babyId, feeding);
      
      // Generate insights
      await generateInsights(babyId);
      
      // Check for alerts (long gaps, low intake)
      await checkFeedingAlerts(babyId, feeding);
      
    } catch (error) {
      console.error('[onFeedingCreate] Error:', error);
    }
  });

// ═══════════════════════════════════════════════════════════
// Update Daily Stats
// ═══════════════════════════════════════════════════════════

async function updateDailyStats(babyId: string, feeding: any): Promise<void> {
  const date = new Date(feeding.startTime.toDate()).toISOString().split('T')[0];
  const statsRef = db
    .collection('babies')
    .doc(babyId)
    .collection('feeding_stats')
    .doc('daily')
    .collection('data')
    .doc(date);
  
  await db.runTransaction(async (t) => {
    const doc = await t.get(statsRef);
    
    if (!doc.exists) {
      // Initialize new day
      t.set(statsRef, {
        babyId,
        date,
        totalFeedings: 1,
        breastFeedingCount: feeding.type === 'breast' ? 1 : 0,
        bottleFeedingCount: feeding.type === 'bottle' ? 1 : 0,
        solidFoodCount: feeding.type === 'solids' ? 1 : 0,
        breastfeeding: feeding.breastfeeding || null,
        bottleFeeding: feeding.bottleFeeding ? {
          totalMl: feeding.bottleFeeding.amountMl,
          totalOz: feeding.bottleFeeding.amountOz,
          averageMl: feeding.bottleFeeding.amountMl,
          count: 1,
        } : null,
        feedingIntervals: [],
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
    } else {
      // Update existing
      const existing = doc.data()!;
      
      const updates: any = {
        totalFeedings: existing.totalFeedings + 1,
        updatedAt: admin.firestore.Timestamp.now(),
      };
      
      if (feeding.type === 'breast') {
        updates.breastFeedingCount = existing.breastFeedingCount + 1;
      } else if (feeding.type === 'bottle') {
        updates.bottleFeedingCount = existing.bottleFeedingCount + 1;
        
        if (existing.bottleFeeding) {
          updates['bottleFeeding.totalMl'] = existing.bottleFeeding.totalMl + feeding.bottleFeeding.amountMl;
          updates['bottleFeeding.totalOz'] = existing.bottleFeeding.totalOz + feeding.bottleFeeding.amountOz;
          updates['bottleFeeding.count'] = existing.bottleFeeding.count + 1;
          updates['bottleFeeding.averageMl'] = 
            (existing.bottleFeeding.totalMl + feeding.bottleFeeding.amountMl) / 
            (existing.bottleFeeding.count + 1);
        }
      } else if (feeding.type === 'solids') {
        updates.solidFoodCount = existing.solidFoodCount + 1;
      }
      
      t.update(statsRef, updates);
    }
  });
}

// ═══════════════════════════════════════════════════════════
// Detect Feeding Patterns
// ═══════════════════════════════════════════════════════════

async function detectFeedingPatterns(babyId: string, currentFeeding: any): Promise<void> {
  // Get last 10 feedings
  const feedingsSnapshot = await db
    .collection('babies')
    .doc(babyId)
    .collection('feedings')
    .orderBy('startTime', 'desc')
    .limit(10)
    .get();
  
  const feedings = feedingsSnapshot.docs.map(d => d.data());
  
  if (feedings.length < 3) return;  // Need at least 3 feedings
  
  // Calculate intervals
  const intervals: number[] = [];
  for (let i = 0; i < feedings.length - 1; i++) {
    const gap = feedings[i].startTime.toMillis() - feedings[i + 1].startTime.toMillis();
    intervals.push(gap / 1000 / 60);  // minutes
  }
  
  const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
  
  // Detect cluster feeding (3+ feedings within 3 hours)
  const threeHoursAgo = Date.now() - (3 * 60 * 60 * 1000);
  const recentFeedings = feedings.filter(
    f => f.startTime.toMillis() > threeHoursAgo
  );
  
  const patterns: string[] = [];
  
  if (recentFeedings.length >= 3) {
    patterns.push('cluster_feeding');
  }
  
  // Regular schedule (consistent intervals ±30 min)
  const isRegular = intervals.every(interval => 
    Math.abs(interval - avgInterval) < 30
  );
  
  if (isRegular) {
    patterns.push('regular_schedule');
  }
  
  // Growth spurt (feeding frequency increased by 50%)
  // Compare current avg interval vs last 7 days
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  const oldFeedingsSnapshot = await db
    .collection('babies')
    .doc(babyId)
    .collection('feedings')
    .where('startTime', '<', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
    .orderBy('startTime', 'desc')
    .limit(10)
    .get();
  
  if (oldFeedingsSnapshot.size >= 3) {
    const oldFeedings = oldFeedingsSnapshot.docs.map(d => d.data());
    const oldIntervals: number[] = [];
    
    for (let i = 0; i < oldFeedings.length - 1; i++) {
      const gap = oldFeedings[i].startTime.toMillis() - oldFeedings[i + 1].startTime.toMillis();
      oldIntervals.push(gap / 1000 / 60);
    }
    
    const oldAvgInterval = oldIntervals.reduce((a, b) => a + b, 0) / oldIntervals.length;
    
    if (avgInterval < oldAvgInterval * 0.7) {  // 30% shorter intervals
      patterns.push('growth_spurt');
    }
  }
  
  // Save patterns to daily stats
  if (patterns.length > 0) {
    const date = new Date().toISOString().split('T')[0];
    const statsRef = db
      .collection('babies')
      .doc(babyId)
      .collection('feeding_stats')
      .doc('daily')
      .collection('data')
      .doc(date);
    
    await statsRef.update({
      patterns: admin.firestore.FieldValue.arrayUnion(...patterns),
    });
  }
}

// ═══════════════════════════════════════════════════════════
// Generate Insights
// ═══════════════════════════════════════════════════════════

async function generateInsights(babyId: string): Promise<void> {
  const date = new Date().toISOString().split('T')[0];
  
  // Get today's stats
  const statsDoc = await db
    .collection('babies')
    .doc(babyId)
    .collection('feeding_stats')
    .doc('daily')
    .collection('data')
    .doc(date)
    .get();
  
  if (!statsDoc.exists) return;
  
  const stats = statsDoc.data()!;
  
  // Generate insights based on patterns
  if (stats.patterns?.includes('cluster_feeding')) {
    await db
      .collection('babies')
      .doc(babyId)
      .collection('feeding_insights')
      .add({
        babyId,
        date,
        type: 'pattern_detected',
        category: 'general',
        title: 'Cluster Feeding Detected',
        message: 'Baby has fed 3+ times in the last 3 hours. This is normal and often happens during growth spurts or for comfort.',
        severity: 'info',
        actionRequired: false,
        isDismissed: false,
        createdAt: admin.firestore.Timestamp.now(),
      });
  }
  
  if (stats.patterns?.includes('growth_spurt')) {
    await db
      .collection('babies')
      .doc(babyId)
      .collection('feeding_insights')
      .add({
        babyId,
        date,
        type: 'pattern_detected',
        category: 'general',
        title: 'Possible Growth Spurt',
        message: 'Feeding frequency has increased significantly. Baby may be going through a growth spurt!',
        severity: 'success',
        actionRequired: false,
        isDismissed: false,
        createdAt: admin.firestore.Timestamp.now(),
      });
  }
}

// ═══════════════════════════════════════════════════════════
// Check Feeding Alerts
// ═══════════════════════════════════════════════════════════

async function checkFeedingAlerts(babyId: string, currentFeeding: any): Promise<void> {
  // Get baby age to determine alert thresholds
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const babyData = babyDoc.data();
  
  if (!babyData) return;
  
  const birthDate = babyData.dateOfBirth.toDate();
  const ageMonths = (Date.now() - birthDate.getTime()) / (1000 * 60 * 60 * 24 * 30);
  
  // Get last feeding
  const lastFeedingSnapshot = await db
    .collection('babies')
    .doc(babyId)
    .collection('feedings')
    .where('startTime', '<', currentFeeding.startTime)
    .orderBy('startTime', 'desc')
    .limit(1)
    .get();
  
  if (lastFeedingSnapshot.empty) return;
  
  const lastFeeding = lastFeedingSnapshot.docs[0].data();
  const gapHours = 
    (currentFeeding.startTime.toMillis() - lastFeeding.startTime.toMillis()) / 
    (1000 * 60 * 60);
  
  // Alert if gap is too long
  let maxGapHours = 4;  // Default for 0-3 months
  
  if (ageMonths > 6) {
    maxGapHours = 6;
  } else if (ageMonths > 3) {
    maxGapHours = 5;
  }
  
  if (gapHours > maxGapHours) {
    // Send alert notification
    await sendFeedingAlert(
      babyId,
      'Long Gap Between Feedings',
      `It's been ${gapHours.toFixed(1)} hours since last feeding. Consider feeding baby.`
    );
  }
}

async function sendFeedingAlert(babyId: string, title: string, message: string): Promise<void> {
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const familyMembers = babyDoc.data()?.familyMembers || [];
  
  const tokens: string[] = [];
  for (const userId of familyMembers) {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) tokens.push(fcmToken);
  }
  
  if (tokens.length === 0) return;
  
  await admin.messaging().sendMulticast({
    tokens,
    notification: { title, body: message },
    data: { type: 'feeding_alert', babyId },
  });
}
```

---

## 4️⃣ FLUTTER IMPLEMENTATION

### **4.1 Feeding Service**

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/feeding_service.dart
// ═══════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feeding_model.dart';

class FeedingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════════════════
  
  /// Create a new feeding record
  Future<String> createFeeding(FeedingModel feeding) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(feeding.babyId)
        .collection('feedings')
        .add(feeding.toMap());
    
    return docRef.id;
  }
  
  /// Start breastfeeding timer
  Future<String> startBreastfeeding({
    required String babyId,
    required String userId,
    required FeedingSide startSide,
  }) async {
    final feeding = FeedingModel(
      id: '',
      babyId: babyId,
      type: FeedingType.breast,
      startTime: DateTime.now(),
      breastfeeding: BreastfeedingData(
        leftDuration: Duration.zero,
        rightDuration: Duration.zero,
        startSide: startSide,
        endSide: startSide,
        switchCount: 0,
      ),
      completed: false,
      loggedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    return await createFeeding(feeding);
  }
  
  /// Log bottle feeding
  Future<String> logBottleFeeding({
    required String babyId,
    required String userId,
    required double amountMl,
    required BottleFeedingType feedingType,
    String? formulaBrand,
  }) async {
    final amountOz = amountMl * 0.033814;  // Convert ml to oz
    
    final feeding = FeedingModel(
      id: '',
      babyId: babyId,
      type: FeedingType.bottle,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      duration: Duration.zero,
      bottleFeeding: BottleFeedingData(
        amountMl: amountMl,
        amountOz: amountOz,
        feedingType: feedingType,
        formulaBrand: formulaBrand,
      ),
      completed: true,
      loggedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    return await createFeeding(feeding);
  }
  
  /// Log solid food
  Future<String> logSolidFood({
    required String babyId,
    required String userId,
    required List<FoodItem> foods,
    bool selfFed = false,
    double? waterMl,
  }) async {
    final feeding = FeedingModel(
      id: '',
      babyId: babyId,
      type: FeedingType.solids,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      solidFood: SolidFoodData(
        foods: foods,
        waterMl: waterMl,
        selfFed: selfFed,
      ),
      completed: true,
      loggedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    return await createFeeding(feeding);
  }
  
  // ═══════════════════════════════════════════════════════════
  // UPDATE
  // ═══════════════════════════════════════════════════════════
  
  /// Update breastfeeding session
  Future<void> updateBreastfeeding({
    required String babyId,
    required String feedingId,
    required Duration leftDuration,
    required Duration rightDuration,
    required FeedingSide currentSide,
    required int switchCount,
  }) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .doc(feedingId)
        .update({
      'breastfeeding.leftDuration': leftDuration.inSeconds,
      'breastfeeding.rightDuration': rightDuration.inSeconds,
      'breastfeeding.endSide': currentSide.name,
      'breastfeeding.switchCount': switchCount,
      'duration': (leftDuration + rightDuration).inSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Complete feeding session
  Future<void> completeFeeding({
    required String babyId,
    required String feedingId,
    String? completionReason,
    String? notes,
  }) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .doc(feedingId)
        .update({
      'completed': true,
      'endTime': FieldValue.serverTimestamp(),
      'completionReason': completionReason,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // ═══════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════
  
  /// Stream today's feedings
  Stream<List<FeedingModel>> streamTodayFeedings(String babyId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FeedingModel.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get feeding history
  Future<List<FeedingModel>> getFeedingHistory({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  }) async {
    Query query = _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => FeedingModel.fromFirestore(doc))
        .toList();
  }
  
  /// Get active feeding session
  Future<FeedingModel?> getActiveFeeding(String babyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .where('completed', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    return FeedingModel.fromFirestore(snapshot.docs.first);
  }
  
  /// Get daily stats
  Future<DailyFeedingStats?> getDailyStats(String babyId, String date) async {
    final doc = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feeding_stats')
        .doc('daily')
        .collection('data')
        .doc(date)
        .get();
    
    if (!doc.exists) return null;
    
    return DailyFeedingStats.fromFirestore(doc);
  }
  
  /// Stream daily stats
  Stream<DailyFeedingStats?> streamDailyStats(String babyId, String date) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feeding_stats')
        .doc('daily')
        .collection('data')
        .doc(date)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return DailyFeedingStats.fromFirestore(doc);
    });
  }
  
  /// Predict next feeding time
  Future<DateTime?> predictNextFeeding(String babyId) async {
    final feedings = await getFeedingHistory(
      babyId: babyId,
      startDate: DateTime.now().subtract(Duration(days: 3)),
      endDate: DateTime.now(),
      limit: 10,
    );
    
    if (feedings.length < 3) return null;
    
    // Calculate average interval
    final intervals = <Duration>[];
    for (int i = 0; i < feedings.length - 1; i++) {
      final gap = feedings[i].startTime.difference(feedings[i + 1].startTime);
      intervals.add(gap);
    }
    
    final avgInterval = Duration(
      milliseconds: intervals
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b) ~/ intervals.length,
    );
    
    final lastFeeding = feedings.first;
    return lastFeeding.startTime.add(avgInterval);
  }
  
  // ═══════════════════════════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════════════════════════
  
  /// Delete feeding record
  Future<void> deleteFeeding(String babyId, String feedingId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('feedings')
        .doc(feedingId)
        .delete();
  }
}
```

---

## 5️⃣ ANALYTICS & INSIGHTS

### **5.1 Feeding Insights Widget**

```dart
// ═══════════════════════════════════════════════════════════
// lib/widgets/feeding/feeding_insights_card.dart
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/feeding_model.dart';

class FeedingInsightsCard extends StatelessWidget {
  final DailyFeedingStats stats;
  
  const FeedingInsightsCard({required this.stats});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // Total feedings
            _buildStatRow(
              icon: Icons.restaurant,
              label: 'Total Feedings',
              value: '${stats.totalFeedings}',
              color: Colors.blue,
            ),
            
            // Average interval
            if (stats.averageInterval.inMinutes > 0)
              _buildStatRow(
                icon: Icons.schedule,
                label: 'Avg Interval',
                value: _formatDuration(stats.averageInterval),
                color: Colors.orange,
              ),
            
            // Breastfeeding stats
            if (stats.breastfeeding != null) ...[
              SizedBox(height: 8),
              _buildStatRow(
                icon: Icons.child_care,
                label: 'Breastfeeding Time',
                value: _formatDuration(stats.breastfeeding!.totalDuration),
                color: Colors.pink,
              ),
            ],
            
            // Bottle stats
            if (stats.bottleFeeding != null) ...[
              SizedBox(height: 8),
              _buildStatRow(
                icon: Icons.local_drink,
                label: 'Total Intake',
                value: '${stats.bottleFeeding!.totalMl.toInt()} ml',
                color: Colors.cyan,
              ),
            ],
            
            // Patterns
            if (stats.patterns.isNotEmpty) ...[
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: stats.patterns.map((pattern) {
                  return Chip(
                    label: Text(_formatPattern(pattern)),
                    backgroundColor: _getPatternColor(pattern),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[700])),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
  
  String _formatPattern(String pattern) {
    switch (pattern) {
      case 'cluster_feeding':
        return 'Cluster Feeding';
      case 'regular_schedule':
        return 'Regular Schedule';
      case 'demand_feeding':
        return 'On Demand';
      case 'growth_spurt':
        return 'Growth Spurt';
      default:
        return pattern;
    }
  }
  
  Color _getPatternColor(String pattern) {
    switch (pattern) {
      case 'cluster_feeding':
        return Colors.orange.shade100;
      case 'regular_schedule':
        return Colors.green.shade100;
      case 'growth_spurt':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
```

---

## 6️⃣ IMPLEMENTATION ROADMAP

### **Phase 1: Models & Service (Week 1)**

- [ ] Create FeedingModel with all variants
- [ ] Create BreastfeedingData, BottleFeedingData, SolidFoodData models
- [ ] Create DailyFeedingStats model
- [ ] Implement FeedingService with CRUD operations
- [ ] Add unit tests for models
- [ ] Add unit tests for service

### **Phase 2: UI Components (Week 1-2)**

- [ ] Create breastfeeding timer screen
- [ ] Create bottle feeding log screen
- [ ] Create solid food log screen
- [ ] Create feeding history timeline
- [ ] Create daily stats card
- [ ] Create feeding insights widget
- [ ] Add quick-log buttons to home screen

### **Phase 3: Cloud Functions (Week 2)**

- [ ] Implement onFeedingCreate trigger
- [ ] Add daily stats aggregation
- [ ] Add pattern detection (cluster feeding, growth spurts)
- [ ] Add feeding alerts (long gaps)
- [ ] Generate insights
- [ ] Test with sample data

### **Phase 4: Analytics & Insights (Week 2-3)**

- [ ] Create feeding charts (timeline, bar chart)
- [ ] Add prediction algorithm (next feeding time)
- [ ] Create weekly summary report
- [ ] Add export functionality (PDF/CSV)
- [ ] Implement feeding reminders
- [ ] Test accuracy of predictions

---

## ✅ SUCCESS METRICS

- [ ] Breastfeeding timer accurate to the second
- [ ] Bottle feeding logged in <30 seconds
- [ ] Daily stats updated within 5 seconds
- [ ] Pattern detection accuracy >80%
- [ ] Next feeding prediction within ±30 minutes
- [ ] User can view 30-day feeding history
- [ ] Export to PDF works correctly

---

**Ready to implement!** Start with Phase 1 (Models & Service) to get the data structure working. 🍼

