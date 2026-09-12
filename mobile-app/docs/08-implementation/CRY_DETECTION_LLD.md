# Cry Detection — Low-Level Design (LLD)

**Document ID**: LLD-CRY-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19
**Feature**: Progressive Multi-Modal Cry Detection Pipeline

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Data Models](#3-data-models)
4. [Service Layer](#4-service-layer)
5. [Cloud Functions](#5-cloud-functions)
6. [BLE Integration](#6-ble-integration)
7. [Push Notifications](#7-push-notifications)
8. [Data Flow](#8-data-flow)
9. [Test Coverage](#9-test-coverage)
10. [File Map](#10-file-map)
11. [Related Documents](#11-related-documents)

---

## 1. Overview

### 1.1 Purpose

The cry detection system provides progressive, multi-modal analysis of baby crying. It detects cries via IoT device, classifies cry types using a 4-tier pipeline, presents actionable alerts to parents, and builds a feedback loop for continuous ML improvement.

### 1.2 Key Features

| Feature | Description | Priority | Status |
|---------|-------------|----------|--------|
| Progressive alerts | Detection → Preliminary → Confirmed → Resolved | P0 | 🟢 Complete |
| 9-type classification | hungry, tired, pain, colic, gassy, discomfort, attention, overstimulated, unknown | P0 | 🟢 Complete |
| Parent feedback | Confirm/correct classifications, log resolution | P0 | 🟢 Complete |
| Passive labeling | Infer cry type from parent actions (feed → hungry) | P0 | 🟢 Complete |
| 3-tier consent | featuresOnly, fullAudio, none | P0 | 🟢 Complete |
| BLE device bridge | Receive cry detections from ESP32 via BLE | P0 | 🟢 Complete |
| FCM push notifications | Background alerts for cry detection + classification | P0 | 🟢 Complete |
| Cloud classification | Heuristic classifier with context fusion | P0 | 🟢 Complete |
| GDPR data deletion | Consent revocation triggers data cleanup | P0 | 🟢 Complete |
| Training data export | JSONL manifest for ML pipeline | P0 | 🟢 Complete |
| Context-aware suggestions | Suggestions based on cry type + sensor context | P0 | 🟢 Complete |

### 1.3 Design Decisions

1. **Features, not raw audio** — Device sends extracted MFCC/mel spectrogram (~2KB) not raw audio (~20KB). Privacy-preserving by default.
2. **Ground truth priority** — `parentCorrectedType` > confirmed `cloudClassification` > unconfirmed. Ensures training data uses the best available label.
3. **Passive labeling** — When parent logs feeding within 15 min of cry event, system infers `hungry`. Dramatically increases labeled data without extra user effort.
4. **Heuristic → ML swap** — `classifyFromFeatures()` is a pure function. When YAMNet is ready, only this function changes. All triggers, alerts, and training pipeline remain unchanged.
5. **Consent at every layer** — `dataConsent` field on every event. Cloud function skips processing if `none`. Revocation triggers deletion.

---

## 2. Architecture

### 2.1 Progressive 4-Tier Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  DEVICE (ESP32-S3 + Mic + Camera)                             │
│                                                                │
│  Tier 1: VAD (Voice Activity Detection)      Latency: <500ms  │
│  - Binary cry/not-cry detector                                 │
│  - Output: BLE broadcast → { intensity, timestamp }           │
│                                                                │
│  Tier 2: Edge Classifier (TFLite)            Latency: 1-3s    │
│  - 8-class cry type classifier                                 │
│  - Output: BLE update → { classification, confidence }        │
│                                                                │
│  Also: Extract audio features (MFCC/mel spectrogram)          │
│  Upload via MQTT/WiFi → Firebase Storage                       │
└───────────────────────┬──────────────────────────────────────┘
                        │ BLE (instant) + WiFi (features)
                        ▼
┌──────────────────────────────────────────────────────────────┐
│  CLOUD (Firebase Cloud Functions)                              │
│                                                                │
│  Tier 3: Cloud Classification                Latency: 3-8s    │
│  - Trigger: onCryAudioUploaded (hasAudioFeatures → true)      │
│  - Loads features from Storage or inline                       │
│  - Runs classifier (heuristic now, YAMNet later)              │
│  - Context fusion with sensor data                             │
│  - Writes cloudClassification + confidence back                │
│                                                                │
│  Also: onConsentRevoked, exportTrainingData                    │
│        onCryEventCreated, onCryClassified (FCM push)          │
└───────────────────────┬──────────────────────────────────────┘
                        │ Firestore real-time
                        ▼
┌──────────────────────────────────────────────────────────────┐
│  APP (Flutter)                                                 │
│                                                                │
│  Tier 4: Progressive Alerts                                    │
│  - T+0.5s: "Baby is crying!" (from BLE)                       │
│  - T+2s:   "Preliminary: Hungry" (from edge)                  │
│  - T+5s:   "Confirmed: Hungry — try feeding" (from cloud)     │
│  - Resolved: "Crying stopped"                                  │
│                                                                │
│  Parent Feedback Loop:                                         │
│  - Confirm / Correct classification → ground truth             │
│  - Passive labeling: feeding action → label "hungry"          │
│  - Consent management (features only / full audio / none)     │
│                                                                │
│  Analytics: trends, peak hours, classification breakdown       │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Alert Tiers

| Tier | Name | Source | Latency | Message Example |
|------|------|--------|---------|-----------------|
| 1 | `detection` | BLE VAD | <500ms | "Baby is crying!" |
| 2 | `preliminary` | BLE Edge TFLite | 1-3s | "Preliminary: Hungry" |
| 3 | `confirmed` | Cloud classifier | 3-8s | "Confirmed: Hungry — try feeding" |
| 4 | `resolved` | BLE / timeout | - | "Crying stopped" |

---

## 3. Data Models

### 3.1 CryEvent Model (`cry_event_model.dart`)

See [4.3 Firestore Schema](../04-backend/4.3-firestore-schema.md#2-cry-events) for full field reference.

Key enums:

```dart
enum CryType { hungry, tired, pain, colic, gassy, discomfort, attention, overstimulated, unknown }
enum ClassificationSource { edge, cloud, heuristic, parentCorrected }
enum CryDataConsent { featuresOnly, fullAudio, none }
enum CryResolution { fed, diaperChange, rocked, held, pacifier, sleep, other, selfResolved }
```

---

## 4. Service Layer

### 4.1 CryDetectionService (`cry_detection_service.dart` — 547 lines)

Progressive lifecycle management:

| Method | Purpose |
|--------|---------|
| `createFromEdgeDetection()` | Create event from BLE VAD detection |
| `updateWithEdgeClassification()` | Update with TFLite classification |
| `updateWithCloudClassification()` | Update with cloud result |
| `endCryEvent()` | Set endTime, compute duration |
| `logManualCryEvent()` | Manual parent entry |
| `getCryAnalytics()` | Trends, peak hours, type breakdown |
| `getExportReadyEvents()` | Query events with ground truth + consent |
| `markAsExported()` | Mark events as exported to training |
| `getModelAccuracyReport()` | Confusion matrix for model performance |

Includes heuristic fallback classifier when cloud is unavailable.

### 4.2 CryAlertService (`cry_alert_service.dart` — 261 lines)

Manages the progressive alert stream:

| Method | Purpose |
|--------|---------|
| `handleBleDetection()` | Process Tier 1 VAD detection |
| `handleBleClassification()` | Process Tier 2 edge classification |
| `handleCloudClassification()` | Process Tier 3 cloud result |
| `handleCryEnded()` | Process cry resolution |
| `alertStream` | `Stream<CryAlert>` for UI consumption |

**Debouncing**: 2-minute window per baby. New detections within the window update the existing alert rather than creating a new one.

**Suggestion generation**: Context-aware suggestions based on cry type + sensor data (e.g., "Baby may be hungry — last fed 120 min ago").

### 4.3 CryFeedbackService (`cry_feedback_service.dart` — 219 lines)

| Method | Purpose |
|--------|---------|
| `confirmClassification()` | Parent confirms cloud classification |
| `correctClassification()` | Parent provides correct cry type |
| `logResolution()` | What resolved the crying |
| `submitFeedback()` | Combined confirm/correct + resolution |
| `attemptPassiveLabel()` | Infer type from parent action within 15 min |
| `getFeedbackStats()` | Admin statistics on feedback rates |

**Passive labeling rules**:
- Parent logs feeding → label recent cry as `hungry`
- Parent logs diaper change → label as `discomfort`
- Parent logs sleep → label as `tired`

### 4.4 CryDataConsentService (`cry_data_consent_service.dart` — 64 lines)

| Method | Purpose |
|--------|---------|
| `getConsent()` | Read current consent level |
| `updateConsent()` | Change consent tier |
| `revokeAndRequestDeletion()` | Revoke + create deletion request |
| `hasCompletedConsentOnboarding()` | Check if onboarding was shown |

### 4.5 BleCryBridgeService (`ble_cry_bridge_service.dart` — 414 lines)

BLE GATT interface for receiving cry detections from ESP32:

| Method | Purpose |
|--------|---------|
| `connect()` | Connect to device via BLE |
| `disconnect()` | Disconnect from device |
| `startListening()` | Subscribe to cry detection characteristic |
| `stopListening()` | Unsubscribe |

---

## 5. Cloud Functions

### 5.1 Cry Classification Pipeline

| Function | Type | Trigger |
|----------|------|---------|
| `onCryAudioUploaded` | Firestore trigger | `cryEvents/{id}` update when `hasAudioFeatures` → `true` |
| `classifyCry` | Callable | On-demand classification |

The classifier module (`cryClassifier.ts`) accepts `AudioFeatures` (MFCC, mel spectrogram, RMS, ZCR, spectral centroid, F0) and returns per-class probabilities with context fusion from sensor data.

### 5.2 Consent & Training

| Function | Type | Purpose |
|----------|------|---------|
| `onConsentRevoked` | Firestore trigger | Delete audio data on consent revocation |
| `exportTrainingData` | Callable (admin) | JSONL manifest export for ML |

### 5.3 Push Notifications

| Function | Type | When |
|----------|------|------|
| `onCryEventCreated` | Firestore trigger | New cry event → Tier 1 push |
| `onCryClassified` | Firestore trigger | Cloud classification set → Tier 3 push |

See [4.2 API Reference](../04-backend/4.2-api-reference.md) for full function signatures.

---

## 6. BLE Integration

### 6.1 GATT Service

| UUID | Type | Description |
|------|------|-------------|
| `CRY_SERVICE_UUID` | Service | Cry detection BLE service |
| `CRY_DETECTION_CHAR_UUID` | Characteristic | Notify on cry detection |
| `CRY_CLASSIFICATION_CHAR_UUID` | Characteristic | Notify on edge classification |
| `CRY_STATUS_CHAR_UUID` | Characteristic | Read current status |

### 6.2 Payload Format

**Detection notification** (Tier 1):
```json
{ "type": "detection", "intensity": 0.85, "timestamp": 1708300000 }
```

**Classification notification** (Tier 2):
```json
{ "type": "classification", "class": "hungry", "confidence": 0.72, "timestamp": 1708300002 }
```

**End notification**:
```json
{ "type": "end", "durationSeconds": 245, "timestamp": 1708300245 }
```

---

## 7. Push Notifications

### 7.1 FCM Channels

| Channel ID | Priority | Sound | Use Case |
|-----------|----------|-------|----------|
| `cry_alerts` | High/Max | Default | Cry detection and classification |

### 7.2 Notification Flow

```
onCryEventCreated:
  → Get baby name from babies/{babyId}
  → Get family FCM tokens from families/{familyId} → users/{uid}.fcmTokens
  → Send multicast: "{BabyName} is crying!"
  → Clean up invalid tokens

onCryClassified:
  → Only fires when cloudClassification is newly set
  → Send multicast: "{BabyName}: {Classification}" + suggestion
```

---

## 8. Data Flow

```
DEVICE                          CLOUD                           APP
━━━━━━                          ━━━━━                           ━━━
1. Mic → VAD detects cry
2. BLE broadcast ──────────────────────────────────────────────→ handleBleDetection()
   { intensity: 0.85 }                                          → creates event in Firestore
                                                                → emits AlertTier.detection
                                                                → "Baby is crying!"

3. Edge TFLite classifies
4. BLE update ─────────────────────────────────────────────────→ handleBleClassification()
   { type: hungry, conf: 0.65 }                                → updates event
                                                                → emits AlertTier.preliminary
                                                                → "Preliminary: Hungry"

5. Extract MFCC/mel features
6. WiFi upload → Storage ──→ 7. Set hasAudioFeatures=true
                              8. onCryAudioUploaded triggers
                              9. Load features from Storage
                              10. classifyFromFeatures()
                                  + context fusion
                              11. Write cloudClassification ───→ Firestore listener
                                                                → handleCloudClassification()
                                                                → emits AlertTier.confirmed
                                                                → "Confirmed: Hungry"

12. Cry stops
13. BLE signal ────────────────────────────────────────────────→ handleCryEnded()
                                                                → sets endTime + durationSeconds
                                                                → emits AlertTier.resolved

14. ─────────────────────────────────────────────────────────── Parent confirms/corrects
                                                                → ground truth stored

15. ──────────────────────── exportTrainingData() ←──────────── Admin triggers export
                              → JSONL manifest to Storage
```

---

## 9. Test Coverage

| Test File | Tests | What's Tested |
|-----------|-------|---------------|
| `cry_detection_service_test.dart` | 28 | Heuristic classifier, progressive lifecycle, manual logging, model accuracy |
| `cry_alert_service_test.dart` | 26 | All 4 alert tiers, debouncing, multi-baby, suggestion generation |
| `cry_feedback_service_test.dart` | 17 | Confirm, correct, resolution, passive labeling (3 types) |
| `cry_data_consent_service_test.dart` | 15 | Get/update consent, revocation + deletion, onboarding |
| `cryClassifier.test.ts` | 21 | Per-type classification, probability normalization, context fusion |
| **Total** | **107** | |

---

## 10. File Map

```
functions/src/
├── cryClassifier.ts              # ML classifier module
├── cryClassification.ts          # Triggers + callable
├── consentHandler.ts             # GDPR deletion
├── trainingExport.ts             # ML training export
├── pushNotifications.ts          # FCM push
└── __tests__/
    └── cryClassifier.test.ts     # 21 tests

baby_track_flutter/lib/
├── models/
│   └── cry_event_model.dart      # CryEvent, enums, serialization
├── services/
│   ├── cry_detection_service.dart    # Progressive pipeline
│   ├── cry_alert_service.dart        # Alert stream + debounce
│   ├── cry_feedback_service.dart     # Parent feedback + passive labeling
│   ├── cry_data_consent_service.dart # 3-tier consent
│   └── ble_cry_bridge_service.dart   # BLE GATT interface
└── screens/cry/
    ├── cry_alert_screen.dart         # Progressive alert UI
    ├── cry_consent_screen.dart       # Consent onboarding
    └── cry_history_screen.dart       # Cry timeline
```

---

## 11. Related Documents

- [4.1 Cloud Functions Overview](../04-backend/4.1-cloud-functions-overview.md) — Backend setup and deployment
- [4.2 API Reference](../04-backend/4.2-api-reference.md) — Function signatures
- [4.3 Firestore Schema](../04-backend/4.3-firestore-schema.md) — Cry event document shape
- [Colic Pattern Detection LLD](COLIC_PATTERN_DETECTION_LLD.md) — Colic analysis subsystem
- [Model System LLD](MODEL_SYSTEM_LLD.md) — ML model management
- [Consent & Privacy LLD](CONSENT_AND_PRIVACY_LLD.md) — GDPR compliance design
- [Admin Panel LLD](ADMIN_PANEL_LLD.md) — Admin UI for model management
