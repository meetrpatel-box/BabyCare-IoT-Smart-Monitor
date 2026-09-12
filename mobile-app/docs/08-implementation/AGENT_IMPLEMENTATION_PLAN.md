# Agent Implementation Plan
> **Version**: 1.0.0 | **Date**: February 1, 2026  
> **Purpose**: Structured task breakdown for parallel agent development

---

## 📋 Overview

This document defines **14 implementation tasks** organized into **5 priority tiers**. Each task is designed to be:
- **Self-contained** - Can be completed independently
- **Agent-ready** - Clear inputs, outputs, and acceptance criteria
- **Testable** - Includes test requirements

### Current State
| Layer | Exists | Missing |
|-------|--------|---------|
| **Models** | BabyModel, SleepModel, PhotoModel, MilestoneModel, TipModel, AIInsightModel, DeviceModel, FamilyModel, UserModel | CryEventModel, BreathingModel, PositionModel, OfflineQueueModel |
| **Services** | AuthService, FirestoreService, DeviceService, PhotoService, FamilyService, PinService, BiometricService, WifiProvisioningService, AIInsightsService | MilestoneService, TipService, CryDetectionService, BreathingService, PositionService, OfflineSyncService, VideoStreamService |
| **Providers** | AuthProvider, BabyProvider, DeviceProvider, PhotoProvider | MilestoneProvider, TipProvider, InsightsProvider, OfflineProvider |

---

## 🚀 TIER 0: Critical Missing Providers (Blocking)
> These are blocking architecture freeze. Must complete first.

---

### Task 0.1: MilestoneProvider Implementation

**Priority**: P0 - BLOCKING  
**Complexity**: Medium  
**Estimated Time**: 2-3 hours  
**Dependencies**: MilestoneModel (exists)

#### Context
MilestoneModel exists but has no provider to manage state. This breaks the Provider pattern consistency.

#### Files to Create
```
lib/providers/milestone_provider.dart
test/providers/milestone_provider_test.dart
```

#### Implementation Requirements

```dart
// lib/providers/milestone_provider.dart
class MilestoneProvider extends ChangeNotifier {
  // State
  List<Milestone> _milestones = [];
  List<Milestone> _upcomingMilestones = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Milestone> get milestones => _milestones;
  List<Milestone> get upcomingMilestones => _upcomingMilestones;
  List<Milestone> get completedMilestones => 
    _milestones.where((m) => m.isCompleted).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Methods required
  Future<void> loadMilestones(String babyId);
  Future<void> loadUpcomingMilestones(String babyId, int ageInMonths);
  Future<void> markMilestoneCompleted(String milestoneId, DateTime completedAt);
  Future<void> addCustomMilestone(Milestone milestone);
  List<Milestone> getMilestonesByCategory(MilestoneCategory category);
  double getCompletionPercentage(int ageInMonths);
}
```

#### Acceptance Criteria
- [ ] Provider loads milestones from Firestore
- [ ] Provider filters by completion status
- [ ] Provider calculates completion percentage
- [ ] All methods notify listeners
- [ ] 90%+ test coverage
- [ ] Registered in main.dart MultiProvider

#### Test Cases Required
```dart
test('loadMilestones fetches from Firestore and notifies');
test('markMilestoneCompleted updates state and persists');
test('getCompletionPercentage calculates correctly');
test('upcomingMilestones filters by age range');
```

---

### Task 0.2: TipProvider Implementation

**Priority**: P0 - BLOCKING  
**Complexity**: Medium  
**Estimated Time**: 2-3 hours  
**Dependencies**: TipModel (exists)

#### Files to Create
```
lib/providers/tip_provider.dart
test/providers/tip_provider_test.dart
```

#### Implementation Requirements

```dart
// lib/providers/tip_provider.dart
class TipProvider extends ChangeNotifier {
  // State
  List<Tip> _tips = [];
  Tip? _tipOfTheDay;
  Set<String> _dismissedTipIds = {};
  bool _isLoading = false;

  // Getters
  List<Tip> get tips => _tips;
  Tip? get tipOfTheDay => _tipOfTheDay;
  List<Tip> get activeTips => 
    _tips.where((t) => !_dismissedTipIds.contains(t.id)).toList();

  // Methods required
  Future<void> loadTips(String babyId, int ageInMonths);
  Future<void> loadTipOfTheDay(String babyId, int ageInMonths);
  Future<void> dismissTip(String tipId);
  Future<void> markTipHelpful(String tipId, bool isHelpful);
  List<Tip> getTipsByCategory(TipCategory category);
  Future<void> refreshTipOfTheDay();
}
```

