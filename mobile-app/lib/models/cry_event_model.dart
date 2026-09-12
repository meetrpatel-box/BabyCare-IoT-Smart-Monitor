import 'package:cloud_firestore/cloud_firestore.dart';

/// Cry classification types from ML models
enum CryClassification {
  hungry,
  tired,
  pain,
  discomfort,
  gassy,
  attention,
  overstimulated,
  colic,
  unknown;

  String get label {
    switch (this) {
      case CryClassification.hungry:
        return 'Hungry';
      case CryClassification.tired:
        return 'Tired';
      case CryClassification.pain:
        return 'Pain';
      case CryClassification.discomfort:
        return 'Discomfort';
      case CryClassification.gassy:
        return 'Gassy';
      case CryClassification.attention:
        return 'Attention';
      case CryClassification.overstimulated:
        return 'Overstimulated';
      case CryClassification.colic:
        return 'Colic';
      case CryClassification.unknown:
        return 'Unknown';
    }
  }

  static CryClassification fromString(String? value) {
    if (value == null) return CryClassification.unknown;
    return CryClassification.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CryClassification.unknown,
    );
  }
}

/// Source of the classification result
enum ClassificationSource {
  edge,
  cloud,
  heuristic,
  parentCorrected;

  static ClassificationSource fromString(String? value) {
    if (value == null) return ClassificationSource.heuristic;
    return ClassificationSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ClassificationSource.heuristic,
    );
  }
}

/// Data consent level for ML training data collection
enum CryDataConsent {
  /// Only extracted features (mel spectrogram, MFCC) — no raw audio
  featuresOnly,

  /// Features + raw audio clip shared for training
  fullAudio,

  /// No data shared — detection still works locally
  none;

  static CryDataConsent fromString(String? value) {
    if (value == null) return CryDataConsent.featuresOnly;
    return CryDataConsent.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CryDataConsent.featuresOnly,
    );
  }
}

/// What action resolved the cry (from parent feedback)
enum CryResolution {
  fed,
  diaperChange,
  rocked,
  held,
  pacifier,
  sleep,
  other,
  selfResolved;

  String get label {
    switch (this) {
      case CryResolution.fed:
        return 'Fed';
      case CryResolution.diaperChange:
        return 'Diaper Change';
      case CryResolution.rocked:
        return 'Rocked';
      case CryResolution.held:
        return 'Held';
      case CryResolution.pacifier:
        return 'Pacifier';
      case CryResolution.sleep:
        return 'Fell Asleep';
      case CryResolution.other:
        return 'Other';
      case CryResolution.selfResolved:
        return 'Self-Resolved';
    }
  }

  static CryResolution fromString(String? value) {
    if (value == null) return CryResolution.other;
    return CryResolution.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CryResolution.other,
    );
  }
}

/// Sensor context captured at the time of cry detection
class CrySensorContext {
  final int? heartRate;
  final int? breathRate;
  final double? bodyTemp;
  final double? envTemp;
  final double? humidity;
  final int? lastFeedMinutesAgo;
  final int? awakeMinutes;
  final int? lastDiaperMinutesAgo;
  final String? timeOfDay; // morning, afternoon, evening, night

  const CrySensorContext({
    this.heartRate,
    this.breathRate,
    this.bodyTemp,
    this.envTemp,
    this.humidity,
    this.lastFeedMinutesAgo,
    this.awakeMinutes,
    this.lastDiaperMinutesAgo,
    this.timeOfDay,
  });

