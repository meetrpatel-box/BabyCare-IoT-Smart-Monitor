# 🚼 Diaper Tracking - Low-Level Design

**Date:** February 2, 2026  
**Feature:** Manual Diaper Change Tracking  
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

| Feature | Description | Insights |
|---------|-------------|----------|
| **Quick Log** | Tap to log wet/dirty/both | Track frequency |
| **Diaper Type** | Disposable, cloth, training | Usage patterns |
| **Stool Details** | Color, consistency, size | Health indicators |
| **Rash Tracking** | Severity, location, treatment | Trend analysis |
| **Change Reminders** | Auto-reminder after X hours | Prevent rashes |
| **Health Alerts** | Unusual patterns (constipation, diarrhea) | Early warning |

### **1.2 Data Flow Architecture**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DIAPER TRACKING FLOW                              │
└─────────────────────────────────────────────────────────────────────────┘

Flutter App                    Firebase Cloud              Analytics
┌────────────────┐            ┌──────────────────┐         ┌─────────────┐
│                │            │                  │         │             │
│  Quick Log     │            │  Cloud Function  │         │  Insights   │
│  ────────────  │   Write    │  ──────────────  │ Trigger │  ─────────  │
│                │  Firestore │                  │ ──────> │             │
│  [💧 Wet]      │ ────────> │  onDiaperCreate  │         │  Frequency  │
│  [💩 Dirty]    │            │  - Validate      │         │  - Normal   │
│  [Both]        │            │  - Update stats  │         │  - Low      │
│                │            │  - Check health  │         │  - High     │
│  Details       │            │                  │         │             │
│  ────────────  │            │  Daily Stats     │         │  Health     │
│  Color: Yellow │            │  ──────────────  │         │  Checks     │
│  Consistency   │            │  Wet count       │         │  - Dehydr.  │
│  Rash: Mild    │            │  Dirty count     │         │  - Constip. │
│  [Save]        │            │  Rash alerts     │         │  - Diarrhea │
│                │            │                  │         │             │
│  History       │   Read     │  Health Alerts   │         │  Rash       │
│  ────────────  │  Firestore │  ──────────────  │         │  Tracking   │
│  Today: 8 wet  │ <───────── │  No wet 6+ hrs   │         │  - Severity │
│        3 dirty │            │  Diarrhea alert  │         │  - Location │
│  Chart         │            │  Dehydration     │         │  - Treatment│
└────────────────┘            └──────────────────┘         └─────────────┘
```

### **1.3 Storage Strategy**

```
Firestore Collections:
├─ babies/{babyId}/diapers/{diaperId}              (Individual changes)
├─ babies/{babyId}/diaper_stats/daily/{date}       (Daily aggregates)
├─ babies/{babyId}/diaper_stats/weekly/{week}      (Weekly summaries)
├─ babies/{babyId}/diaper_health_alerts/{alertId}  (Health alerts)
└─ babies/{babyId}/rash_tracking/{rashId}          (Rash timeline)

Data Retention:
- Individual changes: Permanent
- Daily stats: Permanent
- Health alerts: Permanent
- Rash tracking: Permanent
```

---

## 2️⃣ DATA MODELS

### **2.1 Firestore Schema**

```typescript
// ═══════════════════════════════════════════════════════════
// Firestore Document Schemas
// ═══════════════════════════════════════════════════════════

// Collection: babies/{babyId}/diapers/{diaperId}
interface DiaperChangeDocument {
  id: string;
  babyId: string;
  
  // Change details
  type: 'wet' | 'dirty' | 'both' | 'dry_check';
  
  // Timing
  changedAt: FirebaseFirestore.Timestamp;
  
  // Diaper info
  diaperType: 'disposable' | 'cloth' | 'training' | 'swim';
  diaperBrand?: string;
  size?: string;  // NB, 1, 2, 3, etc.
  
  // Urine details (if wet)
  urineDetails?: {
    amount: 'small' | 'medium' | 'large';
    color: 'clear' | 'light_yellow' | 'dark_yellow' | 'other';
    hasOdor: boolean;
  };
  
  // Stool details (if dirty)
  stoolDetails?: {
    consistency: 'watery' | 'soft' | 'formed' | 'hard' | 'pellets';
    color: 'yellow' | 'brown' | 'green' | 'black' | 'red' | 'white';
    amount: 'small' | 'medium' | 'large';
    hasBlood: boolean;
    hasMucus: boolean;
  };
  
