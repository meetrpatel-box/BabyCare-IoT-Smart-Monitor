# Cloud Functions Testing Guide

**Document ID**: DOC-9.4
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: 2026-02-19

---

## Executive Summary

Guide for running and writing tests for the BabyTrack Cloud Functions. Tests use Jest with ts-jest and mocked Firebase services. No emulator required.

---

## 📋 Table of Contents

1. [Quick Start](#1-quick-start)
2. [Test Architecture](#2-test-architecture)
3. [Running Tests](#3-running-tests)
4. [Writing Tests](#4-writing-tests)
5. [Mocking Patterns](#5-mocking-patterns)
6. [Common Patterns](#6-common-patterns)
7. [Test Inventory](#7-test-inventory)
8. [Troubleshooting](#8-troubleshooting)
9. [Related Documents](#9-related-documents)

---

## 1. Quick Start

```bash
cd functions
npm install
npm test             # Run all 75 tests
npm run test:watch   # Watch mode
```

---

## 2. Test Architecture

```
functions/
├── src/
│   └── __tests__/                    # Test files
│       ├── cryClassifier.test.ts     # 21 tests
│       ├── modelLoader.test.ts       # 26 tests
│       ├── colicPatternDetector.test.ts  # 12 tests
│       └── adminFunctions.test.ts    # 16 tests
├── jest.config.js                    # Jest configuration
├── tsconfig.json                     # TypeScript config
└── package.json                      # Test scripts
```

### Configuration

**jest.config.js:**
```javascript
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/__tests__/**/*.test.ts"],
  moduleFileExtensions: ["ts", "js", "json"],
};
```

**Key dependencies:**
- `jest` ^29.7.0
- `ts-jest` ^29.1.2
- `@types/jest` ^29.5.12
- `firebase-functions-test` ^3.3.0

---

## 3. Running Tests

```bash
# Run all tests
npm test

# Run specific test file
npx jest --testPathPattern cryClassifier

# Watch mode (re-run on changes)
npm run test:watch

# With coverage
npx jest --coverage

# Verbose output
npx jest --verbose
```

---

## 4. Writing Tests

### 4.1 File Naming

Place tests in `src/__tests__/` with the naming pattern `{moduleName}.test.ts`.

### 4.2 Basic Structure

```typescript
// Use var (not const) for mock variables — jest.mock is hoisted above const
var mockGet: jest.Mock;
var mockCollection: jest.Mock;

// Initialize mocks before jest.mock
mockGet = jest.fn();
mockCollection = jest.fn();

// Mock firebase-admin
jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  apps: [],
  firestore: Object.assign(
    jest.fn(() => ({
      collection: (...args: any[]) => mockCollection(...args),
    })),
    {
      Timestamp: {
        fromDate: (d: Date) => ({ toDate: () => d }),
      },
      FieldValue: {
        serverTimestamp: () => "SERVER_TIMESTAMP",
        delete: () => "FIELD_DELETE",
        arrayRemove: (...vals: any[]) => ({ _remove: vals }),
      },
    }
  ),
  auth: jest.fn(() => ({
    setCustomUserClaims: jest.fn(),
  })),
}));

// Mock firebase-functions
jest.mock("firebase-functions", () => ({
  https: {
    onCall: (fn: Function) => fn,
    HttpsError: class HttpsError extends Error {
      constructor(public code: string, message: string) {
        super(message);
      }
    },
  },
  firestore: {
    document: () => ({ onCreate: (fn: Function) => fn, onUpdate: (fn: Function) => fn }),
  },
  pubsub: {
    schedule: () => ({ timeZone: () => ({ onRun: (fn: Function) => fn }) }),
  },
  logger: { info: jest.fn(), error: jest.fn() },
}));

// Import AFTER mocks
import { myFunction } from "../myModule";

describe("myFunction", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Set up chainable Firestore mocks
    mockCollection.mockReturnValue({
      doc: mockDoc,
      where: mockWhere,
      orderBy: mockOrderBy,
      get: mockGet,
    });
  });

  it("should do something", async () => {
    mockGet.mockResolvedValue({ docs: [], empty: true });
    const result = await myFunction(data, context);
    expect(result).toBeDefined();
  });
});
```

---

## 5. Mocking Patterns

### 5.1 Firestore Chainable Queries

Many Firestore operations chain methods. Set up chainable returns:

```typescript
var mockGet: jest.Mock;
var mockDoc: jest.Mock;
var mockCollection: jest.Mock;
var mockWhere: jest.Mock;
var mockOrderBy: jest.Mock;
var mockSet: jest.Mock;
var mockUpdate: jest.Mock;

// In beforeEach:
mockCollection.mockReturnValue({
  doc: mockDoc,
  where: mockWhere,
  orderBy: mockOrderBy,
  get: mockGet,
  add: jest.fn().mockResolvedValue({ id: "new-doc" }),
});
mockDoc.mockReturnValue({
  get: mockGet,
  set: mockSet,
  update: mockUpdate,
  collection: mockCollection,
});
mockWhere.mockReturnValue({
  where: mockWhere,
  orderBy: mockOrderBy,
  get: mockGet,
  limit: jest.fn().mockReturnValue({ get: mockGet }),
});
mockOrderBy.mockReturnValue({
  get: mockGet,
});
```

### 5.2 Sequential Get Calls

When a function calls `.get()` multiple times, use `mockResolvedValueOnce`:

```typescript
mockGet
  .mockResolvedValueOnce({ exists: true, data: () => configData })  // First get
  .mockResolvedValueOnce({ docs: eventDocs, empty: false });         // Second get
```

### 5.3 Callable Function Context

```typescript
const validContext = {
  auth: {
    uid: "user-123",
    token: { admin: true },
  },
};

const unauthContext = { auth: null };
const nonAdminContext = { auth: { uid: "user-456", token: {} } };
```

### 5.4 Timestamp Mocking

```typescript
// In the firebase-admin mock:
Timestamp: {
  fromDate: (d: Date) => ({ toDate: () => d }),
}
```

---

## 6. Common Patterns

### 6.1 Testing Auth Requirements

```typescript
it("should reject unauthenticated calls", async () => {
  await expect(myFunction({}, { auth: null }))
    .rejects.toMatchObject({ code: "unauthenticated" });
});

it("should reject non-admin calls", async () => {
  await expect(myFunction({}, { auth: { uid: "x", token: {} } }))
    .rejects.toMatchObject({ code: "permission-denied" });
});
```

### 6.2 Testing Validation

```typescript
it("should reject invalid input", async () => {
  await expect(myFunction({ backend: "invalid" }, adminContext))
    .rejects.toMatchObject({ code: "invalid-argument" });
});
```

### 6.3 Date Handling

Use relative dates to avoid timezone issues:

```typescript
function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(12, 0, 0, 0);  // Midday avoids UTC boundary issues
  return d;
}
```

### 6.4 Jest Mock Hoisting

**Critical**: `jest.mock()` is hoisted to the top of the file by babel/jest. Use `var` instead of `const` for mock variables:

```typescript
// WRONG — ReferenceError: Cannot access before initialization
const mockGet = jest.fn();
jest.mock("firebase-admin", () => ({ ... mockGet ... }));

// CORRECT — var is hoisted, accessible in mock factory
var mockGet: jest.Mock;
mockGet = jest.fn();
jest.mock("firebase-admin", () => ({
  firestore: jest.fn(() => ({ collection: jest.fn(() => ({ get: (...args: any[]) => mockGet(...args) })) })),
}));
```

---

## 7. Test Inventory

| File | Tests | What's Tested |
|------|-------|---------------|
| `cryClassifier.test.ts` | 21 | Per-type classification (7 types), probability normalization, context fusion (5 factors), edge cases |
| `modelLoader.test.ts` | 26 | Singleton pattern, config caching, TTL expiry, A/B test routing, backend selection, hash determinism |
| `colicPatternDetector.test.ts` | 12 | Empty data, day threshold, mild/severe risk, suggestions, streaks, weekly summaries, peak hours, score cap, events without endTime |
| `adminFunctions.test.ts` | 16 | getModelConfig (4), updateModelConfig (6), getModelPerformance (2), setAdminClaim (4) |
| **Total** | **75** | |

---

## 8. Troubleshooting

### `ReferenceError: Cannot access 'X' before initialization`

Mock variables declared with `const` or `let` are not hoisted. Use `var`.

### `TypeError: mockX.mockReturnValue is not a function`

Mock variable was not initialized before `jest.mock()`. Initialize with `jest.fn()` before the mock factory.

### Tests pass individually but fail together

Add `jest.clearAllMocks()` in `beforeEach`. Mock state leaks between tests.

### Firestore chain returns `undefined`

Ensure all chain methods return objects with the next method. Check `mockWhere.mockReturnValue` includes `{ where: mockWhere, get: mockGet }`.

### Date-related test failures

Hardcoded dates may fall outside lookback windows. Use `daysAgo()` helper with midday hours.

---

## 9. Related Documents

- [4.1 Cloud Functions Overview](../04-backend/4.1-cloud-functions-overview.md) — Function setup and deployment
- [5.1 Testing Strategy](../05-operations/5.1-testing-strategy.md) — Overall testing approach
- [5.3 Testing Architecture](../05-operations/5.3-testing-architecture.md) — Test infrastructure
