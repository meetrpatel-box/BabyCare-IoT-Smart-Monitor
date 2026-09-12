# Model System — Low-Level Design (LLD)

**Document ID**: LLD-MODEL-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19
**Feature**: ML Model Loading, Versioning, and A/B Testing

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Model Backends](#3-model-backends)
4. [Model Loader](#4-model-loader)
5. [A/B Testing](#5-ab-testing)
6. [Configuration](#6-configuration)
7. [Admin Management](#7-admin-management)
8. [Flutter Integration](#8-flutter-integration)
9. [Test Coverage](#9-test-coverage)
10. [File Map](#10-file-map)
11. [Related Documents](#11-related-documents)

---

## 1. Overview

### 1.1 Purpose

The model system manages the cry classification ML model lifecycle: loading, caching, versioning, A/B testing between model variants, and performance monitoring. It's designed to support hot-swapping between three backend types without changing any pipeline code.

### 1.2 Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| Multi-backend support | Heuristic, TF.js, Vertex AI | 🟢 Complete |
| Model loader singleton | Cached model with 5-min config TTL | 🟢 Complete |
| A/B test routing | Traffic split between primary and challenger | 🟢 Complete |
| Config management | CRUD via admin Cloud Functions | 🟢 Complete |
| Performance monitoring | Accuracy stats with A/B comparison | 🟢 Complete |
| Audit logging | All config changes tracked | 🟢 Complete |
| Admin UI | Flutter screen for config + performance | 🟢 Complete |

---

## 2. Architecture

```
┌────────────────────────────────────────────────────┐
│  Model System Architecture                          │
├────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  ModelLoader (Singleton)                      │   │
│  │                                               │   │
│  │  ┌─────────────┐    ┌────────────────────┐   │   │
│  │  │ Config Cache │    │ A/B Test Router    │   │   │
│  │  │ (5-min TTL) │    │ (traffic split)    │   │   │
│  │  └──────┬──────┘    └─────────┬──────────┘   │   │
│  │         │                      │               │   │
│  │         ▼                      ▼               │   │
│  │  ┌─────────────┐   ┌──────────────────────┐  │   │
│  │  │ Firestore   │   │ Backend Selection    │  │   │
│  │  │ modelConfig │   │                      │  │   │
│  │  │ /cryClassi- │   │ Hash(babyId) % 100  │  │   │
│  │  │  fier       │   │ < trafficPercent?    │  │   │
│  │  └─────────────┘   │   → challenger       │  │   │
│  │                     │   → primary          │  │   │
│  │                     └──────────────────────┘  │   │
│  └──────────────────────┬────────────────────────┘   │
│                         │                             │
│           ┌─────────────┼─────────────┐               │
│           ▼             ▼             ▼               │
│  ┌──────────────┐ ┌──────────┐ ┌──────────────┐     │
│  │  Heuristic   │ │  TF.js   │ │  Vertex AI   │     │
│  │  Classifier  │ │  Model   │ │  Endpoint    │     │
│  │              │ │          │ │              │     │
│  │  Rule-based  │ │  Storage │ │  REST API    │     │
│  │  + context   │ │  loaded  │ │  call        │     │
│  │  fusion      │ │          │ │              │     │
│  └──────────────┘ └──────────┘ └──────────────┘     │
│                                                      │
└────────────────────────────────────────────────────┘
```

---

## 3. Model Backends

### 3.1 Heuristic (`heuristic`)

Rule-based classifier using acoustic feature statistics and sensor context fusion.

```typescript
// In cryClassifier.ts
function classifyFromFeatures(
  features: AudioFeatures,
  context?: SensorContext
): ClassificationResult
```

**Pros**: No model file needed, instant, deterministic
**Cons**: Limited accuracy, manually tuned thresholds

### 3.2 TF.js (`tfjs`)

TensorFlow.js model loaded from Firebase Storage.

- Model path: `models/cry-classifier/{version}/model.json`
- Loaded via `@tensorflow/tfjs-node`
- Type declarations in `functions/src/types/tfjs-node.d.ts`

**Pros**: ML-trained, better accuracy
**Cons**: Cold start latency, memory usage

### 3.3 Vertex AI (`vertex-ai`)

Google Cloud Vertex AI endpoint for server-side inference.

- Endpoint ID stored in config: `vertexEndpointId`
- Uses `google-auth-library` for authentication

**Pros**: Managed infrastructure, auto-scaling
**Cons**: Network latency, cost per prediction

---

## 4. Model Loader

### 4.1 Singleton Pattern (`modelLoader.ts`)

```typescript
class ModelLoader {
  private static instance: ModelLoader;
  private config: ModelConfig | null = null;
  private configLoadedAt: number = 0;
  private readonly CONFIG_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  static getInstance(): ModelLoader;
  async getConfig(): Promise<ModelConfig>;
  async classify(features: AudioFeatures, babyId: string): Promise<ClassificationResult>;
}
```

### 4.2 Config Caching

- Config loaded from `modelConfig/cryClassifier` on first request
- Cached for 5 minutes (CONFIG_CACHE_TTL)
- Subsequent requests within TTL use cached config
- Cache invalidated after TTL expires

### 4.3 Classification Flow

```
classify(features, babyId)
│
├── 1. Load config (from cache or Firestore)
│
├── 2. Check A/B test routing
│   ├── If abTest enabled → route via hash(babyId) % 100
│   └── Else → use primary backend
│
├── 3. Load model for selected backend
│   ├── heuristic → classifyFromFeatures()
│   ├── tfjs → load model from Storage, run inference
│   └── vertex-ai → REST API call to Vertex endpoint
│
└── 4. Return ClassificationResult with modelVersion tag
```

---

## 5. A/B Testing

### 5.1 Traffic Routing

Uses deterministic hash-based routing so the same baby always gets the same model:

```typescript
function shouldUseChallenger(babyId: string, trafficPercent: number): boolean {
  const hash = hashCode(babyId);
  return (Math.abs(hash) % 100) < trafficPercent;
}
```

**Benefits**:
- Consistent per-baby (no flip-flopping between models)
- Reproducible results for accuracy comparison
- No external service needed

### 5.2 Configuration

```typescript
// modelConfig/cryClassifier.abTest
{
  challengerVersion: "tfjs-v1.0",
  challengerBackend: "tfjs",
  challengerStoragePath: "models/cry-classifier/v1.0/model.json",
  trafficPercent: 20  // 20% of babies get challenger
}
```

### 5.3 Performance Comparison

The `getModelPerformance` admin function aggregates accuracy split by model version:

```typescript
abTestStats: {
  primaryCount: 450,        // events classified by primary
  challengerCount: 112,     // events classified by challenger
  primaryAccuracy: 0.72,    // ground truth match rate
  challengerAccuracy: 0.85  // challenger is winning
}
```

---

## 6. Configuration

### 6.1 Firestore Document

**Path**: `modelConfig/cryClassifier`

```typescript
{
  activeVersion: "heuristic-v1.0",
  backend: "heuristic",
  storagePath: null,
  vertexEndpointId: null,
  abTest: null,
  lastUpdatedBy: "admin-uid",
  lastUpdatedAt: Timestamp
}
```

### 6.2 Changing Backends

**Switch to TF.js:**
```typescript
await updateModelConfig({
  activeVersion: "tfjs-v1.0",
  backend: "tfjs",
  storagePath: "models/cry-classifier/v1.0/model.json"
});
```

**Enable A/B test:**
```typescript
await updateModelConfig({
  abTest: {
    challengerVersion: "tfjs-v1.0",
    challengerBackend: "tfjs",
    challengerStoragePath: "models/cry-classifier/v1.0/model.json",
    trafficPercent: 20
  }
});
```

**Disable A/B test:**
```typescript
await updateModelConfig({ abTest: null });
```

---

## 7. Admin Management

### 7.1 Admin Cloud Functions

| Function | Purpose |
|----------|---------|
| `getModelConfig` | Read current config |
| `updateModelConfig` | Change backend, version, A/B test |
| `getModelPerformance` | Accuracy stats with A/B comparison |
| `setAdminClaim` | Grant/revoke admin access |

All require `admin: true` custom claim. All changes logged to `adminAuditLog`.

### 7.2 Validation Rules

- `backend` must be one of: `heuristic`, `tfjs`, `vertex-ai`
- `trafficPercent` must be 0–100
- A/B test requires both `challengerVersion` and `challengerBackend`
- At least one valid field must be provided for update
- Cannot remove own admin status

---

## 8. Flutter Integration

### 8.1 AdminService (`admin_service.dart`)

```dart
enum ModelBackend {
  heuristic, tfjs, vertexAi;
  String get value => ...;  // "heuristic", "tfjs", "vertex-ai"
  String get label => ...;  // "Heuristic", "TensorFlow.js", "Vertex AI"
}

class AdminService {
  Future<ModelConfig> getModelConfig();
  Future<ModelConfig> updateModelConfig(Map<String, dynamic> updates);
  Future<ModelPerformanceStats> getModelPerformance({int days, List<String>? babyIds});
  Future<void> setAdminClaim(String targetUid, bool isAdmin);
}
```

### 8.2 AdminPanelScreen (`admin_panel_screen.dart` — 530 lines)

| Section | Description |
|---------|-------------|
| Model Configuration | Current backend, version, storage path |
| A/B Testing | Challenger config, traffic slider, enable/disable |
| Model Performance | Total classified, accuracy, type breakdown |
| Quick Actions | Change backend, create A/B test, manage admins |

Dialogs: Change Backend, Create A/B Test, Edit Traffic %, Manage Admin Access.

---

## 9. Test Coverage

| Test File | Tests | Coverage |
|-----------|-------|---------|
| `modelLoader.test.ts` | 26 | Singleton, caching, A/B routing, backend selection, config TTL |
| `adminFunctions.test.ts` | 16 | CRUD config, validation, performance stats, admin claims, audit |
| `admin_service_test.dart` | 14 | ModelBackend parsing, ModelConfig, ABTestConfig, performance stats |
| **Total** | **56** | |

---

## 10. File Map

```
functions/src/
├── modelLoader.ts                # Singleton model loader + A/B routing
├── adminFunctions.ts             # Admin CRUD Cloud Functions
├── cryClassifier.ts              # Heuristic classifier (default backend)
├── types/
│   └── tfjs-node.d.ts            # TF.js type declarations
└── __tests__/
    ├── modelLoader.test.ts       # 26 tests
    └── adminFunctions.test.ts    # 16 tests

baby_track_flutter/lib/
├── services/
│   └── admin_service.dart        # Flutter admin service wrapper
└── screens/admin/
    └── admin_panel_screen.dart   # Admin UI

baby_track_flutter/test/unit/services/
└── admin_service_test.dart       # 14 tests
```

---

## 11. Related Documents

- [Cry Detection LLD](CRY_DETECTION_LLD.md) — Pipeline that uses this model system
- [Admin Panel LLD](ADMIN_PANEL_LLD.md) — UI for managing models
- [4.1 Cloud Functions Overview](../04-backend/4.1-cloud-functions-overview.md) — Deployment and setup
- [4.2 API Reference](../04-backend/4.2-api-reference.md) — Admin function signatures
- [4.3 Firestore Schema](../04-backend/4.3-firestore-schema.md#4-model-configuration) — Model config document