#### Acceptance Criteria
- [ ] Provider loads age-appropriate tips
- [ ] Tip of the day rotates daily
- [ ] Dismissed tips are persisted
- [ ] Helpfulness feedback saved
- [ ] 90%+ test coverage

---

### Task 0.3: MilestoneService Implementation

**Priority**: P0 - BLOCKING  
**Complexity**: Medium  
**Estimated Time**: 2-3 hours  
**Dependencies**: MilestoneModel (exists), FirestoreService (exists)

#### Files to Create
```
lib/services/milestone_service.dart
test/services/milestone_service_test.dart
```

#### Implementation Requirements

```dart
// lib/services/milestone_service.dart
class MilestoneService {
  final FirebaseFirestore _firestore;

  // CRUD Operations
  Future<List<Milestone>> getMilestones(String babyId);
  Future<List<Milestone>> getUpcomingMilestones(String babyId, int ageInMonths);
  Future<void> createMilestone(Milestone milestone);
  Future<void> updateMilestone(String id, Map<String, dynamic> updates);
  Future<void> deleteMilestone(String id);
  
  // Business Logic
  Future<void> markCompleted(String milestoneId, DateTime completedAt, String? photoUrl);
  Future<List<Milestone>> getDefaultMilestonesForAge(int ageInMonths);
  Stream<List<Milestone>> watchMilestones(String babyId);
}
```

#### Firestore Structure
```
/babies/{babyId}/milestones/{milestoneId}
  - title: string
  - description: string
  - category: string (enum)
  - expectedAgeMonths: number
  - completedAt: timestamp?
  - photoUrl: string?
  - isCustom: boolean
```

---

### Task 0.4: TipService Implementation

**Priority**: P0 - BLOCKING  
**Complexity**: Medium  
**Estimated Time**: 2-3 hours  
**Dependencies**: TipModel (exists)

#### Files to Create
```
lib/services/tip_service.dart
test/services/tip_service_test.dart
```

#### Implementation Requirements

```dart
// lib/services/tip_service.dart
class TipService {
  // Tip retrieval
  Future<List<Tip>> getTipsForAge(int ageInMonths);
  Future<Tip?> getTipOfTheDay(String babyId, int ageInMonths);
  Future<List<Tip>> getTipsByCategory(TipCategory category, int ageInMonths);
  
  // User interactions
  Future<void> markTipDismissed(String tipId, String userId);
  Future<void> recordTipFeedback(String tipId, String userId, bool isHelpful);
  
  // Seeding (for initial content)
  Future<void> seedDefaultTips();
}
```

---

## 🔴 TIER 1: Core Sensor Features (High Value)
> Hardware sensors exist but software doesn't utilize them.

---

### Task 1.1: Breath Rate Monitoring

**Priority**: P1 - HIGH VALUE  
**Complexity**: High  
**Estimated Time**: 4-6 hours  
**Dependencies**: DeviceService, BabyModel

#### Rationale
AnvayaPod has breath rate sensor. This is key SIDS indicator. Parents expect this.

#### Files to Create
```
lib/models/breathing_model.dart
lib/services/breathing_service.dart
lib/providers/breathing_provider.dart
lib/widgets/vitals/breathing_indicator.dart
test/models/breathing_model_test.dart
test/services/breathing_service_test.dart
```

#### Model Definition

```dart
// lib/models/breathing_model.dart
enum BreathingStatus { normal, elevated, low, critical, unknown }

class BreathingReading {
  final String id;
  final String babyId;
  final int breathsPerMinute;
  final BreathingStatus status;
  final DateTime timestamp;
  final String? deviceId;
  
  // Normal ranges by age (breaths per minute)
  static Map<String, Range> normalRanges = {
    '0-1m': Range(30, 60),
    '1-6m': Range(25, 40),
    '6-12m': Range(20, 30),
  };
  
  BreathingStatus calculateStatus(int ageInMonths);
}

class BreathingSession {
  final String id;
  final String babyId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<BreathingReading> readings;
  final int averageBpm;
  final int minBpm;
  final int maxBpm;
  final int irregularityCount;
}
```

#### Service Requirements