  factory CrySensorContext.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const CrySensorContext();
    return CrySensorContext(
      heartRate: data['heartRate'] as int?,
      breathRate: data['breathRate'] as int?,
      bodyTemp: (data['bodyTemp'] as num?)?.toDouble(),
      envTemp: (data['envTemp'] as num?)?.toDouble(),
      humidity: (data['humidity'] as num?)?.toDouble(),
      lastFeedMinutesAgo: data['lastFeedMinutesAgo'] as int?,
      awakeMinutes: data['awakeMinutes'] as int?,
      lastDiaperMinutesAgo: data['lastDiaperMinutesAgo'] as int?,
      timeOfDay: data['timeOfDay'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (heartRate != null) 'heartRate': heartRate,
      if (breathRate != null) 'breathRate': breathRate,
      if (bodyTemp != null) 'bodyTemp': bodyTemp,
      if (envTemp != null) 'envTemp': envTemp,
      if (humidity != null) 'humidity': humidity,
      if (lastFeedMinutesAgo != null)
        'lastFeedMinutesAgo': lastFeedMinutesAgo,
      if (awakeMinutes != null) 'awakeMinutes': awakeMinutes,
      if (lastDiaperMinutesAgo != null)
        'lastDiaperMinutesAgo': lastDiaperMinutesAgo,
      if (timeOfDay != null) 'timeOfDay': timeOfDay,
    };
  }

  /// Derive time-of-day label from a DateTime
  static String timeOfDayLabel(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }
}

/// Enhanced cry event model with ML training data fields
///
/// Stored in: babies/{babyId}/cryEvents/{eventId}
class CryEvent {
  final String id;
  final String babyId;
  final String? deviceId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final double? intensity;
  final DateTime createdAt;

  // --- Classification results (progressive: edge → cloud → parent) ---

  /// Edge device's initial classification (TFLite on-device)
  final CryClassification? edgeClassification;
  final double? edgeConfidence;

  /// Cloud model's classification (YAMNet fine-tuned + fusion)
  final CryClassification? cloudClassification;
  final double? cloudConfidence;

  /// The "active" classification shown to user (best available)
  final CryClassification classification;
  final ClassificationSource classificationSource;

  // --- Parent feedback (ground truth for training) ---

  /// Parent confirmed the classification was correct
  final bool parentConfirmed;

  /// Parent corrected to a different type (ground truth label)
  final CryClassification? parentCorrectedType;
  final DateTime? correctedAt;

  /// What action actually resolved the cry
  final CryResolution? resolution;

  // --- ML training data references ---

  /// Paths to stored feature data in Firebase Storage
  final String? audioFeaturesPath;
  final String? rawAudioPath;
  final List<String>? keyFramesPaths;

  final bool hasAudioFeatures;
  final bool hasRawAudio;
  final bool hasKeyFrames;

  // --- Sensor context snapshot ---
  final CrySensorContext? sensorContext;

  // --- Training pipeline metadata ---
  final CryDataConsent dataConsent;
  final bool exportedToTraining;
  final String? trainingDatasetVersion;

  /// The ground truth label for ML training.
  /// Priority: parentCorrectedType > parentConfirmed cloudClassification > cloudClassification
  CryClassification? get groundTruthLabel {
    if (parentCorrectedType != null) return parentCorrectedType;
    if (parentConfirmed && cloudClassification != null) {
      return cloudClassification;
    }
    return null;
  }

  /// Whether this event has a usable label for training
  bool get hasGroundTruth => groundTruthLabel != null;

  /// Whether this event is ready for export to training pipeline
  bool get isExportReady =>
      hasGroundTruth &&
      hasAudioFeatures &&
      !exportedToTraining &&
      dataConsent != CryDataConsent.none;

  CryEvent({
    required this.id,
    required this.babyId,
    this.deviceId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.intensity,
    required this.createdAt,
    this.edgeClassification,
    this.edgeConfidence,
    this.cloudClassification,
    this.cloudConfidence,
    this.classification = CryClassification.unknown,
    this.classificationSource = ClassificationSource.heuristic,
    this.parentConfirmed = false,
    this.parentCorrectedType,
    this.correctedAt,
    this.resolution,
    this.audioFeaturesPath,
    this.rawAudioPath,
    this.keyFramesPaths,
    this.hasAudioFeatures = false,
    this.hasRawAudio = false,
    this.hasKeyFrames = false,
    this.sensorContext,
    this.dataConsent = CryDataConsent.featuresOnly,
    this.exportedToTraining = false,
    this.trainingDatasetVersion,
  });

