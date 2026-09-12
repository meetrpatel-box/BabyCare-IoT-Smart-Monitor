# Consent & Privacy — Low-Level Design (LLD)

**Document ID**: LLD-CONSENT-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19
**Feature**: 3-Tier Data Consent System with GDPR Compliance

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Consent Tiers](#2-consent-tiers)
3. [Consent Flow](#3-consent-flow)
4. [Data Deletion](#4-data-deletion)
5. [Service Layer](#5-service-layer)
6. [Cloud Functions](#6-cloud-functions)
7. [UI Components](#7-ui-components)
8. [Data Handling Matrix](#8-data-handling-matrix)
9. [Test Coverage](#9-test-coverage)
10. [File Map](#10-file-map)
11. [Related Documents](#11-related-documents)

---

## 1. Overview

### 1.1 Purpose

The consent system gives parents full control over what cry detection data is collected, stored, and used for ML training. It follows GDPR principles: purpose limitation, data minimization, right to erasure, and transparency.

### 1.2 Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| 3-tier consent | featuresOnly, fullAudio, none | 🟢 Complete |
| Consent onboarding | First-launch explanation screen | 🟢 Complete |
| Consent management | Change tier at any time | 🟢 Complete |
| Revocation + deletion | Automatic data cleanup on downgrade | 🟢 Complete |
| Per-event consent | Each event tagged with consent level | 🟢 Complete |
| GDPR audit trail | Deletion requests tracked | 🟢 Complete |

---

## 2. Consent Tiers

### 2.1 Tier Definitions

| Tier | Enum Value | What's Stored | What's Used For |
|------|-----------|---------------|-----------------|
| **Features Only** (Default) | `featuresOnly` | Extracted audio features (~2KB) — MFCC, mel spectrogram, RMS, ZCR | Cloud classification + anonymized ML training |
| **Full Audio** | `fullAudio` | Features + raw audio file (~20KB WAV) | Higher quality training data, manual labeling |
| **None** | `none` | Event metadata only (times, duration) | Parent's cry log only, no ML processing |

### 2.2 Privacy Properties

```
                    featuresOnly        fullAudio           none
                    ────────────        ─────────           ────
Audio recoverable?  No (features only)  Yes (raw stored)    No data at all
ML training?        Yes (anonymized)    Yes (better data)   No
Cloud classifier?   Yes                 Yes                 Skipped
Parent cry log?     Yes                 Yes                 Yes (metadata only)
Storage per event   ~2KB                ~20KB               ~0.5KB
```

### 2.3 Default Behavior

New users default to `featuresOnly`:
- Privacy-preserving (no raw audio)
- Still enables cloud classification and ML improvement
- Can upgrade to `fullAudio` or downgrade to `none` at any time

---

## 3. Consent Flow

### 3.1 Onboarding

```
First Launch / First Cry Event
│
├── 1. Check hasCompletedConsentOnboarding()
│      └── If false → show CryConsentScreen
│
├── 2. CryConsentScreen explains:
│      - What data is collected
│      - How it's used
│      - 3 tier options with clear descriptions
│      - "You can change this anytime in Settings"
│
├── 3. User selects tier
│      └── updateConsent(selectedTier)
│          → Writes to users/{uid}/preferences.cryDataConsent
│          → Sets cryDataConsentUpdatedAt
│
└── 4. Mark onboarding complete
       └── Consent screen won't show again
```

### 3.2 Changing Consent

```
Settings → Privacy → Cry Data Consent
│
├── Upgrade (none → featuresOnly → fullAudio)
│   └── Simple preference update
│       Future events will include more data
│
└── Downgrade (fullAudio → featuresOnly, or any → none)
    └── revokeAndRequestDeletion()
        ├── Updates preference
        ├── Creates dataDeleteRequest { status: "pending" }
        └── Triggers onConsentRevoked Cloud Function
```

---

## 4. Data Deletion

### 4.1 Deletion Flow

```
User downgrades consent
    │
    ├── 1. Flutter creates dataDeleteRequest
    │      { userId, type: "cry_training_data", status: "pending" }
    │
    ├── 2. onConsentRevoked trigger fires
    │      └── Firestore trigger on dataDeleteRequests/{id} create
    │
    ├── 3. Cloud Function processes deletion
    │      ├── Query all cryEvents for user's babies
    │      ├── For each event:
    │      │   ├── Delete audioFeaturesPath from Storage
    │      │   ├── Delete rawAudioPath from Storage
    │      │   ├── Clear ML fields:
    │      │   │   - audioFeatures → null
    │      │   │   - audioFeaturesPath → null
    │      │   │   - rawAudioPath → null
    │      │   │   - hasAudioFeatures → false
    │      │   │   - hasRawAudio → false
    │      │   │   - classProbabilities → null
    │      │   │   - cloudClassification → null
    │      │   │   - cloudConfidence → null
    │      │   └── Keep metadata (startTime, endTime, parentFeedback)
    │      └── Update request: status → "completed"
    │
    └── 4. Result tracked in dataDeleteRequests
           { deletedFeatureFiles: N, clearedEvents: N, completedAt }
```

### 4.2 What's Kept vs. Deleted

| Data | Deleted | Kept | Reason |
|------|---------|------|--------|
| Audio features (Storage) | Yes | - | ML data, user opted out |
| Raw audio (Storage) | Yes | - | Sensitive audio |
| Event metadata | - | Yes | Parent's cry history |
| Event timing | - | Yes | Duration, start/end times |
| Parent feedback | - | Yes | User's own input |
| Classification results | Yes | - | Derived from deleted data |
| Sensor context | Yes | - | Associated with ML processing |

---

## 5. Service Layer

### 5.1 CryDataConsentService (`cry_data_consent_service.dart` — 64 lines)

```dart
class CryDataConsentService {
  final FirebaseFirestore _firestore;

  // Read consent
  Future<CryDataConsent> getConsent(String userId);

  // Update consent tier
  Future<void> updateConsent(String userId, CryDataConsent consent);

  // Revoke consent + request data deletion
  Future<void> revokeAndRequestDeletion(String userId);

  // Check if onboarding was completed
  Future<bool> hasCompletedConsentOnboarding(String userId);
}
```

### 5.2 Per-Event Tagging

When creating a cry event, the current consent level is stamped on the event:

```dart
// In CryDetectionService.createFromEdgeDetection()
final consent = await _consentService.getConsent(userId);
event.dataConsent = consent;
```

This ensures each event is self-describing — even if the user changes consent later, the event records what was consented at creation time.

---

## 6. Cloud Functions

### 6.1 onConsentRevoked (`consentHandler.ts` — 174 lines)

```typescript
// Firestore trigger on dataDeleteRequests/{id} create
export const onConsentRevoked = functions.firestore
  .document("dataDeleteRequests/{requestId}")
  .onCreate(async (snap, context) => {
    // 1. Mark request in_progress
    // 2. Get user's babies
    // 3. For each baby, query cryEvents
    // 4. Delete Storage files
    // 5. Clear ML fields from event docs
    // 6. Mark request completed
  });
```

### 6.2 Consent-Aware Processing

Other Cloud Functions respect consent:

```typescript
// In onCryAudioUploaded
if (event.dataConsent === "none") {
  // Skip classification entirely
  return null;
}
```

```typescript
// In exportTrainingData
query.where("dataConsent", "in", ["featuresOnly", "fullAudio"])
     .where("exportedToTraining", "==", false);
```

---

## 7. UI Components

### 7.1 CryConsentScreen (`cry_consent_screen.dart`)

- Shown on first cry event or first launch
- Explains 3 tiers with clear visual differentiation
- Privacy-first messaging ("Your data stays private by default")
- "You can change this anytime" reassurance
- Links to full privacy policy

### 7.2 Settings Integration

- Settings → Privacy → Cry Data Consent
- Dropdown or radio buttons for tier selection
- Warning dialog when downgrading ("This will delete stored audio features")
- Confirmation before deletion request

---

## 8. Data Handling Matrix

| Operation | `featuresOnly` | `fullAudio` | `none` |
|-----------|---------------|------------|--------|
| Create cry event | Yes (metadata) | Yes (metadata) | Yes (metadata only) |
| Upload audio features | Yes | Yes | No |
| Upload raw audio | No | Yes | No |
| Cloud classification | Yes | Yes | Skipped |
| Parent feedback | Yes | Yes | Yes |
| Training export | Yes | Yes | Excluded |
| Storage cleanup on revoke | Features deleted | Features + audio deleted | N/A |

---

## 9. Test Coverage

| Test File | Tests | Coverage |
|-----------|-------|---------|
| `cry_data_consent_service_test.dart` | 15 | Get/update consent (6 cases), merge with user data, revocation + deletion, onboarding check |
| **Total** | **15** | |

---

## 10. File Map

```
functions/src/
├── consentHandler.ts               # GDPR deletion Cloud Function
└── (consent checks in cryClassification.ts, trainingExport.ts)

baby_track_flutter/lib/
├── services/
│   └── cry_data_consent_service.dart   # Consent management
└── screens/cry/
    └── cry_consent_screen.dart         # Consent onboarding UI

baby_track_flutter/test/unit/services/
└── cry_data_consent_service_test.dart  # 15 tests
```

---

## 11. Related Documents

- [Cry Detection LLD](CRY_DETECTION_LLD.md) — Pipeline that respects consent
- [4.3 Firestore Schema](../04-backend/4.3-firestore-schema.md#6-data-delete-requests) — Deletion request document
- [4.4 Security Model](../04-backend/4.4-security-model.md#6-gdpr-compliance) — Access rules for deletion requests
- [Model System LLD](MODEL_SYSTEM_LLD.md) — Training export respects consent