```dart
// lib/services/breathing_service.dart
class BreathingService {
  Stream<BreathingReading> watchBreathRate(String deviceId);
  Future<BreathingSession> getLatestSession(String babyId);
  Future<List<BreathingSession>> getSessionHistory(String babyId, DateRange range);
  Future<void> saveReading(BreathingReading reading);
  bool isBreathingIrregular(List<BreathingReading> readings);
  Future<void> triggerAlert(String babyId, BreathingReading reading);
}
```

#### Dashboard Integration
Update `_buildVitalItem` in dashboard to include breathing:
```dart
_buildVitalItem(Icons.air, '32', 'Breaths/min'),
```

#### Acceptance Criteria
- [ ] Real-time breath rate from device stream
- [ ] Age-appropriate normal range calculation
- [ ] Critical/low/elevated status detection
- [ ] Alert triggering for abnormal readings
- [ ] Dashboard widget displays current reading
- [ ] History view in vitals detail screen

---

### Task 1.2: Cry Detection & Classification

**Priority**: P1 - HIGH VALUE  
**Complexity**: High  
**Estimated Time**: 6-8 hours  
**Dependencies**: DeviceService, AIInsightsService

#### Rationale
Current: `bool isCrying` - only tells IF baby is crying.  
Parents need: WHY baby is crying (hungry, tired, pain, needs change, bored).

#### Files to Create
```
lib/models/cry_event_model.dart
lib/services/cry_detection_service.dart
lib/providers/cry_provider.dart
lib/widgets/dashboard/cry_indicator.dart
lib/screens/main/cry_history_screen.dart
test/models/cry_event_model_test.dart
test/services/cry_detection_service_test.dart
```

#### Model Definition

```dart
// lib/models/cry_event_model.dart
enum CryReason {
  hungry,
  tired,
  pain,
  wet,
  bored,
  overstimulated,
  unknown,
}

class CryEvent {
  final String id;
  final String babyId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final CryReason classifiedReason;
  final double confidence;
  final int intensityLevel; // 1-10
  final String? audioSnippetUrl;
  final bool wasAccurate; // Parent feedback
  final String? parentCorrectedReason;
  
  // Computed
  bool get isActive => endTime == null;
  bool get isHighIntensity => intensityLevel >= 7;
}

class CryPattern {
  final String babyId;
  final Map<CryReason, int> reasonFrequency;
  final Map<int, int> hourlyDistribution; // Hour -> count
  final Duration averageDuration;
  final List<String> triggers; // Identified patterns
}
```

#### Service Requirements

```dart
// lib/services/cry_detection_service.dart
class CryDetectionService {
  // Real-time detection
  Stream<CryEvent> watchCryEvents(String deviceId);
  Future<CryReason> classifyCry(String audioUrl);
  
  // History & patterns
  Future<List<CryEvent>> getCryHistory(String babyId, DateRange range);
  Future<CryPattern> analyzeCryPatterns(String babyId);
  
  // Feedback loop
  Future<void> submitAccuracyFeedback(String eventId, bool wasAccurate, CryReason? correction);
  
  // ML integration (placeholder for now)
  Future<void> trainOnFeedback(String babyId);
}
```

#### Dashboard Integration
Replace simple crying indicator with:
```dart
CryIndicator(
  isCrying: baby.latestVitals.isCrying,
  reason: baby.latestVitals.cryReason,
  confidence: baby.latestVitals.cryConfidence,
  onTap: () => context.push('/cry-history'),
)
```

#### Acceptance Criteria
- [ ] Real-time cry detection from audio stream
- [ ] Classification into 6 reason categories
- [ ] Confidence score displayed
- [ ] Parent feedback collection
- [ ] Cry history screen with patterns
- [ ] Dashboard integration

---

### Task 1.3: Position Detection (Camera-Based)

**Priority**: P1 - HIGH VALUE  
**Complexity**: Very High  
**Estimated Time**: 8-10 hours  
**Dependencies**: VideoStreamService, DeviceService

#### Rationale
Camera exists on AnvayaPod. Safe sleep = back sleeping. Parents want to know position.

#### Files to Create
```
lib/models/position_model.dart
lib/services/position_detection_service.dart
lib/widgets/dashboard/position_indicator.dart
test/models/position_model_test.dart
```

#### Model Definition

