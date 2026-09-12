import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cry_event_model.dart';
import 'cry_detection_service.dart';

/// Manages the progressive cry alert lifecycle.
///
/// Alert progression:
/// T+0.5s (BLE): "Baby is crying!"
/// T+2s   (BLE): "Preliminary: hungry"
/// T+5s   (Cloud): "Confirmed: HUNGRY (89%)"
///
/// Also handles:
/// - Alert deduplication (don't spam for rapid cry events)
/// - Offline fallback (BLE-only alerts when WiFi is down)
/// - Suggestion generation based on classification + context
class CryAlertService {
  final CryDetectionService _detectionService;
  final FirebaseFirestore _firestore;

  /// Minimum time between new alerts for the same baby (debounce)
  static const _alertCooldown = Duration(minutes: 2);

  /// Track last alert time per baby to avoid spam
  final Map<String, DateTime> _lastAlertTimes = {};

  /// Active event ID per baby (the event currently being tracked)
  final Map<String, String> _activeEventIds = {};

  /// Stream controller for alert updates
  final _alertController = StreamController<CryAlert>.broadcast();

  /// Listen to progressive alert updates
  Stream<CryAlert> get alertStream => _alertController.stream;

  CryAlertService({
    required CryDetectionService detectionService,
    FirebaseFirestore? firestore,
  })  : _detectionService = detectionService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Handle incoming BLE cry detection (Tier 1: instant alert)
  Future<void> handleBleDetection({
    required String babyId,
    required String deviceId,
    required double intensity,
    CrySensorContext? sensorContext,
    CryDataConsent dataConsent = CryDataConsent.featuresOnly,
  }) async {
    // Debounce: skip if we just alerted for this baby
    final lastAlert = _lastAlertTimes[babyId];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert) < _alertCooldown) {
      return;
    }

    // Create event in Firestore
    final eventId = await _detectionService.createFromEdgeDetection(
      babyId: babyId,
      deviceId: deviceId,
      intensity: intensity,
      sensorContext: sensorContext,
      dataConsent: dataConsent,
    );

    _lastAlertTimes[babyId] = DateTime.now();
    _activeEventIds[babyId] = eventId;

    // Emit Tier 1 alert
    _alertController.add(CryAlert(
      eventId: eventId,
      babyId: babyId,
      tier: AlertTier.detection,
      title: 'Baby is crying!',
      subtitle: 'Intensity: ${(intensity * 100).round()}%',
      classification: null,
      confidence: null,
      suggestion: null,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle incoming BLE classification update (Tier 2: preliminary)
  Future<void> handleBleClassification({
    required String babyId,
    required CryClassification classification,
    required double confidence,
  }) async {
    final eventId = _activeEventIds[babyId];
    if (eventId == null) return;

    // Update Firestore
    await _detectionService.updateWithEdgeClassification(
      babyId: babyId,
      eventId: eventId,
      classification: classification,
      confidence: confidence,
    );

    // Emit Tier 2 alert
    _alertController.add(CryAlert(
      eventId: eventId,
      babyId: babyId,
      tier: AlertTier.preliminary,
      title: 'Preliminary: ${classification.label}',
      subtitle: 'Confidence: ${(confidence * 100).round()}%',
      classification: classification,
      confidence: confidence,
      suggestion: null,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle cloud classification result (Tier 3: confirmed)
  Future<void> handleCloudClassification({
    required String babyId,
    required String eventId,
    required CryClassification classification,
    required double confidence,
    CrySensorContext? sensorContext,
    String? audioFeaturesPath,
    List<String>? keyFramesPaths,
  }) async {
    // Update Firestore
    await _detectionService.updateWithCloudClassification(
      babyId: babyId,
      eventId: eventId,
      classification: classification,
      confidence: confidence,
      audioFeaturesPath: audioFeaturesPath,
      keyFramesPaths: keyFramesPaths,
    );

    // Generate suggestion based on classification + context
    final suggestion = _generateSuggestion(classification, sensorContext);

    // Emit Tier 3 alert
    _alertController.add(CryAlert(
      eventId: eventId,
      babyId: babyId,
      tier: AlertTier.confirmed,
      title: 'Confirmed: ${classification.label}',
      subtitle: 'Confidence: ${(confidence * 100).round()}%',
      classification: classification,
      confidence: confidence,
      suggestion: suggestion,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle cry stopped
  Future<void> handleCryEnded({
    required String babyId,
  }) async {
    final eventId = _activeEventIds.remove(babyId);
    if (eventId == null) return;

    await _detectionService.endCryEvent(
      babyId: babyId,
      eventId: eventId,
      endTime: DateTime.now(),
    );

    _alertController.add(CryAlert(
      eventId: eventId,
      babyId: babyId,
      tier: AlertTier.resolved,
      title: 'Crying stopped',
      subtitle: null,
      classification: null,
      confidence: null,
      suggestion: null,
      timestamp: DateTime.now(),
    ));
  }

  /// Get the active event ID for a baby (if currently crying)
  String? getActiveEventId(String babyId) => _activeEventIds[babyId];

  /// Generate a contextual suggestion based on classification and sensor data
  String _generateSuggestion(
    CryClassification classification,
    CrySensorContext? context,
  ) {
    final feedInfo = context?.lastFeedMinutesAgo != null
        ? 'Last fed ${context!.lastFeedMinutesAgo} min ago. '
        : '';
    final awakeInfo = context?.awakeMinutes != null
        ? 'Awake for ${context!.awakeMinutes} min. '
        : '';
    final diaperInfo = context?.lastDiaperMinutesAgo != null
        ? 'Last diaper ${context!.lastDiaperMinutesAgo} min ago. '
        : '';

    switch (classification) {
      case CryClassification.hungry:
        return '${feedInfo}Try offering a feed.';
      case CryClassification.tired:
        return '${awakeInfo}Try rocking or putting down for a nap.';
      case CryClassification.pain:
        return 'Check for discomfort signs. Consult pediatrician if persistent.';
      case CryClassification.discomfort:
        return '${diaperInfo}Check diaper, temperature, and clothing.';
      case CryClassification.gassy:
        return 'Try gentle tummy massage or bicycle legs.';
      case CryClassification.attention:
        return 'Baby may want interaction. Try talking or holding.';
      case CryClassification.overstimulated:
        return 'Move to a quiet, dim environment. Reduce stimulation.';
      case CryClassification.colic:
        return 'Try white noise, swaddling, or gentle motion. This is normal and will pass.';
      case CryClassification.unknown:
        return 'Check on baby. ${feedInfo}${diaperInfo}';
    }
  }

  /// Clean up resources
  void dispose() {
    _alertController.close();
  }
}

/// The progression tier of a cry alert
enum AlertTier {
  /// Tier 1: Binary detection from edge (<500ms)
  detection,

  /// Tier 2: Preliminary classification from edge (1-3s)
  preliminary,

  /// Tier 3: Confirmed classification from cloud (3-8s)
  confirmed,

  /// Cry has stopped
  resolved,
}

/// A progressive cry alert update
class CryAlert {
  final String eventId;
  final String babyId;
  final AlertTier tier;
  final String title;
  final String? subtitle;
  final CryClassification? classification;
  final double? confidence;
  final String? suggestion;
  final DateTime timestamp;

  const CryAlert({
    required this.eventId,
    required this.babyId,
    required this.tier,
    required this.title,
    this.subtitle,
    this.classification,
    this.confidence,
    this.suggestion,
    required this.timestamp,
  });
}