  // Rash assessment
  hasRash: boolean;
  rashDetails?: {
    severity: 'mild' | 'moderate' | 'severe';
    location: ('buttocks' | 'genitals' | 'thighs' | 'lower_back')[];
    type: 'redness' | 'bumps' | 'blisters' | 'peeling' | 'bleeding';
    treatmentApplied?: string;  // e.g., "Diaper cream", "Zinc oxide"
  };
  
  // Context
  location?: 'home' | 'daycare' | 'outside' | 'other';
  
  // Notes
  notes?: string;
  
  // Logged by
  changedBy: string;  // userId
  loggedAt: FirebaseFirestore.Timestamp;
  
  // Metadata
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/diaper_stats/daily/{date}
interface DailyDiaperStats {
  babyId: string;
  date: string;  // YYYY-MM-DD
  
  // Counts
  totalChanges: number;
  wetCount: number;
  dirtyCount: number;
  bothCount: number;
  dryCheckCount: number;
  
  // Frequency analysis
  changeIntervals: number[];  // minutes between changes
  averageInterval: number;
  longestDryPeriod: number;  // minutes
  
  // Time distribution
  hourlyDistribution: Record<string, number>;  // Hour of day
  
  // Stool analysis
  stoolChanges: number;
  stoolConsistencies: Record<string, number>;  // {watery: 2, soft: 1}
  stoolColors: Record<string, number>;
  
  // Health flags
  healthFlags: ('dehydration_risk' | 'constipation' | 'diarrhea' | 'unusual_color')[];
  
  // Rash tracking
  rashOccurrences: number;
  rashSeverity?: 'mild' | 'moderate' | 'severe';
  
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/diaper_health_alerts/{alertId}
interface DiaperHealthAlert {
  id: string;
  babyId: string;
  
  // Alert type
  alertType: 'no_wet_6h' | 'no_dirty_3d' | 'diarrhea' | 'constipation' | 
             'blood_in_stool' | 'unusual_color' | 'severe_rash';
  severity: 'info' | 'warning' | 'critical';
  
  // Alert details
  title: string;
  message: string;
  
  // Supporting data
  data?: {
    hoursSinceLastWet?: number;
    daysSinceLastDirty?: number;
    diarrheaCount?: number;
    stoolColor?: string;
  };
  
  // Recommendations
  recommendation: string;
  requiresDoctorVisit: boolean;
  
  // Status
  status: 'active' | 'acknowledged' | 'resolved';
  acknowledgedBy?: string;
  acknowledgedAt?: FirebaseFirestore.Timestamp;
  resolvedAt?: FirebaseFirestore.Timestamp;
  
  // Notification
  notificationSent: boolean;
  
  triggeredAt: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/rash_tracking/{rashId}
interface RashTrackingDocument {
  id: string;
  babyId: string;
  
  // Rash episode
  startedAt: FirebaseFirestore.Timestamp;
  resolvedAt?: FirebaseFirestore.Timestamp;
  duration?: number;  // hours
  
  // Initial assessment
  initialSeverity: 'mild' | 'moderate' | 'severe';
  currentSeverity: 'mild' | 'moderate' | 'severe';
  
  // Progression
  progressionLog: Array<{
    timestamp: FirebaseFirestore.Timestamp;
    severity: 'mild' | 'moderate' | 'severe';
    treatment?: string;
    notes?: string;
  }>;
  
  // Treatment history
  treatments: string[];
  
  // Resolution
  resolved: boolean;
  resolutionNotes?: string;
  
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}
```

### **2.2 Flutter Dart Models**

```dart
// ═══════════════════════════════════════════════════════════
// lib/models/diaper_change_model.dart
// ═══════════════════════════════════════════════════════════

enum DiaperChangeType { wet, dirty, both, dryCheck }

enum DiaperType { disposable, cloth, training, swim }

enum StoolConsistency { watery, soft, formed, hard, pellets }

enum StoolColor { yellow, brown, green, black, red, white }

enum RashSeverity { mild, moderate, severe }

class DiaperChangeModel {
  final String id;
  final String babyId;
  final DiaperChangeType type;
  final DateTime changedAt;
  
  // Diaper info
  final DiaperType diaperType;
  final String? diaperBrand;
  final String? size;
  
  // Details
  final UrineDetails? urineDetails;
  final StoolDetails? stoolDetails;
  