```dart
// lib/models/position_model.dart
enum SleepPosition {
  back,      // Safe - recommended
  side,      // Warning - may roll to stomach
  stomach,   // Alert - SIDS risk
  unknown,
}

enum PositionAlert {
  none,
  sideWarning,
  stomachCritical,
  movementDetected,
  outOfFrame,
}

class PositionReading {
  final String id;
  final String babyId;
  final SleepPosition position;
  final double confidence;
  final DateTime timestamp;
  final PositionAlert alert;
  final String? snapshotUrl;
}

class PositionSession {
  final String babyId;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<SleepPosition, Duration> positionDurations;
  final int rolloverCount;
  final List<PositionAlert> alerts;
}
```

#### Service Requirements

```dart
// lib/services/position_detection_service.dart
class PositionDetectionService {
  Stream<PositionReading> watchPosition(String deviceId);
  Future<void> enablePositionMonitoring(String deviceId);
  Future<void> disablePositionMonitoring(String deviceId);
  Future<PositionSession> getSessionSummary(String babyId, DateTime date);
  Future<void> triggerAlert(String babyId, PositionAlert alert);
  
  // Settings
  Future<void> setAlertPreferences(String userId, PositionAlertSettings settings);
}
```

#### Note
This requires ML model on device or cloud. Initially implement with placeholder that returns `unknown` until ML is integrated.

---

## 🟡 TIER 2: Resilience & Infrastructure

---

### Task 2.1: Offline Mode Implementation

**Priority**: P2 - IMPORTANT  
**Complexity**: High  
**Estimated Time**: 6-8 hours  
**Dependencies**: All services, Hive or SQLite

#### Rationale
Internet outage = parent panic. App must work offline with cached data.

#### Files to Create
```
lib/models/offline_queue_model.dart
lib/services/offline_sync_service.dart
lib/providers/connectivity_provider.dart
lib/core/offline_storage.dart
test/services/offline_sync_service_test.dart
```

#### Implementation Requirements

```dart
// lib/services/offline_sync_service.dart
class OfflineSyncService {
  // Connectivity
  Stream<ConnectivityStatus> get connectivityStream;
  bool get isOnline;
  
  // Caching
  Future<void> cacheVitals(LatestVitals vitals);
  Future<void> cachePhotos(List<PhotoModel> photos);
  Future<void> cacheBabyProfile(BabyModel baby);
  
  // Queue operations
  Future<void> queuePhotoUpload(String localPath, PhotoMetadata metadata);
  Future<void> queueMilestoneUpdate(String milestoneId, Map<String, dynamic> updates);
  
  // Sync
  Future<void> syncWhenOnline();
  Stream<SyncStatus> get syncStatusStream;
  
  // Retrieval
  Future<LatestVitals?> getCachedVitals(String babyId);
  Future<List<PhotoModel>> getCachedPhotos(String babyId);
}
```

#### Connectivity Provider

```dart
// lib/providers/connectivity_provider.dart
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityStatus _status = ConnectivityStatus.online;
  int _pendingUploads = 0;
  DateTime? _lastSyncTime;
  
  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  int get pendingUploads => _pendingUploads;
  
  Stream<ConnectivityStatus> watchConnectivity();
  Future<void> forcSync();
}
```

#### UI Requirements
- Offline banner at top of screen when disconnected
- "Pending uploads" indicator
- "Last synced X ago" in settings
- Graceful degradation of real-time features

#### Acceptance Criteria
- [ ] App opens and shows cached data when offline
- [ ] Photo uploads queue and sync when back online
- [ ] Vitals display "last known" with timestamp
- [ ] Clear visual indicator of offline state
- [ ] No crashes when offline

---

### Task 2.2: Video Streaming Service

**Priority**: P2 - IMPORTANT  
**Complexity**: High  
**Estimated Time**: 6-8 hours  
**Dependencies**: DeviceService, WiFi Provisioning

#### Files to Create
```
lib/services/video_stream_service.dart
lib/widgets/video/live_video_player.dart
lib/screens/main/live_video_screen.dart
test/services/video_stream_service_test.dart
```

#### Implementation Requirements

```dart
// lib/services/video_stream_service.dart
class VideoStreamService {
  // Connection
  Future<String> getStreamUrl(String deviceId);
  Future<void> startStream(String deviceId);
  Future<void> stopStream(String deviceId);
  
  // Quality
  Future<void> setStreamQuality(StreamQuality quality);
  Stream<StreamStatus> get statusStream;
  
  // Features
  Future<void> enableNightVision(String deviceId, bool enable);
  Future<void> captureSnapshot(String deviceId);
  Future<void> startRecording(String deviceId);
  Future<void> stopRecording(String deviceId);
  
  // Two-way audio
  Future<void> enableMicrophone(bool enable);
  Future<void> enableSpeaker(bool enable);
}

enum StreamQuality { low, medium, high, auto }
enum StreamStatus { connecting, live, buffering, error, disconnected }
```

