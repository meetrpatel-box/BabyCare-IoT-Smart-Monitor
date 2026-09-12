# 📏 Growth Tracking - Low-Level Design

**Date:** February 2, 2026  
**Feature:** Manual Growth Tracking with WHO Growth Charts  
**Type:** App-based Manual Entry (No Device Sensors)

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [WHO Growth Charts](#who-growth-charts)
3. [Data Models](#data-models)
4. [Cloud Functions](#cloud-functions)
5. [Flutter Implementation](#flutter-implementation)
6. [Growth Charts Visualization](#growth-charts-visualization)
7. [Implementation Roadmap](#implementation-roadmap)

---

## 1️⃣ SYSTEM OVERVIEW

### **1.1 Feature Scope**

| Feature | Description | WHO Standards |
|---------|-------------|---------------|
| **Weight Tracking** | Log weight in kg/lbs | WHO weight-for-age charts |
| **Height/Length** | Log height/length in cm/in | WHO length/height-for-age charts |
| **Head Circumference** | Log head size in cm | WHO head-circumference-for-age |
| **BMI Calculation** | Auto-calculate BMI | WHO BMI-for-age (2-5 years) |
| **Percentile Tracking** | Show percentile curves | 3rd, 15th, 50th, 85th, 97th |
| **Growth Velocity** | Track growth rate | Alert if slow/fast |
| **Export Reports** | PDF for pediatrician | Include all measurements + charts |

### **1.2 WHO Growth Chart Standards**

```
WHO Growth Charts (0-5 years):
├─ Weight-for-age (0-5 years)
│  ├─ Boys: 2.5-25 kg
│  └─ Girls: 2.4-23 kg
│
├─ Length/Height-for-age (0-5 years)
│  ├─ Boys: 45-120 cm
│  └─ Girls: 45-118 cm
│
├─ Weight-for-length/height (0-5 years)
│  ├─ <2 years: Weight-for-length
│  └─ 2-5 years: Weight-for-height
│
├─ Head Circumference-for-age (0-5 years)
│  ├─ Boys: 32-54 cm
│  └─ Girls: 31-53 cm
│
└─ BMI-for-age (2-5 years)
   ├─ Boys: 13-18 kg/m²
   └─ Girls: 13-18 kg/m²
```

### **1.3 Data Flow Architecture**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GROWTH TRACKING FLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

Flutter App                    Firebase Cloud              WHO Charts
┌────────────────┐            ┌──────────────────┐         ┌─────────────┐
│                │            │                  │         │             │
│  Measurement   │            │  Cloud Function  │         │  Percentile │
│  Entry         │   Write    │  ──────────────  │ Calculate│  ─────────  │
│  ────────────  │  Firestore │                  │ ──────> │             │
│                │ ────────> │  onMeasurCreate  │         │  WHO Data   │
│  Weight: 8.2kg │            │  - Validate      │         │  - JSON     │
│  Length: 72cm  │            │  - Calculate age │         │  - L/M/S    │
│  Head: 45cm    │            │  - Compute %ile  │         │  - Z-score  │
│  [Save]        │            │  - Update trend  │         │             │
│                │            │                  │         │  Compute    │
│  Growth Chart  │   Read     │  Percentile      │         │  ─────────  │
│  ────────────  │  Firestore │  ──────────────  │         │  Z-score    │
│  📊 Timeline   │ <───────── │  Weight: 65th    │         │  Percentile │
│  - Weight      │            │  Height: 50th    │         │  Category   │
│  - Height      │            │  Head: 75th      │         │             │
│  - Head circ.  │            │                  │         │  Alerts     │
│                │            │  Growth Alerts   │         │  ─────────  │
│  Insights      │            │  ──────────────  │         │  - Slow     │
│  ────────────  │            │  Falling %ile    │         │  - Fast     │
│  Growing well! │            │  Slow velocity   │         │  - Normal   │
│  65th %ile     │            │  Rapid gain      │         │             │
└────────────────┘            └──────────────────┘         └─────────────┘
```

### **1.4 Storage Strategy**

```
Firestore Collections:
├─ babies/{babyId}/measurements/{measurementId}     (Individual measurements)
├─ babies/{babyId}/growth_stats/monthly/{month}     (Monthly summaries)
├─ babies/{babyId}/growth_alerts/{alertId}          (Growth alerts)
└─ reference_data/who_charts/{chartType}            (WHO standard data)

Assets (Local):
├─ assets/who_charts/weight_for_age_boys.json
├─ assets/who_charts/weight_for_age_girls.json
├─ assets/who_charts/length_for_age_boys.json
├─ assets/who_charts/length_for_age_girls.json
├─ assets/who_charts/head_circumference_boys.json
└─ assets/who_charts/head_circumference_girls.json

Data Retention:
- Measurements: Permanent
- Growth stats: Permanent
- Alerts: Permanent
```

---

## 2️⃣ WHO GROWTH CHARTS

### **2.1 WHO LMS Method**

WHO uses the **LMS method** (Lambda-Mu-Sigma) to calculate percentiles:

```dart
// LMS Parameters
// L = Box-Cox power (skewness)
// M = Median
// S = Coefficient of variation

// Calculate Z-score:
Z = ((value/M)^L - 1) / (L * S)

// Calculate Percentile:
Percentile = normalCDF(Z) * 100

// Example for 6-month-old boy weighing 8.0 kg:
// From WHO data: L=0.3809, M=7.934, S=0.12464
Z = ((8.0/7.934)^0.3809 - 1) / (0.3809 * 0.12464)
Z = 0.175
Percentile = 56.9th
```

### **2.2 WHO Chart Data Structure**

```json
// assets/who_charts/weight_for_age_boys.json
{
  "chart_type": "weight_for_age",
  "sex": "boys",
  "unit": "kg",
  "age_range": "0-60 months",
  "data": [
    {
      "age_months": 0,
      "L": 0.3809,
      "M": 3.3464,
      "S": 0.14602,
      "P3": 2.5,
      "P15": 2.9,
      "P50": 3.3,
      "P85": 3.9,
      "P97": 4.4
    },
    {
      "age_months": 1,
      "L": 0.1714,
      "M": 4.4709,
      "S": 0.13395,
      "P3": 3.4,
      "P15": 3.9,
      "P50": 4.5,
      "P85": 5.1,
      "P97": 5.8
    }
    // ... data for each month 0-60
  ]
}
```

### **2.3 Percentile Categories**

```
WHO Categories:
├─ Severe Underweight: <3rd percentile
├─ Underweight: 3rd-15th percentile
├─ Normal: 15th-85th percentile
├─ At Risk of Overweight: 85th-97th percentile
└─ Overweight: >97th percentile

Growth Velocity Alerts:
├─ Crossing down 2 major percentile lines (e.g., 75th → 25th)
├─ Crossing up 2 major percentile lines (rapid gain)
├─ Weight gain <5g/day (0-3 months)
├─ Weight gain <3g/day (3-6 months)
└─ No growth for 2+ months
```

---

## 3️⃣ DATA MODELS

### **3.1 Firestore Schema**

```typescript
// ═══════════════════════════════════════════════════════════
// Firestore Document Schemas
// ═══════════════════════════════════════════════════════════

// Collection: babies/{babyId}/measurements/{measurementId}
interface GrowthMeasurementDocument {
  id: string;
  babyId: string;
  
  // Measurement date
  measuredAt: FirebaseFirestore.Timestamp;
  ageMonths: number;      // Calculated from birthdate
  ageDays: number;
  
  // Measurements
  weightKg?: number;
  weightLbs?: number;
  lengthCm?: number;      // <2 years: length (lying down)
  heightCm?: number;      // 2+ years: height (standing)
  lengthInches?: number;
  headCircumferenceCm?: number;
  headCircumferenceInches?: number;
  
  // Calculated metrics
  bmi?: number;           // For 2+ years
  
  // WHO Percentiles (calculated by Cloud Function)
  percentiles?: {
    weightForAge?: number;      // e.g., 65.2
    lengthForAge?: number;
    heightForAge?: number;
    headCircumference?: number;
    bmiForAge?: number;
    weightForLength?: number;   // 0-2 years
    weightForHeight?: number;   // 2-5 years
  };
  
  // WHO Z-scores
  zScores?: {
    weightForAge?: number;
    lengthForAge?: number;
    headCircumference?: number;
  };
  
  // Categories
  categories?: {
    weightCategory?: 'severe_underweight' | 'underweight' | 'normal' | 'at_risk_overweight' | 'overweight';
    heightCategory?: 'stunted' | 'normal' | 'tall';
    headCategory?: 'small' | 'normal' | 'large';
  };
  
  // Context
  location?: 'home' | 'clinic' | 'hospital' | 'other';
  measuredBy?: string;    // 'parent', 'pediatrician', 'nurse'
  notes?: string;
  
  // Metadata
  loggedBy: string;       // userId
  loggedAt: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/growth_stats/monthly/{month}
interface MonthlyGrowthStats {
  babyId: string;
  month: string;          // YYYY-MM
  ageMonths: number;
  
  // Measurements summary
  measurementCount: number;
  
  // Weight
  weight?: {
    startKg: number;
    endKg: number;
    gainKg: number;
    gainPercent: number;
    averagePercentile: number;
  };
  
  // Length/Height
  lengthHeight?: {
    startCm: number;
    endCm: number;
    growthCm: number;
    growthPercent: number;
    averagePercentile: number;
  };
  
  // Head circumference
  headCircumference?: {
    startCm: number;
    endCm: number;
    growthCm: number;
    averagePercentile: number;
  };
  
  // Growth velocity
  velocity: {
    weightGPerDay: number;      // grams/day
    lengthCmPerMonth: number;
    headCmPerMonth: number;
  };
  
  // Trends
  trends: {
    weightTrend: 'declining' | 'stable' | 'increasing' | 'rapid';
    heightTrend: 'slow' | 'normal' | 'fast';
    percentileTrend: 'falling' | 'stable' | 'rising';
  };
  
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

// Collection: babies/{babyId}/growth_alerts/{alertId}
interface GrowthAlertDocument {
  id: string;
  babyId: string;
  
  // Alert type
  alertType: 'falling_percentile' | 'rising_percentile' | 'slow_velocity' | 
             'rapid_gain' | 'underweight' | 'overweight' | 'stunted' | 'no_growth';
  severity: 'info' | 'warning' | 'critical';
  
  // Alert details
  title: string;
  message: string;
  
  // Supporting data
  data?: {
    previousPercentile?: number;
    currentPercentile?: number;
    percentileChange?: number;
    velocity?: number;
    expectedVelocity?: number;
  };
  
  // Recommendations
  recommendation: string;
  requiresPediatricianVisit: boolean;
  
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
```

### **3.2 Flutter Dart Models**

```dart
// ═══════════════════════════════════════════════════════════
// lib/models/growth_measurement_model.dart
// ═══════════════════════════════════════════════════════════

class GrowthMeasurementModel {
  final String id;
  final String babyId;
  final DateTime measuredAt;
  final int ageMonths;
  final int ageDays;
  
  // Measurements
  final double? weightKg;
  final double? lengthCm;
  final double? heightCm;
  final double? headCircumferenceCm;
  final double? bmi;
  
  // WHO Percentiles
  final GrowthPercentiles? percentiles;
  final GrowthZScores? zScores;
  final GrowthCategories? categories;
  
  // Context
  final String? location;
  final String? measuredBy;
  final String? notes;
  
  // Metadata
  final String loggedBy;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  GrowthMeasurementModel({
    required this.id,
    required this.babyId,
    required this.measuredAt,
    required this.ageMonths,
    required this.ageDays,
    this.weightKg,
    this.lengthCm,
    this.heightCm,
    this.headCircumferenceCm,
    this.bmi,
    this.percentiles,
    this.zScores,
    this.categories,
    this.location,
    this.measuredBy,
    this.notes,
    required this.loggedBy,
    required this.loggedAt,
    required this.createdAt,
    this.updatedAt,
  });
  
  // Display helpers
  String get ageDisplay {
    if (ageMonths < 12) {
      return '$ageMonths months';
    } else {
      final years = ageMonths ~/ 12;
      final months = ageMonths % 12;
      return months > 0 ? '$years yr $months mo' : '$years yr';
    }
  }
  
  String get weightDisplay {
    if (weightKg == null) return '--';
    final lbs = weightKg! * 2.20462;
    return '${weightKg!.toStringAsFixed(2)} kg (${lbs.toStringAsFixed(1)} lbs)';
  }
  
  String get heightDisplay {
    final cm = lengthCm ?? heightCm;
    if (cm == null) return '--';
    final inches = cm / 2.54;
    return '${cm.toStringAsFixed(1)} cm (${inches.toStringAsFixed(1)} in)';
  }
  
  String get headDisplay {
    if (headCircumferenceCm == null) return '--';
    final inches = headCircumferenceCm! / 2.54;
    return '${headCircumferenceCm!.toStringAsFixed(1)} cm (${inches.toStringAsFixed(1)} in)';
  }
  
  bool get hasGrowthConcern {
    if (categories == null) return false;
    
    if (categories!.weightCategory == 'severe_underweight' ||
        categories!.weightCategory == 'underweight' ||
        categories!.weightCategory == 'overweight') {
      return true;
    }
    
    if (categories!.heightCategory == 'stunted') return true;
    
    return false;
  }
  
  factory GrowthMeasurementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GrowthMeasurementModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      measuredAt: (data['measuredAt'] as Timestamp).toDate(),
      ageMonths: data['ageMonths'] ?? 0,
      ageDays: data['ageDays'] ?? 0,
      weightKg: data['weightKg']?.toDouble(),
      lengthCm: data['lengthCm']?.toDouble(),
      heightCm: data['heightCm']?.toDouble(),
      headCircumferenceCm: data['headCircumferenceCm']?.toDouble(),
      bmi: data['bmi']?.toDouble(),
      percentiles: data['percentiles'] != null
          ? GrowthPercentiles.fromMap(data['percentiles'])
          : null,
      zScores: data['zScores'] != null
          ? GrowthZScores.fromMap(data['zScores'])
          : null,
      categories: data['categories'] != null
          ? GrowthCategories.fromMap(data['categories'])
          : null,
      location: data['location'],
      measuredBy: data['measuredBy'],
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
      'measuredAt': Timestamp.fromDate(measuredAt),
      'ageMonths': ageMonths,
      'ageDays': ageDays,
      'weightKg': weightKg,
      'weightLbs': weightKg != null ? weightKg! * 2.20462 : null,
      'lengthCm': lengthCm,
      'heightCm': heightCm,
      'lengthInches': (lengthCm ?? heightCm) != null ? (lengthCm ?? heightCm)! / 2.54 : null,
      'headCircumferenceCm': headCircumferenceCm,
      'headCircumferenceInches': headCircumferenceCm != null ? headCircumferenceCm! / 2.54 : null,
      'bmi': bmi,
      'percentiles': percentiles?.toMap(),
      'zScores': zScores?.toMap(),
      'categories': categories?.toMap(),
      'location': location,
      'measuredBy': measuredBy,
      'notes': notes,
      'loggedBy': loggedBy,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

// ═══════════════════════════════════════════════════════════
// Supporting Classes
// ═══════════════════════════════════════════════════════════

class GrowthPercentiles {
  final double? weightForAge;
  final double? lengthForAge;
  final double? heightForAge;
  final double? headCircumference;
  final double? bmiForAge;
  final double? weightForLength;
  final double? weightForHeight;
  
  GrowthPercentiles({
    this.weightForAge,
    this.lengthForAge,
    this.heightForAge,
    this.headCircumference,
    this.bmiForAge,
    this.weightForLength,
    this.weightForHeight,
  });
  
  String formatPercentile(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)}th';
  }
  
  factory GrowthPercentiles.fromMap(Map<String, dynamic> map) {
    return GrowthPercentiles(
      weightForAge: map['weightForAge']?.toDouble(),
      lengthForAge: map['lengthForAge']?.toDouble(),
      heightForAge: map['heightForAge']?.toDouble(),
      headCircumference: map['headCircumference']?.toDouble(),
      bmiForAge: map['bmiForAge']?.toDouble(),
      weightForLength: map['weightForLength']?.toDouble(),
      weightForHeight: map['weightForHeight']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'weightForAge': weightForAge,
      'lengthForAge': lengthForAge,
      'heightForAge': heightForAge,
      'headCircumference': headCircumference,
      'bmiForAge': bmiForAge,
      'weightForLength': weightForLength,
      'weightForHeight': weightForHeight,
    };
  }
}

class GrowthZScores {
  final double? weightForAge;
  final double? lengthForAge;
  final double? headCircumference;
  
  GrowthZScores({
    this.weightForAge,
    this.lengthForAge,
    this.headCircumference,
  });
  
  factory GrowthZScores.fromMap(Map<String, dynamic> map) {
    return GrowthZScores(
      weightForAge: map['weightForAge']?.toDouble(),
      lengthForAge: map['lengthForAge']?.toDouble(),
      headCircumference: map['headCircumference']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'weightForAge': weightForAge,
      'lengthForAge': lengthForAge,
      'headCircumference': headCircumference,
    };
  }
}

class GrowthCategories {
  final String? weightCategory;
  final String? heightCategory;
  final String? headCategory;
  
  GrowthCategories({
    this.weightCategory,
    this.heightCategory,
    this.headCategory,
  });
  
  factory GrowthCategories.fromMap(Map<String, dynamic> map) {
    return GrowthCategories(
      weightCategory: map['weightCategory'],
      heightCategory: map['heightCategory'],
      headCategory: map['headCategory'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'weightCategory': weightCategory,
      'heightCategory': heightCategory,
      'headCategory': headCategory,
    };
  }
}
```

---

## 4️⃣ CLOUD FUNCTIONS

```typescript
// ═══════════════════════════════════════════════════════════
// functions/src/onMeasurementCreate.ts
// ═══════════════════════════════════════════════════════════

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { calculateWHOPercentile, calculateZScore } from './whoCalculations';

const db = admin.firestore();

export const onMeasurementCreate = functions.firestore
  .document('babies/{babyId}/measurements/{measurementId}')
  .onCreate(async (snap, context) => {
    
    const measurement = snap.data();
    const { babyId } = context.params;
    
    console.log(`[onMeasurementCreate] Baby: ${babyId}, Age: ${measurement.ageMonths} months`);
    
    try {
      // Get baby gender for WHO charts
      const babyDoc = await db.collection('babies').doc(babyId).get();
      const sex = babyDoc.data()?.gender || 'male';  // 'male' or 'female'
      
      // Calculate WHO percentiles and Z-scores
      const percentiles = await calculatePercentiles(measurement, sex);
      const zScores = await calculateZScores(measurement, sex);
      const categories = categorizeGrowth(percentiles, zScores);
      
      // Update measurement with calculated values
      await snap.ref.update({
        percentiles,
        zScores,
        categories,
        updatedAt: admin.firestore.Timestamp.now(),
      });
      
      // Check for growth alerts
      await checkGrowthAlerts(babyId, measurement, percentiles);
      
      // Update monthly stats
      await updateMonthlyStats(babyId, measurement);
      
    } catch (error) {
      console.error('[onMeasurementCreate] Error:', error);
    }
  });

// ═══════════════════════════════════════════════════════════
// Calculate Percentiles
// ═══════════════════════════════════════════════════════════

async function calculatePercentiles(measurement: any, sex: string): Promise<any> {
  const percentiles: any = {};
  
  // Weight-for-age
  if (measurement.weightKg) {
    percentiles.weightForAge = await calculateWHOPercentile(
      'weight_for_age',
      sex,
      measurement.ageMonths,
      measurement.weightKg
    );
  }
  
  // Length/Height-for-age
  if (measurement.lengthCm || measurement.heightCm) {
    const lengthHeight = measurement.lengthCm || measurement.heightCm;
    percentiles.lengthForAge = await calculateWHOPercentile(
      measurement.ageMonths < 24 ? 'length_for_age' : 'height_for_age',
      sex,
      measurement.ageMonths,
      lengthHeight
    );
  }
  
  // Head circumference-for-age
  if (measurement.headCircumferenceCm) {
    percentiles.headCircumference = await calculateWHOPercentile(
      'head_circumference_for_age',
      sex,
      measurement.ageMonths,
      measurement.headCircumferenceCm
    );
  }
  
  // BMI-for-age (for 2+ years)
  if (measurement.bmi && measurement.ageMonths >= 24) {
    percentiles.bmiForAge = await calculateWHOPercentile(
      'bmi_for_age',
      sex,
      measurement.ageMonths,
      measurement.bmi
    );
  }
  
  // Weight-for-length/height
  if (measurement.weightKg && (measurement.lengthCm || measurement.heightCm)) {
    const lengthHeight = measurement.lengthCm || measurement.heightCm;
    percentiles.weightForLength = await calculateWHOPercentile(
      measurement.ageMonths < 24 ? 'weight_for_length' : 'weight_for_height',
      sex,
      lengthHeight,  // Use length/height as x-axis
      measurement.weightKg
    );
  }
  
  return percentiles;
}

// ═══════════════════════════════════════════════════════════
// Calculate Z-Scores
// ═══════════════════════════════════════════════════════════

async function calculateZScores(measurement: any, sex: string): Promise<any> {
  const zScores: any = {};
  
  if (measurement.weightKg) {
    zScores.weightForAge = await calculateZScore(
      'weight_for_age',
      sex,
      measurement.ageMonths,
      measurement.weightKg
    );
  }
  
  if (measurement.lengthCm || measurement.heightCm) {
    const lengthHeight = measurement.lengthCm || measurement.heightCm;
    zScores.lengthForAge = await calculateZScore(
      measurement.ageMonths < 24 ? 'length_for_age' : 'height_for_age',
      sex,
      measurement.ageMonths,
      lengthHeight
    );
  }
  
  if (measurement.headCircumferenceCm) {
    zScores.headCircumference = await calculateZScore(
      'head_circumference_for_age',
      sex,
      measurement.ageMonths,
      measurement.headCircumferenceCm
    );
  }
  
  return zScores;
}

// ═══════════════════════════════════════════════════════════
// Categorize Growth
// ═══════════════════════════════════════════════════════════

function categorizeGrowth(percentiles: any, zScores: any): any {
  const categories: any = {};
  
  // Weight category
  if (percentiles.weightForAge) {
    if (percentiles.weightForAge < 3) {
      categories.weightCategory = 'severe_underweight';
    } else if (percentiles.weightForAge < 15) {
      categories.weightCategory = 'underweight';
    } else if (percentiles.weightForAge <= 85) {
      categories.weightCategory = 'normal';
    } else if (percentiles.weightForAge <= 97) {
      categories.weightCategory = 'at_risk_overweight';
    } else {
      categories.weightCategory = 'overweight';
    }
  }
  
  // Height category
  if (zScores.lengthForAge) {
    if (zScores.lengthForAge < -2) {
      categories.heightCategory = 'stunted';
    } else if (zScores.lengthForAge > 2) {
      categories.heightCategory = 'tall';
    } else {
      categories.heightCategory = 'normal';
    }
  }
  
  // Head category
  if (percentiles.headCircumference) {
    if (percentiles.headCircumference < 3) {
      categories.headCategory = 'small';
    } else if (percentiles.headCircumference > 97) {
      categories.headCategory = 'large';
    } else {
      categories.headCategory = 'normal';
    }
  }
  
  return categories;
}

// ═══════════════════════════════════════════════════════════
// Check Growth Alerts
// ═══════════════════════════════════════════════════════════

async function checkGrowthAlerts(
  babyId: string,
  currentMeasurement: any,
  currentPercentiles: any
): Promise<void> {
  
  // Get previous measurement
  const prevMeasurementSnapshot = await db
    .collection('babies')
    .doc(babyId)
    .collection('measurements')
    .where('measuredAt', '<', currentMeasurement.measuredAt)
    .orderBy('measuredAt', 'desc')
    .limit(1)
    .get();
  
  if (prevMeasurementSnapshot.empty) return;
  
  const prevMeasurement = prevMeasurementSnapshot.docs[0].data();
  const prevPercentiles = prevMeasurement.percentiles;
  
  if (!prevPercentiles) return;
  
  // Check for falling percentile (crossing down 2 major lines)
  if (currentPercentiles.weightForAge && prevPercentiles.weightForAge) {
    const drop = prevPercentiles.weightForAge - currentPercentiles.weightForAge;
    
    if (drop >= 30) {  // Crossed 2 major percentile lines
      await createGrowthAlert(
        babyId,
        'falling_percentile',
        'Falling Weight Percentile',
        `Weight dropped from ${prevPercentiles.weightForAge.toFixed(0)}th to ${currentPercentiles.weightForAge.toFixed(0)}th percentile.`,
        'warning',
        true,
        {
          previousPercentile: prevPercentiles.weightForAge,
          currentPercentile: currentPercentiles.weightForAge,
          percentileChange: drop,
        }
      );
    }
  }
  
  // Check growth velocity
  const monthsDiff = currentMeasurement.ageMonths - prevMeasurement.ageMonths;
  
  if (monthsDiff > 0 && currentMeasurement.weightKg && prevMeasurement.weightKg) {
    const weightGain = (currentMeasurement.weightKg - prevMeasurement.weightKg) * 1000;  // grams
    const daysElapsed = monthsDiff * 30;
    const gramsPerDay = weightGain / daysElapsed;
    
    // Expected weight gain (varies by age)
    let expectedGramsPerDay = 20;
    if (currentMeasurement.ageMonths <= 3) {
      expectedGramsPerDay = 25;
    } else if (currentMeasurement.ageMonths <= 6) {
      expectedGramsPerDay = 15;
    } else if (currentMeasurement.ageMonths <= 12) {
      expectedGramsPerDay = 10;
    }
    
    if (gramsPerDay < expectedGramsPerDay * 0.5) {  // Less than 50% of expected
      await createGrowthAlert(
        babyId,
        'slow_velocity',
        'Slow Weight Gain',
        `Weight gain is ${gramsPerDay.toFixed(1)}g/day (expected: ${expectedGramsPerDay}g/day).`,
        'warning',
        true,
        {
          velocity: gramsPerDay,
          expectedVelocity: expectedGramsPerDay,
        }
      );
    }
  }
}

async function createGrowthAlert(
  babyId: string,
  alertType: string,
  title: string,
  message: string,
  severity: string,
  requiresPediatricianVisit: boolean,
  data?: any
): Promise<void> {
  
  await db
    .collection('babies')
    .doc(babyId)
    .collection('growth_alerts')
    .add({
      babyId,
      alertType,
      severity,
      title,
      message,
      data,
      recommendation: requiresPediatricianVisit 
        ? 'Schedule pediatrician visit' 
        : 'Continue monitoring',
      requiresPediatricianVisit,
      status: 'active',
      notificationSent: false,
      triggeredAt: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now(),
    });
  
  // Send notification
  if (severity === 'warning' || severity === 'critical') {
    await sendGrowthAlert(babyId, title, message);
  }
}

async function sendGrowthAlert(babyId: string, title: string, message: string): Promise<void> {
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
    notification: { title: `📏 ${title}`, body: message },
    data: { type: 'growth_alert', babyId },
  });
}

async function updateMonthlyStats(babyId: string, measurement: any): Promise<void> {
  const month = new Date(measurement.measuredAt.toDate()).toISOString().slice(0, 7);  // YYYY-MM
  
  // Implementation: Calculate monthly growth velocity, trends, etc.
  // Similar to daily stats aggregation
}
```

---

## 5️⃣ FLUTTER IMPLEMENTATION

```dart
// ═══════════════════════════════════════════════════════════
// lib/services/growth_service.dart
// ═══════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/growth_measurement_model.dart';

class GrowthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Log new measurement
  Future<String> logMeasurement({
    required String babyId,
    required String userId,
    required DateTime measuredAt,
    required DateTime birthDate,
    double? weightKg,
    double? lengthCm,
    double? heightCm,
    double? headCircumferenceCm,
    String? location,
    String? measuredBy,
    String? notes,
  }) async {
    
    // Calculate age
    final ageMonths = _calculateAgeMonths(birthDate, measuredAt);
    final ageDays = measuredAt.difference(birthDate).inDays;
    
    // Calculate BMI if applicable (for 2+ years with height and weight)
    double? bmi;
    if (ageMonths >= 24 && weightKg != null && (lengthCm != null || heightCm != null)) {
      final heightM = (heightCm ?? lengthCm)! / 100;
      bmi = weightKg / (heightM * heightM);
    }
    
    final measurement = GrowthMeasurementModel(
      id: '',
      babyId: babyId,
      measuredAt: measuredAt,
      ageMonths: ageMonths,
      ageDays: ageDays,
      weightKg: weightKg,
      lengthCm: lengthCm,
      heightCm: heightCm,
      headCircumferenceCm: headCircumferenceCm,
      bmi: bmi,
      loggedBy: userId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
      location: location,
      measuredBy: measuredBy,
      notes: notes,
    );
    
    final docRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('measurements')
        .add(measurement.toMap());
    
    return docRef.id;
  }
  
  /// Stream all measurements
  Stream<List<GrowthMeasurementModel>> streamMeasurements(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('measurements')
        .orderBy('measuredAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GrowthMeasurementModel.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get latest measurement
  Future<GrowthMeasurementModel?> getLatestMeasurement(String babyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('measurements')
        .orderBy('measuredAt', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    return GrowthMeasurementModel.fromFirestore(snapshot.docs.first);
  }
  
  int _calculateAgeMonths(DateTime birthDate, DateTime measureDate) {
    int months = (measureDate.year - birthDate.year) * 12;
    months += measureDate.month - birthDate.month;
    return months;
  }
}
```

---

## 6️⃣ GROWTH CHARTS VISUALIZATION

```dart
// ═══════════════════════════════════════════════════════════
// lib/widgets/growth/growth_chart_widget.dart
// ═══════════════════════════════════════════════════════════

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GrowthChartWidget extends StatelessWidget {
  final List<GrowthMeasurementModel> measurements;
  final String chartType;  // 'weight', 'length', 'head'
  final String sex;
  
  const GrowthChartWidget({
    required this.measurements,
    required this.chartType,
    required this.sex,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getChartTitle(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: LineChart(
                _buildChartData(),
              ),
            ),
            SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }
  
  String _getChartTitle() {
    switch (chartType) {
      case 'weight':
        return 'Weight-for-Age';
      case 'length':
        return 'Length/Height-for-Age';
      case 'head':
        return 'Head Circumference-for-Age';
      default:
        return 'Growth Chart';
    }
  }
  
  LineChartData _buildChartData() {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        // WHO Percentile curves
        _buildPercentileCurve(97, Colors.red.withOpacity(0.3)),
        _buildPercentileCurve(85, Colors.orange.withOpacity(0.3)),
        _buildPercentileCurve(50, Colors.blue.withOpacity(0.3)),
        _buildPercentileCurve(15, Colors.orange.withOpacity(0.3)),
        _buildPercentileCurve(3, Colors.red.withOpacity(0.3)),
        
        // Baby's actual measurements
        _buildMeasurementCurve(),
      ],
    );
  }
  
  LineChartBarData _buildPercentileCurve(int percentile, Color color) {
    // Load WHO data from assets and create curve
    // This would use the JSON data from assets/who_charts/
    return LineChartBarData(
      spots: _getWHOPercentileSpots(percentile),
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
    );
  }
  
  LineChartBarData _buildMeasurementCurve() {
    final spots = measurements.map((m) {
      double yValue = 0;
      switch (chartType) {
        case 'weight':
          yValue = m.weightKg ?? 0;
          break;
        case 'length':
          yValue = (m.lengthCm ?? m.heightCm) ?? 0;
          break;
        case 'head':
          yValue = m.headCircumferenceCm ?? 0;
          break;
      }
      
      return FlSpot(m.ageMonths.toDouble(), yValue);
    }).toList();
    
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: Colors.purple,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true),
    );
  }
  
  List<FlSpot> _getWHOPercentileSpots(int percentile) {
    // Load from assets/who_charts/{chartType}_{sex}.json
    // Return list of FlSpot(ageMonths, value)
    return [];  // Placeholder
  }
  
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('97th', Colors.red),
        _buildLegendItem('85th', Colors.orange),
        _buildLegendItem('50th', Colors.blue),
        _buildLegendItem('15th', Colors.orange),
        _buildLegendItem('3rd', Colors.red),
        _buildLegendItem('Baby', Colors.purple),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          color: color,
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
```

---

## 7️⃣ IMPLEMENTATION ROADMAP

### **Phase 1: WHO Chart Data (Week 1)**
- [ ] Download WHO LMS data files
- [ ] Convert to JSON format
- [ ] Add to assets folder
- [ ] Create WHO calculation utilities
- [ ] Test percentile calculations

### **Phase 2: Models & Service (Week 1)**
- [ ] Create GrowthMeasurementModel
- [ ] Create GrowthPercentiles, ZScores, Categories models
- [ ] Implement GrowthService
- [ ] Add unit tests

### **Phase 3: Cloud Functions (Week 2)**
- [ ] Implement onMeasurementCreate
- [ ] Add percentile/Z-score calculations
- [ ] Add growth alert detection
- [ ] Test with sample data

### **Phase 4: UI & Charts (Week 2-3)**
- [ ] Create measurement entry screen
- [ ] Build growth chart widget (fl_chart)
- [ ] Create measurement timeline
- [ ] Add percentile display
- [ ] Implement alert notifications

### **Phase 5: Export & Reports (Week 3)**
- [ ] Generate PDF reports
- [ ] Include all measurements
- [ ] Add growth charts to PDF
- [ ] Test export functionality

---

## ✅ SUCCESS METRICS

- [ ] Percentile calculations match WHO standards (±0.5%)
- [ ] Growth charts display correctly with curves
- [ ] Alerts triggered for falling percentiles
- [ ] Export PDF includes all data + charts
- [ ] Measurement entry takes <60 seconds
- [ ] Charts render smoothly (60 FPS)

---

**Ready to implement!** Start with Phase 1 (WHO Chart Data). 📏

