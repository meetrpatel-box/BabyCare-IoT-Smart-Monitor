import 'package:baby_track_flutter/models/video_call_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Test fixtures for video call integration tests
class VideoCallFixtures {
  // Test device IDs
  static const String deviceId1 = 'test-device-001';
  static const String deviceId2 = 'test-device-002';
  
  // Test user IDs
  static const String userId1 = 'test-user-001';
  static const String userId2 = 'test-user-002';
  
  // Session IDs
  static const String sessionId1 = 'test-session-001';
  static const String sessionId2 = 'test-session-002';
  static const String sessionId3 = 'test-session-003';
  
  /// Sample video call session in connecting state
  static VideoCallSession get connectingSession => VideoCallSession(
    sessionId: sessionId1,
    deviceId: deviceId1,
    userId: userId1,
    state: CameraSessionState.connecting,
    quality: StreamQuality.medium,
    startedAt: DateTime.now(),
  );
  
  /// Sample video call session in streaming state
  static VideoCallSession get streamingSession => VideoCallSession(
    sessionId: sessionId2,
    deviceId: deviceId1,
    userId: userId1,
    state: CameraSessionState.streaming,
    quality: StreamQuality.medium,
    startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    streamUrl: 'https://test-stream-url.com/video',
    fps: 15,
    bitrate: 512000,
    resolution: '640x480',
  );
  
  /// Sample video call session with high quality
  static VideoCallSession get highQualitySession => VideoCallSession(
    sessionId: sessionId3,
    deviceId: deviceId2,
    userId: userId2,
    state: CameraSessionState.streaming,
    quality: StreamQuality.high,
    startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    streamUrl: 'https://test-stream-url.com/hd-video',
    fps: 30,
    bitrate: 2000000,
    resolution: '1280x720',
  );
  
  /// Sample disconnected session (ended)
  static VideoCallSession get disconnectedSession => VideoCallSession(
    sessionId: 'test-session-ended',
    deviceId: deviceId1,
    userId: userId1,
    state: CameraSessionState.disconnected,
    quality: StreamQuality.low,
    startedAt: DateTime.now().subtract(const Duration(hours: 1)),
    endedAt: DateTime.now().subtract(const Duration(minutes: 50)),
  );
  
  /// Sample session with error
  static VideoCallSession get errorSession => VideoCallSession(
    sessionId: 'test-session-error',
    deviceId: deviceId1,
    userId: userId1,
    state: CameraSessionState.error,
    quality: StreamQuality.medium,
    startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    errorMessage: 'Camera initialization failed',
  );
  
  /// Sample camera snapshot
  static CameraSnapshot get snapshot1 => CameraSnapshot(
    id: 'test-snapshot-001',
    deviceId: deviceId1,
    userId: userId1,
    sessionId: sessionId1,
    capturedAt: DateTime.now(),
    imageUrl: 'gs://test-bucket/snapshots/snapshot-001.jpg',
    thumbnailUrl: 'gs://test-bucket/snapshots/snapshot-001_thumb.jpg',
    width: 1280,
    height: 720,
    sizeBytes: 245678,
  );
  
  /// Sample camera snapshot with different dimensions
  static CameraSnapshot get snapshot2 => CameraSnapshot(
    id: 'test-snapshot-002',
    deviceId: deviceId1,
    userId: userId1,
    sessionId: sessionId1,
    capturedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    imageUrl: 'gs://test-bucket/snapshots/snapshot-002.jpg',
    thumbnailUrl: 'gs://test-bucket/snapshots/snapshot-002_thumb.jpg',
    width: 640,
    height: 480,
    sizeBytes: 98234,
  );
  
  /// Create a start_camera command document
  static Map<String, dynamic> startCameraCommand({
    String? deviceId,
    String? sessionId,
    StreamQuality quality = StreamQuality.medium,
  }) => {
    'deviceId': deviceId ?? deviceId1,
    'command': 'start_camera',
    'sessionId': sessionId ?? sessionId1,
    'quality': quality.name,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  /// Create a stop_camera command document
  static Map<String, dynamic> stopCameraCommand({
    String? deviceId,
    String? sessionId,
  }) => {
    'deviceId': deviceId ?? deviceId1,
    'command': 'stop_camera',
    'sessionId': sessionId ?? sessionId1,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  /// Create a change_quality command document
  static Map<String, dynamic> changeQualityCommand({
    String? deviceId,
    String? sessionId,
    required StreamQuality quality,
  }) => {
    'deviceId': deviceId ?? deviceId1,
    'command': 'change_quality',
    'sessionId': sessionId ?? sessionId1,
    'quality': quality.name,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  /// Create a capture_snapshot command document
  static Map<String, dynamic> captureSnapshotCommand({
    String? deviceId,
    String? sessionId,
  }) => {
    'deviceId': deviceId ?? deviceId1,
    'command': 'capture_snapshot',
    'sessionId': sessionId ?? sessionId1,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  /// Create session update data (for simulating device responses)
  static Map<String, dynamic> streamingStateUpdate({
    int fps = 15,
    int bitrate = 512000,
    String resolution = '640x480',
    String? streamUrl,
  }) => {
    'state': CameraSessionState.streaming.name,
    'fps': fps,
    'bitrate': bitrate,
    'resolution': resolution,
    'streamUrl': streamUrl ?? 'https://test-stream-url.com/video',
    'updatedAt': FieldValue.serverTimestamp(),
  };
  
  /// Create disconnected state update
  static Map<String, dynamic> disconnectedStateUpdate() => {
    'state': CameraSessionState.disconnected.name,
    'endedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  
  /// Create error state update
  static Map<String, dynamic> errorStateUpdate(String errorMessage) => {
    'state': CameraSessionState.error.name,
    'errorMessage': errorMessage,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