#### Widget Requirements

```dart
// lib/widgets/video/live_video_player.dart
class LiveVideoPlayer extends StatefulWidget {
  final String deviceId;
  final bool showControls;
  final Function(String)? onSnapshotCaptured;
  
  // Controls: quality, night vision, snapshot, record, mute
}
```

---

## 🟢 TIER 3: Engagement Features

---

### Task 3.1: AI Insights Activation

**Priority**: P3 - ENGAGEMENT  
**Complexity**: Medium  
**Estimated Time**: 4-6 hours  
**Dependencies**: AIInsightsService (exists), All data services

#### Rationale
Infrastructure exists but no insights are generated. Need to connect data → insights.

#### Files to Modify
```
lib/services/ai_insights_service.dart
lib/providers/insights_provider.dart (new)
```

#### Implementation Requirements

```dart
// lib/providers/insights_provider.dart
class InsightsProvider extends ChangeNotifier {
  List<AIInsight> _insights = [];
  bool _isLoading = false;
  
  // Generation triggers
  Future<void> generateSleepInsight(List<SleepSession> sessions);
  Future<void> generateVitalsTrendInsight(List<VitalsReading> readings);
  Future<void> generateMilestoneInsight(String babyId, int ageInMonths);
  Future<void> generateCryPatternInsight(CryPattern pattern);
  
  // Scheduled generation
  Future<void> runDailyInsightGeneration(String babyId);
}
```

#### Insight Types to Implement
1. **Sleep Prediction**: "Based on patterns, baby will likely be tired around 2pm"
2. **Vital Trend**: "Temperature has been trending up over last 6 hours"
3. **Milestone Reminder**: "Most babies start crawling around this age"
4. **Cry Pattern**: "Baby tends to cry more between 5-7pm (witching hour)"
5. **Sleep Regression Warning**: "4-month sleep regression often occurs now"

#### Acceptance Criteria
- [ ] At least 5 insight types generated
- [ ] Insights refresh daily
- [ ] Confidence scores calculated
- [ ] Actionable recommendations included

---

### Task 3.2: Milestone Screen Implementation

**Priority**: P3 - ENGAGEMENT  
**Complexity**: Medium  
**Estimated Time**: 4-5 hours  
**Dependencies**: MilestoneProvider, MilestoneService

#### Files to Create
```
lib/screens/main/milestones_screen.dart
lib/widgets/milestones/milestone_card.dart
lib/widgets/milestones/milestone_timeline.dart
```

#### Screen Requirements
- Timeline view of milestones (completed + upcoming)
- Category filters (motor, cognitive, social, language)
- Completion percentage by category
- Photo attachment for completed milestones
- Age-appropriate suggestions
- Add custom milestone

---

### Task 3.3: Tips & Guidance Screen

**Priority**: P3 - ENGAGEMENT  
**Complexity**: Medium  
**Estimated Time**: 3-4 hours  
**Dependencies**: TipProvider, TipService

#### Files to Create
```
lib/screens/main/tips_screen.dart
lib/widgets/tips/tip_card.dart
lib/widgets/tips/tip_of_day_banner.dart
```

#### Screen Requirements
- Tip of the day prominent display
- Category browsing (sleep, feeding, development, safety)
- Dismissible tips
- Helpful/not helpful feedback
- Save favorites
- Age-appropriate filtering

---

## 🔵 TIER 4: Enhancement Features

---

### Task 4.1: Enhanced Dashboard Vitals

**Priority**: P4 - ENHANCEMENT  
**Complexity**: Low  
**Estimated Time**: 2-3 hours  
**Dependencies**: Tasks 1.1, 1.2, 1.3

#### Files to Modify
```
lib/screens/main/dashboard_screen.dart
lib/widgets/dashboard/vitals_grid.dart (new)
```

#### Requirements
Update vitals grid to include:
- SpO2 with status color
- Heart rate with status
- Temperature with status
- **NEW**: Breath rate with status
- **NEW**: Position indicator
- **NEW**: Cry reason (when crying)

---

### Task 4.2: Vitals History Screen

**Priority**: P4 - ENHANCEMENT  
**Complexity**: Medium  
**Estimated Time**: 4-5 hours  
**Dependencies**: All vital models and services

