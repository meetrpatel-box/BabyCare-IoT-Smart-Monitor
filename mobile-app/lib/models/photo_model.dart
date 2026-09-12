import 'package:cloud_firestore/cloud_firestore.dart';

/// Photo model for baby photos with data context
///
/// Each photo stores:
/// - Basic metadata (URL, timestamps, uploader)
/// - AI-generated tags (mood, activity, people)
/// - Data context (vitals at time of capture)
/// - Engagement data (likes, comments, views)
class PhotoModel {
  final String id;
  final String babyId;
  final String uploadedBy;
  final String photoUrl;
  final String thumbnailUrl;
  final DateTime capturedAt;
  final DateTime uploadedAt;

  final AIPhotoTags aiTags;
  final PhotoDataContext? dataContext;

  final String? caption;
  final List<String> manualTags;
  final List<String> albumIds;

  final int viewCount;
  final List<String> likedBy;
  final int commentsCount;

  final List<String> sharedWith;
  final bool isPublic;
  final bool isArchived;
  final DateTime? deletedAt;

  PhotoModel({
    required this.id,
    required this.babyId,
    required this.uploadedBy,
    required this.photoUrl,
    required this.thumbnailUrl,
    required this.capturedAt,
    required this.uploadedAt,
    required this.aiTags,
    this.dataContext,
    this.caption,
    this.manualTags = const [],
    this.albumIds = const [],
    this.viewCount = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    this.sharedWith = const [],
    this.isPublic = false,
    this.isArchived = false,
    this.deletedAt,
  });

