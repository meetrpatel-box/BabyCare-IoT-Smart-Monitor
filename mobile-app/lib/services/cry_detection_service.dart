import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cry_event_model.dart';

/// Cry Detection Service
///
/// Handles the progressive cry detection pipeline:
/// 1. Edge detection (BLE) → immediate alert
/// 2. Edge classification → preliminary guess
/// 3. Cloud classification → confirmed result
/// 4. Analytics and trend computation
class CryDetectionService {
  final FirebaseFirestore _firestore;

  CryDetectionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cryCollection(String babyId) =>
      _firestore
          .collection('babies')
          .doc(babyId)
          .collection('cryEvents');

  // ==================== Event Streams ====================

  /// Stream cry events for a baby (real-time updates)
  Stream<List<CryEvent>> streamCryEvents(String babyId, {int limit = 20}) {
    return _cryCollection(babyId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CryEvent.fromFirestore(doc)).toList();
    });
  }

  /// Stream the latest active (ongoing) cry event
  Stream<CryEvent?> streamActiveCryEvent(String babyId) {
    return _cryCollection(babyId)
        .where('endTime', isNull: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CryEvent.fromFirestore(snapshot.docs.first);
    });
  }

  // ==================== Event Queries ====================

  /// Get cry events for a specific date range
  Future<List<CryEvent>> getCryEventsInRange(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _cryCollection(babyId)
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => CryEvent.fromFirestore(doc)).toList();
  }

  /// Get cry events for today
  Future<List<CryEvent>> getTodayCryEvents(String babyId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getCryEventsInRange(babyId, startOfDay, endOfDay);
  }

  /// Get the latest active (ongoing) cry event
  Future<CryEvent?> getActiveCryEvent(String babyId) async {
    final snapshot = await _cryCollection(babyId)
        .where('endTime', isNull: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return CryEvent.fromFirestore(snapshot.docs.first);
  }

  // ==================== Progressive Event Lifecycle ====================

  /// Step 1: Edge detects cry → create event with BLE data
  /// Called when BLE broadcast received from device
  Future<String> createFromEdgeDetection({
    required String babyId,
    required String deviceId,
    required double intensity,
    CrySensorContext? sensorContext,
    CryDataConsent dataConsent = CryDataConsent.featuresOnly,
  }) async {
    final now = DateTime.now();
    final event = CryEvent(
      id: '',
      babyId: babyId,
      deviceId: deviceId,
      startTime: now,
      intensity: intensity,
      createdAt: now,
      classification: CryClassification.unknown,
      classificationSource: ClassificationSource.edge,
      sensorContext: sensorContext,
      dataConsent: dataConsent,
    );

    final docRef = await _cryCollection(babyId).add(event.toFirestore());
    return docRef.id;
  }

  /// Step 2: Edge classifier gives preliminary result
  /// Called when BLE update received with classification
  Future<void> updateWithEdgeClassification({
    required String babyId,
    required String eventId,
    required CryClassification classification,
    required double confidence,
  }) async {
    await _cryCollection(babyId).doc(eventId).update({
      'edgeClassification': classification.name,
      'edgeConfidence': confidence,
      'classification': classification.name,
      'classificationSource': ClassificationSource.edge.name,
    });
  }

  /// Step 3: Cloud model returns final classification
  /// Called when Firestore listener detects cloud result
  Future<void> updateWithCloudClassification({
    required String babyId,
    required String eventId,
    required CryClassification classification,
    required double confidence,
    String? audioFeaturesPath,
    List<String>? keyFramesPaths,
  }) async {
    final updates = <String, dynamic>{
      'cloudClassification': classification.name,
      'cloudConfidence': confidence,
      // Cloud overrides edge as the active classification
      'classification': classification.name,
      'classificationSource': ClassificationSource.cloud.name,
    };

    if (audioFeaturesPath != null) {
      updates['audioFeaturesPath'] = audioFeaturesPath;
      updates['hasAudioFeatures'] = true;
    }
    if (keyFramesPaths != null) {
      updates['keyFramesPaths'] = keyFramesPaths;
      updates['hasKeyFrames'] = true;
    }

    await _cryCollection(babyId).doc(eventId).update(updates);
  }

  /// End an ongoing cry event
  Future<void> endCryEvent({
    required String babyId,
    required String eventId,
    required DateTime endTime,
  }) async {
    final doc = await _cryCollection(babyId).doc(eventId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final startTime = (data['startTime'] as Timestamp).toDate();
    final duration = endTime.difference(startTime).inSeconds;

    await _cryCollection(babyId).doc(eventId).update({
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': duration,
    });
  }

  /// Manually log a cry event (parent-initiated)
  Future<String> logManualCryEvent({
    required String babyId,
    required DateTime startTime,
    DateTime? endTime,
    CryClassification? classification,
    double? intensity,
  }) async {
    final event = CryEvent(
      id: '',
      babyId: babyId,
      startTime: startTime,
      endTime: endTime,
      durationSeconds:
          endTime != null ? endTime.difference(startTime).inSeconds : null,
      intensity: intensity,
      createdAt: DateTime.now(),
      classification: classification ?? CryClassification.unknown,
      classificationSource: ClassificationSource.heuristic,
    );

    final docRef = await _cryCollection(babyId).add(event.toFirestore());
    return docRef.id;
  }

  // ==================== Heuristic Classifier (Offline Fallback) ====================

  /// Classify cry type based on duration/intensity/time heuristics.
  /// Used as offline fallback when cloud is unavailable.
  CryClassification classifyCryPattern({
    required int durationSeconds,
    required double intensity,
    required DateTime timeOfDay,
  }) {
    final hour = timeOfDay.hour;
    final isNight = hour >= 22 || hour <= 6;

    if (durationSeconds < 30 && intensity > 0.8) {
      return CryClassification.pain;
    }
    if (durationSeconds > 120 && intensity < 0.6) {
      return CryClassification.tired;
    }
    if (isNight && intensity > 0.7) {
      return CryClassification.discomfort;
    }
    if (durationSeconds < 60 && intensity > 0.6) {
      return CryClassification.attention;
    }
    if (durationSeconds > 60 && intensity > 0.5) {
      return CryClassification.hungry;
    }
    return CryClassification.unknown;
  }

  // ==================== Training Data Queries ====================

  /// Get events that are ready for training export
  Future<List<CryEvent>> getExportReadyEvents(String babyId) async {
    final snapshot = await _cryCollection(babyId)
        .where('exportedToTraining', isEqualTo: false)
        .where('hasAudioFeatures', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => CryEvent.fromFirestore(doc))
        .where((e) => e.hasGroundTruth && e.dataConsent != CryDataConsent.none)
        .toList();
  }

  /// Mark events as exported to training dataset
  Future<void> markAsExported(
    String babyId,
    List<String> eventIds,
    String datasetVersion,
  ) async {
    final batch = _firestore.batch();
    for (final eventId in eventIds) {
      batch.update(_cryCollection(babyId).doc(eventId), {
        'exportedToTraining': true,
        'trainingDatasetVersion': datasetVersion,
      });
    }
    await batch.commit();
  }

  // ==================== Model Accuracy Tracking ====================

  /// Compute accuracy of cloud model vs parent corrections
  Future<ModelAccuracyReport> computeModelAccuracy(
    String babyId, {
    int days = 30,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final events = await getCryEventsInRange(babyId, startDate, endDate);

    // Only events with ground truth
    final labeled = events.where((e) => e.hasGroundTruth).toList();
    if (labeled.isEmpty) {
      return ModelAccuracyReport(
        totalLabeled: 0,
        edgeCorrect: 0,
        cloudCorrect: 0,
        edgeAccuracy: 0,
        cloudAccuracy: 0,
        confusionMatrix: {},
      );
    }

    int edgeCorrect = 0;
    int cloudCorrect = 0;
    int edgeTotal = 0;
    int cloudTotal = 0;
    final confusionMatrix =
        <CryClassification, Map<CryClassification, int>>{};

    for (final event in labeled) {
      final truth = event.groundTruthLabel!;

      if (event.edgeClassification != null) {
        edgeTotal++;
        if (event.edgeClassification == truth) edgeCorrect++;
      }

      if (event.cloudClassification != null) {
        cloudTotal++;
        if (event.cloudClassification == truth) cloudCorrect++;

        // Build confusion matrix: actual (truth) vs predicted (cloud)
        confusionMatrix
            .putIfAbsent(truth, () => {})
            .update(event.cloudClassification!, (v) => v + 1,
                ifAbsent: () => 1);
      }
    }

    return ModelAccuracyReport(
      totalLabeled: labeled.length,
      edgeCorrect: edgeCorrect,
      cloudCorrect: cloudCorrect,
      edgeAccuracy: edgeTotal > 0 ? edgeCorrect / edgeTotal : 0,
      cloudAccuracy: cloudTotal > 0 ? cloudCorrect / cloudTotal : 0,
      confusionMatrix: confusionMatrix,
    );
  }

  // ==================== Analytics ====================

  /// Get cry analytics for a period
  Future<CryAnalytics> getCryAnalytics(
    String babyId,
    int days,
  ) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final events = await getCryEventsInRange(babyId, startDate, endDate);

    if (events.isEmpty) {
      return CryAnalytics(
        totalCries: 0,
        avgDuration: 0,
        avgIntensity: 0,
        classificationBreakdown: {},
        peakHours: [],
        insights: ['No cry data available for this period'],
      );
    }

    final totalCries = events.length;
    final completedEvents = events.where((e) => e.endTime != null).toList();

    final avgDuration = completedEvents.isEmpty
        ? 0
        : completedEvents.fold<int>(
                0, (sum, e) => sum + (e.durationSeconds ?? 0)) /
            completedEvents.length;

    final eventsWithIntensity = events.where((e) => e.intensity != null);
    final avgIntensity = eventsWithIntensity.isEmpty
        ? 0.0
        : eventsWithIntensity.fold<double>(
                0, (sum, e) => sum + (e.intensity ?? 0)) /
            eventsWithIntensity.length;

    final Map<String, int> classificationBreakdown = {};
    for (final event in events) {
      final key = event.classification.name;
      classificationBreakdown[key] =
          (classificationBreakdown[key] ?? 0) + 1;
    }

    final hourCounts = List<int>.filled(24, 0);
    for (final event in events) {
      hourCounts[event.startTime.hour]++;
    }

    final maxCount = hourCounts.reduce((a, b) => a > b ? a : b);
    final peakHours = <int>[];
    for (int i = 0; i < 24; i++) {
      if (hourCounts[i] == maxCount && maxCount > 0) {
        peakHours.add(i);
      }
    }

    final insights = _generateCryInsights(
      totalCries: totalCries,
      avgDuration: avgDuration.round(),
      classificationBreakdown: classificationBreakdown,
      peakHours: peakHours,
      days: days,
    );

    return CryAnalytics(
      totalCries: totalCries,
      avgDuration: avgDuration.round(),
      avgIntensity: avgIntensity,
      classificationBreakdown: classificationBreakdown,
      peakHours: peakHours,
      insights: insights,
    );
  }

  List<String> _generateCryInsights({
    required int totalCries,
    required int avgDuration,
    required Map<String, int> classificationBreakdown,
    required List<int> peakHours,
    required int days,
  }) {
    final List<String> insights = [];

    final avgPerDay = totalCries / days;
    if (avgPerDay < 3) {
      insights.add('Low cry frequency - baby is generally content');
    } else if (avgPerDay > 10) {
      insights.add('High cry frequency - consider consulting pediatrician');
    }

    if (avgDuration > 180) {
      insights.add('Long average cry duration - baby may need extra comfort');
    } else if (avgDuration < 30) {
      insights.add('Short cry bursts - quick response is working well');
    }

    final mostCommon = classificationBreakdown.entries.isEmpty
        ? null
        : classificationBreakdown.entries
            .reduce((a, b) => a.value > b.value ? a : b);

    if (mostCommon != null) {
      switch (mostCommon.key) {
        case 'hungry':
          insights.add(
              'Most cries are hunger-related - consider adjusting feeding schedule');
          break;
        case 'tired':
          insights.add(
              'Fatigue is the main cause - ensure consistent sleep routine');
          break;
        case 'pain':
          insights.add('Frequent pain cries detected - consult pediatrician');
          break;
        case 'discomfort':
          insights.add(
              'Discomfort is common - check diaper, temperature, and clothing');
          break;
      }
    }

    if (peakHours.isNotEmpty) {
      final peakStr = peakHours.map((h) => '${h}:00').join(', ');
      if (peakHours.any((h) => h >= 18 && h <= 22)) {
        insights.add('Evening fussiness (witching hour) detected at $peakStr');
      } else {
        insights.add('Peak crying hours: $peakStr');
      }
    }

    if (insights.isEmpty) {
      insights.add('Cry patterns are normal for this age');
    }

    return insights;
  }

  /// Get cry frequency trend (cries per day)
  Future<List<CryTrend>> getCryTrends(
    String babyId,
    int days,
  ) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final events = await getCryEventsInRange(babyId, startDate, endDate);

    final Map<String, int> dailyCounts = {};
    for (final event in events) {
      final dateKey =
          '${event.startTime.year}-${event.startTime.month.toString().padLeft(2, '0')}-${event.startTime.day.toString().padLeft(2, '0')}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }

    final trends = <CryTrend>[];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      trends.add(CryTrend(
        date: date,
        count: dailyCounts[dateKey] ?? 0,
      ));
    }

    return trends;
  }
}

/// Cry analytics summary
class CryAnalytics {
  final int totalCries;
  final int avgDuration;
  final double avgIntensity;
  final Map<String, int> classificationBreakdown;
  final List<int> peakHours;
  final List<String> insights;

  CryAnalytics({
    required this.totalCries,
    required this.avgDuration,
    required this.avgIntensity,
    required this.classificationBreakdown,
    required this.peakHours,
    required this.insights,
  });
}

/// Cry frequency trend for charting
class CryTrend {
  final DateTime date;
  final int count;

  CryTrend({required this.date, required this.count});
}

/// Model accuracy report for admin panel
class ModelAccuracyReport {
  final int totalLabeled;
  final int edgeCorrect;
  final int cloudCorrect;
  final double edgeAccuracy;
  final double cloudAccuracy;
  final Map<CryClassification, Map<CryClassification, int>> confusionMatrix;

  ModelAccuracyReport({
    required this.totalLabeled,
    required this.edgeCorrect,
    required this.cloudCorrect,
    required this.edgeAccuracy,
    required this.cloudAccuracy,
    required this.confusionMatrix,
  });
}