  // Rash
  final bool hasRash;
  final RashDetails? rashDetails;
  
  // Context
  final String? location;
  final String? notes;
  
  // Metadata
  final String changedBy;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  DiaperChangeModel({
    required this.id,
    required this.babyId,
    required this.type,
    required this.changedAt,
    required this.diaperType,
    this.diaperBrand,
    this.size,
    this.urineDetails,
    this.stoolDetails,
    required this.hasRash,
    this.rashDetails,
    this.location,
    this.notes,
    required this.changedBy,
    required this.loggedAt,
    required this.createdAt,
    this.updatedAt,
  });
  
  // Display helpers
  String get displayType {
    switch (type) {
      case DiaperChangeType.wet:
        return '💧 Wet';
      case DiaperChangeType.dirty:
        return '💩 Dirty';
      case DiaperChangeType.both:
        return '💧💩 Both';
      case DiaperChangeType.dryCheck:
        return '✓ Dry Check';
    }
  }
  
  String get displayTime {
    final now = DateTime.now();
    final diff = now.difference(changedAt);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  bool get hasHealthConcern {
    if (stoolDetails != null) {
      if (stoolDetails!.hasBlood) return true;
      if (stoolDetails!.color == StoolColor.black && babyId.contains('infant')) return true;
      if (stoolDetails!.color == StoolColor.white) return true;
      if (stoolDetails!.color == StoolColor.red) return true;
    }
    if (hasRash && rashDetails?.severity == RashSeverity.severe) return true;
    return false;
  }
  
  factory DiaperChangeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DiaperChangeModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      type: DiaperChangeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => DiaperChangeType.wet,
      ),
      changedAt: (data['changedAt'] as Timestamp).toDate(),
      diaperType: DiaperType.values.firstWhere(
        (e) => e.name == data['diaperType'],
        orElse: () => DiaperType.disposable,
      ),
      diaperBrand: data['diaperBrand'],
      size: data['size'],
      urineDetails: data['urineDetails'] != null
          ? UrineDetails.fromMap(data['urineDetails'])
          : null,
      stoolDetails: data['stoolDetails'] != null
          ? StoolDetails.fromMap(data['stoolDetails'])
          : null,
      hasRash: data['hasRash'] ?? false,
      rashDetails: data['rashDetails'] != null
          ? RashDetails.fromMap(data['rashDetails'])
          : null,
      location: data['location'],
      notes: data['notes'],
      changedBy: data['changedBy'] ?? '',
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
      'changedAt': Timestamp.fromDate(changedAt),
      'diaperType': diaperType.name,
      'diaperBrand': diaperBrand,
      'size': size,
      'urineDetails': urineDetails?.toMap(),
      'stoolDetails': stoolDetails?.toMap(),
      'hasRash': hasRash,
      'rashDetails': rashDetails?.toMap(),
      'location': location,
      'notes': notes,
      'changedBy': changedBy,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Supporting Classes
// ═══════════════════════════════════════════════════════════

class UrineDetails {
  final String amount;  // small, medium, large
  final String color;
  final bool hasOdor;
  
  UrineDetails({
    required this.amount,
    required this.color,
    required this.hasOdor,
  });
  
  factory UrineDetails.fromMap(Map<String, dynamic> map) {
    return UrineDetails(
      amount: map['amount'] ?? 'medium',
      color: map['color'] ?? 'light_yellow',
      hasOdor: map['hasOdor'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'color': color,
      'hasOdor': hasOdor,
    };
  }
}

class StoolDetails {
  final StoolConsistency consistency;
  final StoolColor color;
  final String amount;  // small, medium, large
  final bool hasBlood;
  final bool hasMucus;
  
  StoolDetails({
    required this.consistency,
    required this.color,
    required this.amount,
    required this.hasBlood,
    required this.hasMucus,
  });
  
  String get displayConsistency => consistency.name.replaceAll('_', ' ');
  String get displayColor => color.name.replaceAll('_', ' ');
  
  factory StoolDetails.fromMap(Map<String, dynamic> map) {
    return StoolDetails(
      consistency: StoolConsistency.values.firstWhere(
        (e) => e.name == map['consistency'],
        orElse: () => StoolConsistency.soft,
      ),
      color: StoolColor.values.firstWhere(
        (e) => e.name == map['color'],
        orElse: () => StoolColor.yellow,
      ),
      amount: map['amount'] ?? 'medium',
      hasBlood: map['hasBlood'] ?? false,
      hasMucus: map['hasMucus'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'consistency': consistency.name,
      'color': color.name,
      'amount': amount,
      'hasBlood': hasBlood,
      'hasMucus': hasMucus,
    };
  }
}

class RashDetails {
  final RashSeverity severity;
  final List<String> location;
  final String type;
  final String? treatmentApplied;
  