#### Files to Create
```
lib/screens/main/vitals_history_screen.dart
lib/widgets/vitals/vitals_chart.dart
lib/widgets/vitals/vital_detail_card.dart
```

#### Requirements
- Time-series charts for each vital
- Date range selector
- Export to PDF for doctor visits
- Abnormal reading highlights
- Trend indicators (improving/worsening)

---

### Task 4.3: Settings & Preferences Screen

**Priority**: P4 - ENHANCEMENT  
**Complexity**: Low  
**Estimated Time**: 2-3 hours  
**Dependencies**: None

#### Files to Create/Modify
```
lib/screens/settings/settings_screen.dart
lib/screens/settings/notification_settings_screen.dart
lib/screens/settings/alert_thresholds_screen.dart
lib/services/preferences_service.dart
```

#### Requirements
- Notification preferences
- Alert thresholds (custom vital ranges)
- Theme selection
- Unit preferences (°C/°F)
- Data export
- Account management
- Privacy settings

---

## 📊 Implementation Schedule

### Week 1: Foundation (TIER 0)
| Day | Tasks | Agent |
|-----|-------|-------|
| Mon | Task 0.1: MilestoneProvider | Agent 1 |
| Mon | Task 0.2: TipProvider | Agent 2 |
| Tue | Task 0.3: MilestoneService | Agent 1 |
| Tue | Task 0.4: TipService | Agent 2 |
| Wed | Integration testing | Both |

### Week 2: Core Sensors (TIER 1)
| Day | Tasks | Agent |
|-----|-------|-------|
| Mon-Tue | Task 1.1: Breath Rate | Agent 1 |
| Mon-Wed | Task 1.2: Cry Detection | Agent 2 |
| Thu-Fri | Task 1.3: Position Detection | Agent 1 |

### Week 3: Infrastructure (TIER 2)
| Day | Tasks | Agent |
|-----|-------|-------|
| Mon-Wed | Task 2.1: Offline Mode | Agent 1 |
| Mon-Wed | Task 2.2: Video Streaming | Agent 2 |
| Thu-Fri | Integration + testing | Both |

### Week 4: Engagement (TIER 3)
| Day | Tasks | Agent |
|-----|-------|-------|
| Mon-Tue | Task 3.1: AI Insights | Agent 1 |
| Mon-Tue | Task 3.2: Milestones Screen | Agent 2 |
| Wed-Thu | Task 3.3: Tips Screen | Agent 2 |
| Fri | Integration | Both |

### Week 5: Enhancement (TIER 4)
| Day | Tasks | Agent |
|-----|-------|-------|
| Mon | Task 4.1: Dashboard Vitals | Agent 1 |
| Tue-Wed | Task 4.2: Vitals History | Agent 1 |
| Mon-Tue | Task 4.3: Settings | Agent 2 |
| Thu-Fri | Final integration + QA | Both |

---

## 🎯 Agent Assignment Template

When assigning a task to an agent, use this template:

```markdown
## Task: [Task ID] - [Task Name]

### Context
[Brief description of why this task matters]

### Files to Create
- lib/...
- test/...

### Implementation Requirements
[Paste from task definition above]

### Acceptance Criteria
[Paste checklist from task definition]

### Dependencies
- [ ] [Dependency 1] - exists / needs to be created first
- [ ] [Dependency 2] - exists / needs to be created first

### Testing Requirements
- Unit tests: 90%+ coverage
- Integration tests: Key flows covered
- Manual testing: [Specific scenarios]

### Notes
[Any additional context or constraints]
```

---

## ✅ Definition of Done (All Tasks)

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] 90%+ test coverage for new code
- [ ] No new lint warnings
- [ ] Documentation updated (if public API)
- [ ] Registered in dependency injection (main.dart)
- [ ] Works in both online and offline (where applicable)
- [ ] Accessibility: screen reader compatible
- [ ] Performance: No jank, <100ms response time

---

## 📝 Notes for Agents

1. **Follow existing patterns** - Look at `PhotoProvider` and `PhotoService` as examples
2. **Use existing models** - Don't recreate, extend if needed
3. **Test with mocks** - Use `fake_cloud_firestore` and `mocktail`
4. **Provider registration** - Add to `MultiProvider` in `main.dart`
5. **Error handling** - Always catch and surface errors to UI
6. **Loading states** - Always track `isLoading` for UI feedback
7. **Null safety** - Use null-safe patterns throughout

---

*Last Updated: February 1, 2026*
*Next Review: After TIER 0 completion*