  /// Create from Firestore document
  factory PhotoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PhotoModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? data['photoUrl'] ?? '',
      capturedAt:
          (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedAt:
          (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aiTags:
          AIPhotoTags.fromMap(data['aiTags'] as Map<String, dynamic>? ?? {}),
      dataContext: data['dataContext'] != null
          ? PhotoDataContext.fromMap(
              data['dataContext'] as Map<String, dynamic>)
          : null,
      caption: data['caption'] as String?,
      manualTags: List<String>.from(data['manualTags'] ?? []),
      albumIds: List<String>.from(data['albumIds'] ?? []),
      viewCount: data['viewCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      isPublic: data['isPublic'] ?? false,
      isArchived: data['isArchived'] ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'uploadedBy': uploadedBy,
      'photoUrl': photoUrl,
      'thumbnailUrl': thumbnailUrl,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'aiTags': aiTags.toMap(),
      if (dataContext != null) 'dataContext': dataContext!.toMap(),
      if (caption != null) 'caption': caption,
      'manualTags': manualTags,
      'albumIds': albumIds,
      'viewCount': viewCount,
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'sharedWith': sharedWith,
      'isPublic': isPublic,
      'isArchived': isArchived,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  /// Create a copy with updated fields
  PhotoModel copyWith({
    String? id,
    String? babyId,
    String? uploadedBy,
    String? photoUrl,
    String? thumbnailUrl,
    DateTime? capturedAt,
    DateTime? uploadedAt,
    AIPhotoTags? aiTags,
    PhotoDataContext? dataContext,
    String? caption,
    List<String>? manualTags,
    List<String>? albumIds,
    int? viewCount,
    List<String>? likedBy,
    int? commentsCount,
    List<String>? sharedWith,
    bool? isPublic,
    bool? isArchived,
    DateTime? deletedAt,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      photoUrl: photoUrl ?? this.photoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      aiTags: aiTags ?? this.aiTags,
      dataContext: dataContext ?? this.dataContext,
      caption: caption ?? this.caption,
      manualTags: manualTags ?? this.manualTags,
      albumIds: albumIds ?? this.albumIds,
      viewCount: viewCount ?? this.viewCount,
      likedBy: likedBy ?? this.likedBy,
      commentsCount: commentsCount ?? this.commentsCount,
      sharedWith: sharedWith ?? this.sharedWith,
      isPublic: isPublic ?? this.isPublic,
      isArchived: isArchived ?? this.isArchived,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Check if photo is liked by a specific user
  bool isLikedBy(String userId) => likedBy.contains(userId);

  /// Get formatted time since capture
  String get timeSinceCapture {
    final diff = DateTime.now().difference(capturedAt);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()} year${diff.inDays >= 730 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} month${diff.inDays >= 60 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() =>
      'PhotoModel(id: $id, babyId: $babyId, capturedAt: $capturedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// AI-generated tags for photo classification
///
/// These are populated by ML model analysis of the photo
class AIPhotoTags {
  /// Detected mood: happy, calm, crying, sleeping, alert, unknown
  final String mood;

  /// Detected activity: feeding, playing, sleeping, bath, tummy_time, outdoor, unknown
  final String activity;

  /// Detected people in photo (mom, dad, grandma, sibling, etc.)
  final List<String> people;

  /// Location if available from EXIF or manual entry
  final String? location;

  /// AI confidence score (0.0 - 1.0)
  final double confidence;

  AIPhotoTags({
    required this.mood,
    required this.activity,
    this.people = const [],
    this.location,
    this.confidence = 0.0,
  });

  /// Create default tags (for manual uploads before AI processing)
  factory AIPhotoTags.empty() {
    return AIPhotoTags(
      mood: 'unknown',
      activity: 'unknown',
      people: [],
      confidence: 0.0,
    );
  }

  factory AIPhotoTags.fromMap(Map<String, dynamic> map) {
    return AIPhotoTags(
      mood: map['mood'] as String? ?? 'unknown',
      activity: map['activity'] as String? ?? 'unknown',
      people: List<String>.from(map['people'] ?? []),
      location: map['location'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'activity': activity,
      'people': people,
      if (location != null) 'location': location,
      'confidence': confidence,
    };
  }

  /// Check if AI has processed this photo
  bool get isProcessed => confidence > 0.0 && mood != 'unknown';

  /// Get mood emoji for display
  String get moodEmoji {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'crying':
        return '😢';
      case 'sleeping':
        return '😴';
      case 'alert':
        return '👀';
      default:
        return '📷';
    }
  }

  /// Get activity emoji for display
  String get activityEmoji {
    switch (activity) {
      case 'feeding':
        return '🍼';
      case 'playing':
        return '🎮';
      case 'sleeping':
        return '🛏️';
      case 'bath':
        return '🛁';
      case 'tummy_time':
        return '🤸';
      case 'outdoor':
        return '🌳';
      default:
        return '📷';
    }
  }

  AIPhotoTags copyWith({
    String? mood,
    String? activity,
    List<String>? people,
    String? location,
    double? confidence,
  }) {
    return AIPhotoTags(
      mood: mood ?? this.mood,
      activity: activity ?? this.activity,
      people: people ?? this.people,
      location: location ?? this.location,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() =>
      'AIPhotoTags(mood: $mood, activity: $activity, confidence: $confidence)';
}

/// Vital data context captured at time of photo
///
/// Links photos to health data for meaningful context cards
class PhotoDataContext {
  /// Heart rate in BPM
  final int? heartRate;

  /// Temperature in Fahrenheit
  final double? temperature;

  /// Blood oxygen saturation (SpO2) percentage
  final int? spO2;

  /// Sleep quality score (0-100)
  final int? sleepScore;

  /// Whether baby was sleeping at time of photo
  final bool isSleeping;

  /// Duration of current sleep session in minutes
  final int? sleepDuration;

  /// Detected mood from vitals analysis
  final String? mood;

  /// Room temperature in Fahrenheit
  final double? roomTemp;

  /// Breathing rate in breaths per minute
  final int? breathingRate;

  PhotoDataContext({
    this.heartRate,
    this.temperature,
    this.spO2,
    this.sleepScore,
    this.isSleeping = false,
    this.sleepDuration,
    this.mood,
    this.roomTemp,
    this.breathingRate,
  });

  /// Create empty context (no vitals data available)
  factory PhotoDataContext.empty() {
    return PhotoDataContext();
  }

  factory PhotoDataContext.fromMap(Map<String, dynamic> map) {
    return PhotoDataContext(
      heartRate: map['heartRate'] as int?,
      temperature: (map['temperature'] as num?)?.toDouble(),
      spO2: map['spO2'] as int?,
      sleepScore: map['sleepScore'] as int?,
      isSleeping: map['isSleeping'] as bool? ?? false,
      sleepDuration: map['sleepDuration'] as int?,
      mood: map['mood'] as String?,
      roomTemp: (map['roomTemp'] as num?)?.toDouble(),
      breathingRate: map['breathingRate'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (heartRate != null) 'heartRate': heartRate,
      if (temperature != null) 'temperature': temperature,
      if (spO2 != null) 'spO2': spO2,
      if (sleepScore != null) 'sleepScore': sleepScore,
      'isSleeping': isSleeping,
      if (sleepDuration != null) 'sleepDuration': sleepDuration,
      if (mood != null) 'mood': mood,
      if (roomTemp != null) 'roomTemp': roomTemp,
      if (breathingRate != null) 'breathingRate': breathingRate,
    };
  }

  /// Check if any vitals data is available
  bool get hasData =>
      heartRate != null ||
      temperature != null ||
      spO2 != null ||
      sleepScore != null ||
      sleepDuration != null;

  /// Get heart rate status
  String get heartRateStatus {
    if (heartRate == null) return 'Unknown';
    if (heartRate! < 100) return 'Calm';
    if (heartRate! < 140) return 'Normal';
    if (heartRate! < 160) return 'Active';
    return 'Excited';
  }

  /// Get temperature status
  String get temperatureStatus {
    if (temperature == null) return 'Unknown';
    if (temperature! < 97.0) return 'Low';
    if (temperature! <= 99.5) return 'Normal';
    if (temperature! <= 100.4) return 'Elevated';
    return 'Fever';
  }

  /// Get SpO2 status
  String get spO2Status {
    if (spO2 == null) return 'Unknown';
    if (spO2! >= 95) return 'Normal';
    if (spO2! >= 90) return 'Low';
    return 'Critical';
  }

  /// Get sleep score rating
  String get sleepScoreRating {
    if (sleepScore == null) return 'Unknown';
    if (sleepScore! >= 90) return 'Excellent';
    if (sleepScore! >= 75) return 'Good';
    if (sleepScore! >= 60) return 'Fair';
    return 'Poor';
  }

  /// Format sleep duration as human readable string
  String get sleepDurationFormatted {
    if (sleepDuration == null) return '';
    final hours = sleepDuration! ~/ 60;
    final minutes = sleepDuration! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  PhotoDataContext copyWith({
    int? heartRate,
    double? temperature,
    int? spO2,
    int? sleepScore,
    bool? isSleeping,
    int? sleepDuration,
    String? mood,
    double? roomTemp,
    int? breathingRate,
  }) {
    return PhotoDataContext(
      heartRate: heartRate ?? this.heartRate,
      temperature: temperature ?? this.temperature,
      spO2: spO2 ?? this.spO2,
      sleepScore: sleepScore ?? this.sleepScore,
      isSleeping: isSleeping ?? this.isSleeping,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      mood: mood ?? this.mood,
      roomTemp: roomTemp ?? this.roomTemp,
      breathingRate: breathingRate ?? this.breathingRate,
    );
  }

  @override
  String toString() =>
      'PhotoDataContext(heartRate: $heartRate, temp: $temperature, spO2: $spO2, sleepScore: $sleepScore)';
}

/// Available mood types for filtering
class PhotoMood {
  static const String happy = 'happy';
  static const String calm = 'calm';
  static const String crying = 'crying';
  static const String sleeping = 'sleeping';
  static const String alert = 'alert';
  static const String unknown = 'unknown';

  static List<String> get all =>
      [happy, calm, crying, sleeping, alert, unknown];
}

/// Available activity types for filtering
class PhotoActivity {
  static const String feeding = 'feeding';
  static const String playing = 'playing';
  static const String sleeping = 'sleeping';
  static const String bath = 'bath';
  static const String tummyTime = 'tummy_time';
  static const String outdoor = 'outdoor';
  static const String unknown = 'unknown';

  static List<String> get all =>
      [feeding, playing, sleeping, bath, tummyTime, outdoor, unknown];
}
