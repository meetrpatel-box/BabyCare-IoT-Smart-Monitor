# Colic Pattern Detection — Low-Level Design (LLD)

**Document ID**: LLD-COLIC-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19
**Feature**: Colic Pattern Analysis using Wessel's Criteria

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Wessel's Criteria](#2-wessels-criteria)
3. [Data Models](#3-data-models)
4. [Analysis Engine](#4-analysis-engine)
5. [Cloud Functions](#5-cloud-functions)
6. [Flutter Service](#6-flutter-service)
7. [Flutter UI](#7-flutter-ui)
8. [Test Coverage](#8-test-coverage)
9. [File Map](#9-file-map)
10. [Related Documents](#10-related-documents)

---

## 1. Overview

### 1.1 Purpose

Analyze cry event history to detect colic patterns using modified Wessel's criteria. Provides risk assessment, daily/weekly breakdowns, streak tracking, and actionable suggestions for parents.

### 1.2 Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| Daily analysis | Crying minutes, episodes, peak hours per day | 🟢 Complete |
| Weekly summaries | Days over threshold, Wessel's criteria check | 🟢 Complete |
| Risk scoring | 0–100 score with 4 risk levels | 🟢 Complete |
| Streak tracking | Current + longest consecutive days | 🟢 Complete |
| Suggestions | Risk-appropriate guidance for parents | 🟢 Complete |
| Scheduled analysis | Daily automated run at 3 AM UTC | 🟢 Complete |
| On-demand analysis | User-triggered via Cloud Function | 🟢 Complete |
| Analytics UI | Risk card, charts, weekly cards, suggestions | 🟢 Complete |

---

## 2. Wessel's Criteria

The classic definition of infant colic (Wessel 1954):

```
Crying ≥ 3 hours per day
      ≥ 3 days per week
      ≥ 3 weeks duration
```

### 2.1 Modified Implementation

The system uses a modified approach for **early detection**:

| Criterion | Wessel's | Our Implementation |
|-----------|----------|-------------------|
| Hours/day | 3+ hours | 180+ minutes of total crying |
| Days/week | 3+ days | 3+ days over threshold in ISO week (Mon–Sun) |
| Weeks | 3+ weeks | Tracked but not required — risk escalates progressively |

**Colic episode detection**: An episode counts as "colic" if:
- Classification is `colic`, OR
- Duration > 180 seconds AND intensity > 0.5

---

## 3. Data Models

### 3.1 Cloud Types (`colicPatternDetector.ts`)

```typescript
interface ColicDayAnalysis {
  date: string;                    // "YYYY-MM-DD"
  totalCryingMinutes: number;
  colicCryingMinutes: number;
  totalEpisodes: number;
  colicEpisodes: number;
  longestEpisodeMinutes: number;
  peakHour: number;                // 0–23, -1 if no events
  avgIntensity: number;            // 0.0–1.0
  meetsThreshold: boolean;         // >= 180 min
}

interface ColicWeekSummary {
  weekStart: string;               // Monday ISO date
  daysOverThreshold: number;
  totalCryingMinutes: number;
  avgDailyCryingMinutes: number;
  meetsWessel: boolean;            // 3+ days over threshold
}

interface ColicPatternResult {
  babyId: string;
  analysisDate: string;
  dailyAnalysis: ColicDayAnalysis[];
  weeklySummaries: ColicWeekSummary[];
  currentStreak: number;
  longestStreak: number;
  wesselWeeksCount: number;
  riskLevel: "none" | "mild" | "moderate" | "severe";
  riskScore: number;               // 0–100
  suggestions: string[];
}
```

### 3.2 Flutter Models (`colic_pattern_model.dart`)

```dart
enum ColicRiskLevel {
  none, mild, moderate, severe;

  String get label => switch (this) {
    ColicRiskLevel.none => 'No Risk',
    ColicRiskLevel.mild => 'Mild',
    ColicRiskLevel.moderate => 'Moderate',
    ColicRiskLevel.severe => 'Severe',
  };
}
```

Full model classes: `ColicDayAnalysis`, `ColicWeekSummary`, `ColicPatternResult` — all with `fromMap()` factory constructors for Firestore deserialization.

---

## 4. Analysis Engine

### 4.1 Algorithm Flow

```
analyzeColicPatterns(babyId, lookbackDays=21)
│
├── 1. Fetch cry events in lookback window
│   └── babies/{babyId}/cryEvents where startTime >= cutoff
│
├── 2. Group events by day (YYYY-MM-DD)
│
├── 3. Analyze each day → ColicDayAnalysis[]
│   ├── Sum crying duration (durationSeconds or estimateDuration)
│   ├── Count colic episodes (classification == "colic" OR long+intense)
│   ├── Find peak hour from startTime distribution
│   ├── Compute average intensity
│   └── Check threshold: totalCryingMinutes >= 180
│
├── 4. Compute weekly summaries → ColicWeekSummary[]
│   ├── Group days by ISO week (Monday start)
│   ├── Count days over threshold per week
│   └── Check Wessel's: daysOverThreshold >= 3
│
├── 5. Compute streaks
│   ├── currentStreak: consecutive days from end
│   └── longestStreak: max consecutive days
│
├── 6. Compute risk level → { riskLevel, riskScore }
│
└── 7. Generate suggestions based on risk + patterns
```

### 4.2 Risk Score Formula

```
score = 0
+ (recent_days_over_in_last_7 * 10)           // 0–70
+ min(current_streak * 5, 15)                   // 0–15
+ min(wessel_weeks_count * 10, 30)              // 0–30
+ (avg_recent_crying > 240min ? 10 : > 180min ? 5 : 0)  // 0–10
= capped at 100
```

| Score Range | Risk Level | Meaning |
|------------|------------|---------|
| 0–14 | `none` | Normal crying patterns |
| 15–39 | `mild` | Some elevated crying, monitor |
| 40–69 | `moderate` | Consult pediatrician |
| 70–100 | `severe` | Matches Wessel's criteria |

### 4.3 Duration Estimation

For events without `endTime`, a default of 5 minutes (300 seconds) is used. For events with `endTime`, duration is computed as `endTime - startTime`.

### 4.4 Suggestions Engine

| Risk Level | Example Suggestions |
|-----------|-------------------|
| `none` | "No colic patterns detected. Baby's crying is within normal range." |
| `mild` | "Monitor over the next few days." + soothing techniques |
| `moderate` | "Consider discussing with your pediatrician." + feeding patterns + "5 S" method |
| `severe` | "Consult your pediatrician." + "Colic peaks at 6 weeks, resolves by 3-4 months." + self-care |

**Time-specific**: If 3+ of last 7 days have peak crying between 5–10 PM → "Evening fussiness (witching hour) pattern detected."

---

## 5. Cloud Functions

### 5.1 detectColicPatterns (Callable)

- **Auth**: Authenticated
- **Input**: `{ babyId, lookbackDays? }`
- **Output**: `ColicPatternResult`
- **Side effect**: Stores result in `babies/{babyId}/colicPatterns/{date}`

### 5.2 scheduledColicAnalysis (Scheduled)

- **Schedule**: `0 3 * * *` (daily 3 AM UTC)
- **Process**: Iterates all babies with cry events in last 7 days
- **Side effect**: Stores results + updates `latestVitals` for moderate/severe

```typescript
// Denormalization for quick dashboard access
if (result.riskLevel === "moderate" || result.riskLevel === "severe") {
  await db.collection("babies").doc(babyId).update({
    "latestVitals.colicRiskLevel": result.riskLevel,
    "latestVitals.colicRiskScore": result.riskScore,
    "latestVitals.colicAnalyzedAt": serverTimestamp(),
  });
}
```

---

## 6. Flutter Service

### 6.1 ColicPatternService (`colic_pattern_service.dart`)

| Method | Return | Description |
|--------|--------|-------------|
| `getLatestAnalysis(babyId)` | `ColicPatternResult?` | Most recent analysis from Firestore |
| `getAnalysisHistory(babyId, limit)` | `List<ColicPatternResult>` | Historical analyses (desc order) |
| `streamLatestAnalysis(babyId)` | `Stream<ColicPatternResult?>` | Real-time updates |
| `runAnalysis(babyId, lookbackDays?)` | `ColicPatternResult` | Trigger Cloud Function |
| `getQuickRiskLevel(babyId)` | `ColicRiskLevel?` | Read denormalized risk from baby doc |

Uses lazy `_functions` getter to avoid `FirebaseFunctions.instance` initialization in constructor (testability).

---

## 7. Flutter UI

### 7.1 ColicAnalyticsScreen (`colic_analytics_screen.dart` — 480 lines)

| Section | Description |
|---------|-------------|
| **Risk Level Card** | Color-coded card with risk level, score bar, and key stats |
| **Wessel's Criteria Tracker** | 3 criteria rows showing current vs. threshold with check marks |
| **Daily Crying Chart** | Bar chart of last 7 days with 3-hour threshold line |
| **Weekly Summaries** | Cards per week with day count, avg crying, Wessel status |
| **Suggestions Panel** | Risk-appropriate guidance with styled container |
| **Run Analysis Button** | Trigger on-demand Cloud Function analysis |

Color scheme follows risk levels:
- None: Green (`#4CAF50`)
- Mild: Amber (`#FFC107`)
- Moderate: Orange (`#FF9800`)
- Severe: Red (`#F44336`)

---

## 8. Test Coverage

| Test File | Tests | Coverage |
|-----------|-------|---------|
| `colicPatternDetector.test.ts` | 12 | Empty analysis, threshold, risk levels, suggestions, streaks, weekly summaries, peak hours, score cap |
| `colic_pattern_model_test.dart` | 9 | Risk level parsing/labels, fromMap with/without data, full/empty results |
| `colic_pattern_service_test.dart` | 9 | Get latest/history, stream, quick risk level, null handling |
| **Total** | **30** | |

---

## 9. File Map

```
functions/src/
├── colicPatternDetector.ts          # Analysis engine + Cloud Functions
└── __tests__/
    └── colicPatternDetector.test.ts # 12 tests

baby_track_flutter/lib/
├── models/
│   └── colic_pattern_model.dart     # ColicRiskLevel, ColicDayAnalysis, etc.
├── services/
│   └── colic_pattern_service.dart   # Firestore queries + Cloud Function calls
└── screens/cry/
    └── colic_analytics_screen.dart  # Analytics UI

baby_track_flutter/test/unit/
├── models/
│   └── colic_pattern_model_test.dart     # 9 tests
└── services/
    └── colic_pattern_service_test.dart   # 9 tests
```

---

## 10. Related Documents

- [Cry Detection LLD](CRY_DETECTION_LLD.md) — Parent system this builds on
- [4.2 API Reference](../04-backend/4.2-api-reference.md) — `detectColicPatterns` function signature
- [4.3 Firestore Schema](../04-backend/4.3-firestore-schema.md#3-colic-patterns) — Colic patterns collection
- [Model System LLD](MODEL_SYSTEM_LLD.md) — ML model that feeds classification