  RashDetails({
    required this.severity,
    required this.location,
    required this.type,
    this.treatmentApplied,
  });
  
  String get locationText => location.join(', ');
  
  factory RashDetails.fromMap(Map<String, dynamic> map) {
    return RashDetails(
      severity: RashSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => RashSeverity.mild,
      ),
      location: List<String>.from(map['location'] ?? []),
      type: map['type'] ?? 'redness',
      treatmentApplied: map['treatmentApplied'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'severity': severity.name,
      'location': location,
      'type': type,
      'treatmentApplied': treatmentApplied,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Daily Stats Model
// ═══════════════════════════════════════════════════════════

class DailyDiaperStats {
  final String babyId;
  final String date;
  final int totalChanges;
  final int wetCount;
  final int dirtyCount;
  final int bothCount;
  final Duration averageInterval;
  final Duration longestDryPeriod;
  final int stoolChanges;
  final List<String> healthFlags;
  final int rashOccurrences;
  
  DailyDiaperStats({
    required this.babyId,
    required this.date,
    required this.totalChanges,
    required this.wetCount,
    required this.dirtyCount,
    required this.bothCount,
    required this.averageInterval,
    required this.longestDryPeriod,
    required this.stoolChanges,
    required this.healthFlags,
    required this.rashOccurrences,
  });
  
  bool get hasDehydrationRisk => healthFlags.contains('dehydration_risk');
  bool get hasConstipation => healthFlags.contains('constipation');
  bool get hasDiarrhea => healthFlags.contains('diarrhea');
  
  String get summary {
    return '$wetCount wet, $dirtyCount dirty';
  }
  
  factory DailyDiaperStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DailyDiaperStats(
      babyId: data['babyId'] ?? '',
      date: data['date'] ?? '',
      totalChanges: data['totalChanges'] ?? 0,
      wetCount: data['wetCount'] ?? 0,
      dirtyCount: data['dirtyCount'] ?? 0,
      bothCount: data['bothCount'] ?? 0,
      averageInterval: Duration(minutes: data['averageInterval'] ?? 0),
      longestDryPeriod: Duration(minutes: data['longestDryPeriod'] ?? 0),
      stoolChanges: data['stoolChanges'] ?? 0,
      healthFlags: List<String>.from(data['healthFlags'] ?? []),
      rashOccurrences: data['rashOccurrences'] ?? 0,
    );
  }
}
```

---

## 3️⃣ CLOUD FUNCTIONS

```typescript
// ═══════════════════════════════════════════════════════════
// functions/src/onDiaperCreate.ts
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export const onDiaperCreate = functions.firestore
  .document('babies/{babyId}/diapers/{diaperId}')
  .onCreate(async (snap, context) => {
    
    const diaper = snap.data();
    const { babyId } = context.params;
    
    console.log(`[onDiaperCreate] Baby: ${babyId}, Type: ${diaper.type}`);
    
    try {
      // Update daily stats
      await updateDailyDiaperStats(babyId, diaper);
      
      // Check for health alerts
      await checkDiaperHealthAlerts(babyId, diaper);
      
      // Update rash tracking if needed
      if (diaper.hasRash) {
        await updateRashTracking(babyId, diaper);
      }
      
    } catch (error) {
      console.error('[onDiaperCreate] Error:', error);
    }
  });

async function updateDailyDiaperStats(babyId: string, diaper: any): Promise<void> {
  const date = new Date(diaper.changedAt.toDate()).toISOString().split('T')[0];
  const statsRef = db
    .collection('babies')
    .doc(babyId)
    .collection('diaper_stats')
    .doc('daily')
    .collection('data')
    .doc(date);
  
  await db.runTransaction(async (t) => {
    const doc = await t.get(statsRef);
    
    const typeKey = `${diaper.type}Count`;
    
    if (!doc.exists) {
      t.set(statsRef, {
        babyId,
        date,
        totalChanges: 1,
        wetCount: diaper.type === 'wet' || diaper.type === 'both' ? 1 : 0,
        dirtyCount: diaper.type === 'dirty' || diaper.type === 'both' ? 1 : 0,
        bothCount: diaper.type === 'both' ? 1 : 0,
        dryCheckCount: diaper.type === 'dry_check' ? 1 : 0,
        stoolChanges: diaper.stoolDetails ? 1 : 0,
        healthFlags: [],
        rashOccurrences: diaper.hasRash ? 1 : 0,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
    } else {
      const existing = doc.data()!;
      
      const updates: any = {
        totalChanges: existing.totalChanges + 1,
        updatedAt: admin.firestore.Timestamp.now(),
      };
      
      if (diaper.type === 'wet' || diaper.type === 'both') {
        updates.wetCount = existing.wetCount + 1;
      }
      if (diaper.type === 'dirty' || diaper.type === 'both') {
        updates.dirtyCount = existing.dirtyCount + 1;
      }
      if (diaper.stoolDetails) {
        updates.stoolChanges = existing.stoolChanges + 1;
      }
      if (diaper.hasRash) {
        updates.rashOccurrences = existing.rashOccurrences + 1;
      }
      
      t.update(statsRef, updates);
    }
  });
}

async function checkDiaperHealthAlerts(babyId: string, currentDiaper: any): Promise<void> {
  // Get baby age
  const babyDoc = await db.collection('babies').doc(babyId).get();
  const birthDate = babyDoc.data()?.dateOfBirth.toDate();
  const ageMonths = (Date.now() - birthDate.getTime()) / (1000 * 60 * 60 * 24 * 30);
  
  // Check for no wet diaper in 6+ hours
  if (currentDiaper.type === 'wet' || currentDiaper.type === 'both') {
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
    const recentWetSnapshot = await db
      .collection('babies')
      .doc(babyId)
      .collection('diapers')
      .where('type', 'in', ['wet', 'both'])
      .where('changedAt', '>', admin.firestore.Timestamp.fromDate(sixHoursAgo))
      .limit(1)
      .get();
    
    if (recentWetSnapshot.empty) {
      await createHealthAlert(
        babyId,
        'no_wet_6h',
        'No Wet Diaper in 6+ Hours',
        'Baby may be dehydrated. Ensure adequate feeding.',
        'warning',
        true
      );
    }
  }
  
  // Check for constipation (no dirty diaper in 3+ days for formula-fed babies)
  if (currentDiaper.type === 'dirty' || currentDiaper.type === 'both') {
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    const recentDirtySnapshot = await db
      .collection('babies')
      .doc(babyId)
      .collection('diapers')
      .where('type', 'in', ['dirty', 'both'])
      .where('changedAt', '>', admin.firestore.Timestamp.fromDate(threeDaysAgo))
      .limit(1)
      .get();
    
    if (recentDirtySnapshot.empty && ageMonths < 6) {
      await createHealthAlert(
        babyId,
        'no_dirty_3d',
        'No Bowel Movement in 3 Days',
        'Baby may be constipated. Consult pediatrician if continues.',
        'warning',
        true
      );
    }
  }
  
  // Check for diarrhea (4+ watery stools in 24 hours)
  if (currentDiaper.stoolDetails?.consistency === 'watery') {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const wateryStools = await db
      .collection('babies')
      .doc(babyId)
      .collection('diapers')
      .where('stoolDetails.consistency', '==', 'watery')
      .where('changedAt', '>', admin.firestore.Timestamp.fromDate(oneDayAgo))
      .get();
    
    if (wateryStools.size >= 4) {
      await createHealthAlert(
        babyId,
        'diarrhea',
        'Diarrhea Detected',
        `${wateryStools.size} watery stools in 24 hours. Monitor for dehydration.`,
        'critical',
        true
      );
    }
  }
  
  // Check for blood in stool
  if (currentDiaper.stoolDetails?.hasBlood) {
    await createHealthAlert(
      babyId,
      'blood_in_stool',
      'Blood in Stool',
      'Contact pediatrician immediately.',
      'critical',
      true
    );
  }
  
  // Check for unusual stool color
  const concerningColors = ['black', 'red', 'white'];
  if (currentDiaper.stoolDetails && concerningColors.includes(currentDiaper.stoolDetails.color)) {
    await createHealthAlert(
      babyId,
      'unusual_color',
      'Unusual Stool Color',
      `Stool color is ${currentDiaper.stoolDetails.color}. Consult pediatrician.`,
      'warning',
      true
    );
  }
  
  // Check for severe rash
  if (currentDiaper.hasRash && currentDiaper.rashDetails?.severity === 'severe') {
    await createHealthAlert(
      babyId,
      'severe_rash',
      'Severe Diaper Rash',
      'Severe rash detected. Consider pediatric consultation if not improving.',
      'warning',
      false
    );
  }
}

async function createHealthAlert(
  babyId: string,
  alertType: string,
  title: string,
  message: string,
  severity: string,
  requiresDoctorVisit: boolean
): Promise<void> {
  await db
    .collection('babies')
    .doc(babyId)
    .collection('diaper_health_alerts')
    .add({
      babyId,
      alertType,
      severity,
      title,
      message,
      recommendation: requiresDoctorVisit ? 'Consult pediatrician' : 'Monitor closely',
      requiresDoctorVisit,
      status: 'active',
      notificationSent: false,
      triggeredAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
    });
  
  // Send push notification
  if (severity === 'critical') {
    await sendAlertNotification(babyId, title, message);
  }
}

async function sendAlertNotification(babyId: string, title: string, message: string): Promise<void> {
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
    notification: { title: `🚼 ${title}`, body: message },
    data: { type: 'diaper_health_alert', babyId },
  });
}

async function updateRashTracking(babyId: string, diaper: any): Promise<void> {
  // Get active rash episode
  const activeRashSnapshot = await db
    .collection('babies')
    .doc(babyId)
    .collection('rash_tracking')
    .where('resolved', '==', false)
    .limit(1)
    .get();
  
  if (activeRashSnapshot.empty) {
    // Start new rash episode
    await db
      .collection('babies')
      .doc(babyId)
      .collection('rash_tracking')
      .add({
        babyId,
        startedAt: diaper.changedAt,
        initialSeverity: diaper.rashDetails.severity,
        currentSeverity: diaper.rashDetails.severity,
        progressionLog: [{
          timestamp: diaper.changedAt,
          severity: diaper.rashDetails.severity,
          treatment: diaper.rashDetails.treatmentApplied,
        }],
        treatments: diaper.rashDetails.treatmentApplied 
          ? [diaper.rashDetails.treatmentApplied] 
          : [],
        resolved: false,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
  } else {
    // Update existing rash episode
    const rashDoc = activeRashSnapshot.docs[0];
    await rashDoc.ref.update({
      currentSeverity: diaper.rashDetails.severity,
      progressionLog: admin.firestore.FieldValue.arrayUnion({
        timestamp: diaper.changedAt,
        severity: diaper.rashDetails.severity,
        treatment: diaper.rashDetails.treatmentApplied,
      }),
      treatments: diaper.rashDetails.treatmentApplied
        ? admin.firestore.FieldValue.arrayUnion(diaper.rashDetails.treatmentApplied)
        : rashDoc.data().treatments,
      updatedAt: admin.firestore.Timestamp.now(),
    });
  }
}
```

---

## 4️⃣ FLUTTER IMPLEMENTATION

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/diaper_service.dart
// ═══════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diaper_change_model.dart';

class DiaperService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ═══════════════════════════════════════════════════════════
  // CREATE - Quick Log
  // ═══════════════════════════════════════════════════════════
  
  /// Quick log wet diaper
  Future<String> logWet(String babyId, String userId) async {
    final change = DiaperChangeModel(
      id: '',
      babyId: babyId,
      type: DiaperChangeType.wet,
      changedAt: DateTime.now(),
      diaperType: DiaperType.disposable,
      hasRash: false,
      changedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    final docRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diapers')
        .add(change.toMap());
    
    return docRef.id;
  }
  
  /// Quick log dirty diaper
  Future<String> logDirty(String babyId, String userId) async {
    final change = DiaperChangeModel(
      id: '',
      babyId: babyId,
      type: DiaperChangeType.dirty,
      changedAt: DateTime.now(),
      diaperType: DiaperType.disposable,
      hasRash: false,
      changedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    final docRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diapers')
        .add(change.toMap());
    
    return docRef.id;
  }
  
  /// Log detailed diaper change
  Future<String> logDetailedChange(DiaperChangeModel change) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(change.babyId)
        .collection('diapers')
        .add(change.toMap());
    
    return docRef.id;
  }
  
  // ═══════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════
  
  /// Stream today's diaper changes
  Stream<List<DiaperChangeModel>> streamTodayChanges(String babyId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diapers')
        .where('changedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DiaperChangeModel.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get daily stats
  Future<DailyDiaperStats?> getDailyStats(String babyId, String date) async {
    final doc = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diaper_stats')
        .doc('daily')
        .collection('data')
        .doc(date)
        .get();
    
    if (!doc.exists) return null;
    
    return DailyDiaperStats.fromFirestore(doc);
  }
  
  /// Check if change is overdue
  Future<bool> isChangeOverdue(String babyId) async {
    final lastChange = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diapers')
        .orderBy('changedAt', descending: true)
        .limit(1)
        .get();
    
    if (lastChange.docs.isEmpty) return false;
    
    final lastChangeTime = (lastChange.docs.first.data()['changedAt'] as Timestamp).toDate();
    final hoursSince = DateTime.now().difference(lastChangeTime).inHours;
    
    return hoursSince >= 4;  // 4+ hours
  }
  
  /// Get next change reminder time
  Future<DateTime?> getNextChangeReminder(String babyId) async {
    final lastChange = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('diapers')
        .orderBy('changedAt', descending: true)
        .limit(1)
        .get();
    
    if (lastChange.docs.isEmpty) return null;
    
    final lastChangeTime = (lastChange.docs.first.data()['changedAt'] as Timestamp).toDate();
    return lastChangeTime.add(Duration(hours: 3));  // Remind every 3 hours
  }
}
```

---

## 5️⃣ ANALYTICS & INSIGHTS

### **5.1 Quick Log Widget**

```dart
// ═══════════════════════════════════════════════════════════
// lib/widgets/diaper/quick_diaper_log.dart
// ═══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class QuickDiaperLog extends StatelessWidget {
  final String babyId;
  final String userId;
  
  const QuickDiaperLog({
    required this.babyId,
    required this.userId,
  });
  
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
              'Quick Log Diaper Change',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton(
                  context,
                  icon: Icons.water_drop,
                  label: 'Wet',
                  color: Colors.blue,
                  onTap: () => _logWet(context),
                ),
                _buildQuickButton(
                  context,
                  icon: Icons.brightness_2,
                  label: 'Dirty',
                  color: Colors.brown,
                  onTap: () => _logDirty(context),
                ),
                _buildQuickButton(
                  context,
                  icon: Icons.details,
                  label: 'Details',
                  color: Colors.purple,
                  onTap: () => _openDetailedLog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  
  Future<void> _logWet(BuildContext context) async {
    final service = DiaperService();
    await service.logWet(babyId, userId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('💧 Wet diaper logged')),
    );
  }
  
  Future<void> _logDirty(BuildContext context) async {
    final service = DiaperService();
    await service.logDirty(babyId, userId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('💩 Dirty diaper logged')),
    );
  }
  
  void _openDetailedLog(BuildContext context) {
    Navigator.pushNamed(context, '/diaper-detailed-log');
  }
}
```

---

## 6️⃣ IMPLEMENTATION ROADMAP

### **Phase 1: Models & Service (Week 1)**
- [ ] Create DiaperChangeModel with all details
- [ ] Create UrineDetails, StoolDetails, RashDetails models
- [ ] Create DailyDiaperStats model
- [ ] Implement DiaperService with quick-log methods
- [ ] Add unit tests

### **Phase 2: UI Components (Week 1)**
- [ ] Create quick-log widget (wet/dirty/both)
- [ ] Create detailed log screen
- [ ] Create diaper history timeline
- [ ] Create daily stats card
- [ ] Add health alert banners

### **Phase 3: Cloud Functions (Week 2)**
- [ ] Implement onDiaperCreate trigger
- [ ] Add daily stats aggregation
- [ ] Add health alert detection (dehydration, constipation, diarrhea)
- [ ] Add rash tracking
- [ ] Test with sample data

### **Phase 4: Analytics (Week 2)**
- [ ] Create diaper frequency chart
- [ ] Add health insights
- [ ] Implement change reminders
- [ ] Add export functionality

---

## ✅ SUCCESS METRICS

- [ ] Quick-log takes <5 seconds
- [ ] Health alerts triggered accurately (0 false positives)
- [ ] Rash tracking progression visible
- [ ] Daily stats update within 5 seconds
- [ ] Change reminders work reliably
- [ ] Export to PDF includes all details

---

**Ready to implement!** Start with Phase 1 (Models & Service). 🚼