  factory CryEvent.fromMap(Map<String, dynamic> data) {
    return CryEvent(
      id: data['id'] as String? ?? '',
      babyId: data['babyId'] ?? '',
      deviceId: data['deviceId'] as String?,
      startTime:
          (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      durationSeconds: data['durationSeconds'] as int?,
      intensity: (data['intensity'] as num?)?.toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      edgeClassification:
          CryClassification.fromString(data['edgeClassification'] as String?),
      edgeConfidence: (data['edgeConfidence'] as num?)?.toDouble(),
      cloudClassification:
          CryClassification.fromString(data['cloudClassification'] as String?),
      cloudConfidence: (data['cloudConfidence'] as num?)?.toDouble(),
      classification:
          CryClassification.fromString(data['classification'] as String?),
      classificationSource: ClassificationSource.fromString(
          data['classificationSource'] as String?),
      parentConfirmed: data['parentConfirmed'] as bool? ?? false,
      parentCorrectedType: data['parentCorrectedType'] != null
          ? CryClassification.fromString(
              data['parentCorrectedType'] as String?)
          : null,
      correctedAt: (data['correctedAt'] as Timestamp?)?.toDate(),
      resolution: data['resolution'] != null
          ? CryResolution.fromString(data['resolution'] as String?)
          : null,
      audioFeaturesPath: data['audioFeaturesPath'] as String?,
      rawAudioPath: data['rawAudioPath'] as String?,
      keyFramesPaths: (data['keyFramesPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hasAudioFeatures: data['hasAudioFeatures'] as bool? ?? false,
      hasRawAudio: data['hasRawAudio'] as bool? ?? false,
      hasKeyFrames: data['hasKeyFrames'] as bool? ?? false,
      sensorContext: CrySensorContext.fromMap(
          data['sensorContext'] as Map<String, dynamic>?),
      dataConsent:
          CryDataConsent.fromString(data['dataConsent'] as String?),
      exportedToTraining: data['exportedToTraining'] as bool? ?? false,
      trainingDatasetVersion: data['trainingDatasetVersion'] as String?,
    );
  }

  factory CryEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CryEvent(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      deviceId: data['deviceId'] as String?,
      startTime:
          (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      durationSeconds: data['durationSeconds'] as int?,
      intensity: (data['intensity'] as num?)?.toDouble(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      edgeClassification:
          CryClassification.fromString(data['edgeClassification'] as String?),
      edgeConfidence: (data['edgeConfidence'] as num?)?.toDouble(),
      cloudClassification:
          CryClassification.fromString(data['cloudClassification'] as String?),
      cloudConfidence: (data['cloudConfidence'] as num?)?.toDouble(),
      classification:
          CryClassification.fromString(data['classification'] as String?),
      classificationSource: ClassificationSource.fromString(
          data['classificationSource'] as String?),
      parentConfirmed: data['parentConfirmed'] as bool? ?? false,
      parentCorrectedType: data['parentCorrectedType'] != null
          ? CryClassification.fromString(
              data['parentCorrectedType'] as String?)
          : null,
      correctedAt: (data['correctedAt'] as Timestamp?)?.toDate(),
      resolution: data['resolution'] != null
          ? CryResolution.fromString(data['resolution'] as String?)
          : null,
      audioFeaturesPath: data['audioFeaturesPath'] as String?,
      rawAudioPath: data['rawAudioPath'] as String?,
      keyFramesPaths: (data['keyFramesPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hasAudioFeatures: data['hasAudioFeatures'] as bool? ?? false,
      hasRawAudio: data['hasRawAudio'] as bool? ?? false,
      hasKeyFrames: data['hasKeyFrames'] as bool? ?? false,
      sensorContext: CrySensorContext.fromMap(
          data['sensorContext'] as Map<String, dynamic>?),
      dataConsent:
          CryDataConsent.fromString(data['dataConsent'] as String?),
      exportedToTraining: data['exportedToTraining'] as bool? ?? false,
      trainingDatasetVersion: data['trainingDatasetVersion'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      if (deviceId != null) 'deviceId': deviceId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationSeconds': durationSeconds,
      'intensity': intensity,
      'createdAt': Timestamp.fromDate(createdAt),
      'edgeClassification': edgeClassification?.name,
      'edgeConfidence': edgeConfidence,
      'cloudClassification': cloudClassification?.name,
      'cloudConfidence': cloudConfidence,
      'classification': classification.name,
      'classificationSource': classificationSource.name,
      'parentConfirmed': parentConfirmed,
      'parentCorrectedType': parentCorrectedType?.name,
      'correctedAt':
          correctedAt != null ? Timestamp.fromDate(correctedAt!) : null,
      'resolution': resolution?.name,
      'audioFeaturesPath': audioFeaturesPath,
      'rawAudioPath': rawAudioPath,
      'keyFramesPaths': keyFramesPaths,
      'hasAudioFeatures': hasAudioFeatures,
      'hasRawAudio': hasRawAudio,
      'hasKeyFrames': hasKeyFrames,
      'sensorContext': sensorContext?.toMap(),
      'dataConsent': dataConsent.name,
      'exportedToTraining': exportedToTraining,
      'trainingDatasetVersion': trainingDatasetVersion,
    };
  }

  CryEvent copyWith({
    String? id,
    String? babyId,
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? intensity,
    DateTime? createdAt,
    CryClassification? edgeClassification,
    double? edgeConfidence,
    CryClassification? cloudClassification,
    double? cloudConfidence,
    CryClassification? classification,
    ClassificationSource? classificationSource,
    bool? parentConfirmed,
    CryClassification? parentCorrectedType,
    DateTime? correctedAt,
    CryResolution? resolution,
    String? audioFeaturesPath,
    String? rawAudioPath,
    List<String>? keyFramesPaths,
    bool? hasAudioFeatures,
    bool? hasRawAudio,
    bool? hasKeyFrames,
    CrySensorContext? sensorContext,
    CryDataConsent? dataConsent,
    bool? exportedToTraining,
    String? trainingDatasetVersion,
  }) {
    return CryEvent(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      deviceId: deviceId ?? this.deviceId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      intensity: intensity ?? this.intensity,
      createdAt: createdAt ?? this.createdAt,
      edgeClassification: edgeClassification ?? this.edgeClassification,
      edgeConfidence: edgeConfidence ?? this.edgeConfidence,
      cloudClassification: cloudClassification ?? this.cloudClassification,
      cloudConfidence: cloudConfidence ?? this.cloudConfidence,
      classification: classification ?? this.classification,
      classificationSource: classificationSource ?? this.classificationSource,
      parentConfirmed: parentConfirmed ?? this.parentConfirmed,
      parentCorrectedType: parentCorrectedType ?? this.parentCorrectedType,
      correctedAt: correctedAt ?? this.correctedAt,
      resolution: resolution ?? this.resolution,
      audioFeaturesPath: audioFeaturesPath ?? this.audioFeaturesPath,
      rawAudioPath: rawAudioPath ?? this.rawAudioPath,
      keyFramesPaths: keyFramesPaths ?? this.keyFramesPaths,
      hasAudioFeatures: hasAudioFeatures ?? this.hasAudioFeatures,
      hasRawAudio: hasRawAudio ?? this.hasRawAudio,
      hasKeyFrames: hasKeyFrames ?? this.hasKeyFrames,
      sensorContext: sensorContext ?? this.sensorContext,
      dataConsent: dataConsent ?? this.dataConsent,
      exportedToTraining: exportedToTraining ?? this.exportedToTraining,
      trainingDatasetVersion:
          trainingDatasetVersion ?? this.trainingDatasetVersion,
    );
  }
}
