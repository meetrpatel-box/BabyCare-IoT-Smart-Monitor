# Admin Panel — Low-Level Design (LLD)

**Document ID**: LLD-ADMIN-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19
**Feature**: Admin Dashboard for Model Management and A/B Testing

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Access Control](#2-access-control)
3. [Admin Service](#3-admin-service)
4. [UI Sections](#4-ui-sections)
5. [Dialogs](#5-dialogs)
6. [Audit Trail](#6-audit-trail)
7. [Test Coverage](#7-test-coverage)
8. [File Map](#8-file-map)
9. [Related Documents](#9-related-documents)

---

## 1. Overview

### 1.1 Purpose

The admin panel provides a Flutter-native interface for managing the cry detection ML model, monitoring classification performance, running A/B tests between model variants, and managing admin user access.

### 1.2 Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| Model config view | See current backend, version | 🟢 Complete |
| Change backend | Switch between heuristic, TF.js, Vertex AI | 🟢 Complete |
| A/B test management | Create, edit traffic, disable A/B tests | 🟢 Complete |
| Performance dashboard | Accuracy, type breakdown, A/B comparison | 🟢 Complete |
| Admin user management | Grant/revoke admin access | 🟢 Complete |
| Audit logging | All actions logged server-side | 🟢 Complete |

---

## 2. Access Control

### 2.1 Admin Requirement

All admin panel functions require Firebase Auth custom claim `admin: true`. The admin panel screen should only be accessible to users with this claim.

### 2.2 Authentication Flow

```
User opens Admin Panel
    → AdminService.getModelConfig()
    → Cloud Function checks context.auth.token.admin
    → If not admin → HttpsError("permission-denied")
    → If admin → returns config data
```

### 2.3 Safety Rules

- Admins cannot remove their own admin status (enforced server-side)
- All admin actions create audit log entries
- Config changes are atomic (Firestore merge writes)

---

## 3. Admin Service

### 3.1 Data Classes

```dart
enum ModelBackend {
  heuristic,    // value: "heuristic",  label: "Heuristic"
  tfjs,         // value: "tfjs",       label: "TensorFlow.js"
  vertexAi;     // value: "vertex-ai",  label: "Vertex AI"
}

class ModelConfig {
  final String activeVersion;
  final ModelBackend backend;
  final String? storagePath;
  final String? vertexEndpointId;
  final ABTestConfig? abTest;
}

class ABTestConfig {
  final String challengerVersion;
  final ModelBackend challengerBackend;
  final String? challengerStoragePath;
  final int trafficPercent;        // 0–100
}

class ModelPerformanceStats {
  final int totalClassified;
  final int totalWithGroundTruth;
  final double cloudAccuracy;      // 0.0–1.0
  final double edgeAccuracy;
  final Map<String, int> classificationBreakdown;
  final int avgProcessingTimeMs;
  final Map<String, int> modelVersionBreakdown;
  final ABTestStats? abTestStats;
}

class ABTestStats {
  final int primaryCount;
  final int challengerCount;
  final double primaryAccuracy;
  final double challengerAccuracy;
}
```

### 3.2 Service Methods

| Method | Cloud Function | Purpose |
|--------|---------------|---------|
| `getModelConfig()` | `getModelConfig` | Read current config |
| `updateModelConfig(updates)` | `updateModelConfig` | Partial config update |
| `getModelPerformance({days, babyIds})` | `getModelPerformance` | Accuracy stats |
| `setAdminClaim(uid, isAdmin)` | `setAdminClaim` | Grant/revoke admin |

---

## 4. UI Sections

### 4.1 Model Configuration Card

```
┌─────────────────────────────────────────┐
│  Model Configuration                     │
│                                          │
│  Backend:    Heuristic                   │
│  Version:    heuristic-v1.0              │
│  A/B Test:   Disabled                    │
│                                          │
│  [ Change Backend ]  [ Edit Config ]     │
└─────────────────────────────────────────┘
```

### 4.2 A/B Testing Card

When A/B test is active:

```
┌─────────────────────────────────────────┐
│  A/B Testing                     ACTIVE  │
│                                          │
│  Primary:     heuristic-v1.0             │
│  Challenger:  tfjs-v1.0                  │
│  Traffic:     20% → challenger           │
│                                          │
│  [ Edit Traffic ]  [ Disable ]           │
└─────────────────────────────────────────┘
```

### 4.3 Performance Dashboard

```
┌─────────────────────────────────────────┐
│  Model Performance (Last 30 days)        │
│                                          │
│  Total Classified:    1,234              │
│  With Ground Truth:   456                │
│  Cloud Accuracy:      72%                │
│  Edge Accuracy:       65%                │
│  Avg Processing:      234ms              │
│                                          │
│  Classification Breakdown:               │
│  hungry: 312  │  tired: 198  │  ...      │
│                                          │
│  A/B Test Results:                       │
│  Primary:     72% (450 events)           │
│  Challenger:  85% (112 events) ★         │
└─────────────────────────────────────────┘
```

### 4.4 Quick Actions

| Action | What It Does |
|--------|-------------|
| Change Backend | Opens backend selection dialog |
| Create A/B Test | Opens A/B test configuration dialog |
| Edit Traffic | Opens traffic percentage slider |
| Manage Admins | Opens admin user management dialog |

---

## 5. Dialogs

### 5.1 Change Backend Dialog

Fields:
- Backend selection (dropdown: Heuristic, TF.js, Vertex AI)
- Version string (text field)
- Storage path (text field, shown for TF.js)
- Vertex endpoint ID (text field, shown for Vertex AI)

### 5.2 Create A/B Test Dialog

Fields:
- Challenger backend (dropdown)
- Challenger version (text field)
- Challenger storage path (text field, optional)
- Traffic percentage (slider, 0–100)

### 5.3 Manage Admin Dialog

Fields:
- User UID (text field)
- Toggle admin on/off

---

## 6. Audit Trail

All admin actions create entries in `adminAuditLog`:

```typescript
{
  action: "updateModelConfig" | "setAdminClaim",
  userId: string,          // Admin who performed action
  changes: Record<string, any>,
  timestamp: Timestamp
}
```

---

## 7. Test Coverage

| Test File | Tests | Coverage |
|-----------|-------|---------|
| `adminFunctions.test.ts` | 16 | getModelConfig (4), updateModelConfig (6), getModelPerformance (2), setAdminClaim (4) |
| `admin_service_test.dart` | 14 | ModelBackend (3), ModelConfig (2), ABTestConfig (2), PerformanceStats (4), ABTestStats (3) |
| **Total** | **30** | |

---

## 8. File Map

```
functions/src/
├── adminFunctions.ts             # Admin Cloud Functions
└── __tests__/
    └── adminFunctions.test.ts    # 16 tests

baby_track_flutter/lib/
├── services/
│   └── admin_service.dart        # AdminService + data classes
└── screens/admin/
    └── admin_panel_screen.dart   # Admin UI (530 lines)

baby_track_flutter/test/unit/services/
└── admin_service_test.dart       # 14 tests
```

---

## 9. Related Documents

- [Model System LLD](MODEL_SYSTEM_LLD.md) — Model loading and A/B routing backend
- [4.2 API Reference](../04-backend/4.2-api-reference.md) — Admin function signatures
- [4.4 Security Model](../04-backend/4.4-security-model.md) — Admin access control
- [Cry Detection LLD](CRY_DETECTION_LLD.md) — Pipeline that admin manages
