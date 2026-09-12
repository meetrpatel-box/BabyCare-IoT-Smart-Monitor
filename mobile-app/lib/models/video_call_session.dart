import 'package:flutter/foundation.dart';

/// Camera stream quality levels
enum StreamQuality {
  low,     // 320x240, 10fps - Low bandwidth
  medium,  // 640x480, 15fps - Balanced
  high,    // 1280x720, 30fps - High quality
}

/// Camera session state
enum CameraSessionState {
  disconnected,
  connecting,
  connected,
  streaming,
  error,
}

/// Video call session model
class VideoCallSession {
  final String sessionId;
  final String deviceId;
  final String userId;
  final CameraSessionState state;
  final StreamQuality quality;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? streamUrl;
  final String? errorMessage;
  
  /// WebRTC signaling data
  final Map<String, dynamic>? signalingData;
  
  /// MJPEG fallback frame data (for testing without WebRTC relay)
  final String? latestFrameUrl;
  final int frameCount;

  /// Session statistics
  final int? fps;
  final int? bitrate;
  final String? resolution;

  const VideoCallSession({
    required this.sessionId,
    required this.deviceId,
    required this.userId,
    required this.state,
    required this.quality,
    required this.startedAt,
    this.endedAt,
    this.streamUrl,
    this.errorMessage,
    this.signalingData,
    this.latestFrameUrl,
    this.frameCount = 0,
    this.fps,
    this.bitrate,
    this.resolution,
  });
  
  /// Create from Firestore document
  factory VideoCallSession.fromJson(Map<String, dynamic> json) {
    return VideoCallSession(
      sessionId: json['sessionId'] as String,
      deviceId: json['deviceId'] as String,
      userId: json['userId'] as String,
      state: CameraSessionState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => CameraSessionState.disconnected,
      ),
      quality: StreamQuality.values.firstWhere(
        (e) => e.name == json['quality'],
        orElse: () => StreamQuality.medium,
      ),
      startedAt: _parseDateTime(json['startedAt']),
      endedAt: _parseDateTime(json['endedAt']),
      streamUrl: json['streamUrl'] as String?,
      errorMessage: json['errorMessage'] as String?,
      signalingData: json['signalingData'] as Map<String, dynamic>?,
      latestFrameUrl: json['latestFrameUrl'] as String?,
      frameCount: json['frameCount'] as int? ?? 0,
      fps: json['fps'] as int?,
      bitrate: json['bitrate'] as int?,
      resolution: json['resolution'] as String?,
    );
  }
  
  /// Parse DateTime from Firestore (handles both DateTime and Timestamp)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    // Handle Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
    return DateTime.now();
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'userId': userId,
      'state': state.name,
      'quality': quality.name,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'streamUrl': streamUrl,
      'errorMessage': errorMessage,
      'signalingData': signalingData,
      'latestFrameUrl': latestFrameUrl,
      'frameCount': frameCount,
      'fps': fps,
      'bitrate': bitrate,
      'resolution': resolution,
    };
  }
  
  /// Copy with updated properties
  VideoCallSession copyWith({
    String? sessionId,
    String? deviceId,
    String? userId,
    CameraSessionState? state,
    StreamQuality? quality,
    DateTime? startedAt,
    DateTime? endedAt,
    String? streamUrl,
    String? errorMessage,
    Map<String, dynamic>? signalingData,
    String? latestFrameUrl,
    int? frameCount,
    int? fps,
    int? bitrate,
    String? resolution,
  }) {
    return VideoCallSession(
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      state: state ?? this.state,
      quality: quality ?? this.quality,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      streamUrl: streamUrl ?? this.streamUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      signalingData: signalingData ?? this.signalingData,
      latestFrameUrl: latestFrameUrl ?? this.latestFrameUrl,
      frameCount: frameCount ?? this.frameCount,
      fps: fps ?? this.fps,
      bitrate: bitrate ?? this.bitrate,
      resolution: resolution ?? this.resolution,
    );
  }
  
  /// Check if session is active (connecting, connected, or streaming)
  bool get isActive => state == CameraSessionState.connecting ||
                       state == CameraSessionState.streaming || 
                       state == CameraSessionState.connected;
  
  /// Get session duration
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }
  
  @override
  String toString() {
    return 'VideoCallSession(id: $sessionId, device: $deviceId, state: $state)';
  }
}

/// Camera snapshot model
class CameraSnapshot {
  final String id;
  final String deviceId;
  final String userId;
  final String? sessionId; // Optional - snapshot might not be tied to a session
  final DateTime capturedAt;
  final String imageUrl;
  final String? thumbnailUrl;
  final int width;
  final int height;
  final int sizeBytes;
  
  const CameraSnapshot({
    required this.id,
    required this.deviceId,
    required this.userId,
    this.sessionId,
    required this.capturedAt,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });
  
  factory CameraSnapshot.fromJson(Map<String, dynamic> json) {
    return CameraSnapshot(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      userId: json['userId'] as String,
      sessionId: json['sessionId'] as String?,
      capturedAt: VideoCallSession._parseDateTime(json['capturedAt']),
      imageUrl: json['imageUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      width: json['width'] as int? ?? 640,
      height: json['height'] as int? ?? 480,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'userId': userId,
      'sessionId': sessionId,
      'capturedAt': capturedAt,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'width': width,
      'height': height,
      'sizeBytes': sizeBytes,
    };
  }
}
