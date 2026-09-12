import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_call_session.dart';

/// Service for managing video calls with baby monitor device
class VideoCallService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  VideoCallSession? _currentSession;
  
  VideoCallService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  VideoCallSession? get currentSession => _currentSession;
  bool get isInCall => _currentSession?.isActive ?? false;
  
  /// Start video call session
  Future<VideoCallSession> startVideoCall({
    required String deviceId,
    required String userId,
    StreamQuality quality = StreamQuality.medium,
  }) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }
    
    try {
      // Create session ID
      final sessionId = _firestore.collection('video_sessions').doc().id;
      
      // Create session object
      final session = VideoCallSession(
        sessionId: sessionId,
        deviceId: deviceId,
        userId: userId,
        state: CameraSessionState.connecting,
        quality: quality,
        startedAt: DateTime.now(),
      );
      
      // Write to Firestore
      await _firestore
          .collection('video_sessions')
          .doc(sessionId)
          .set(session.toJson());
      
      // Send command to device
      await _sendCameraCommand(deviceId, 'start_camera', {
        'sessionId': sessionId,
        'quality': quality.name,
        'userId': userId,
      });
      
      _currentSession = session;
      notifyListeners();
      
      debugPrint('[VideoCall] Started session: $sessionId');
      return session;
      
    } catch (e) {
      debugPrint('[VideoCall] Error starting call: $e');
      rethrow;
    }
  }
  
  /// End video call session
  Future<void> endVideoCall(String sessionId) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty');
    }
    
    try {
      // Get session document to find deviceId and check if it exists
      final sessionDoc = await _firestore
          .collection('video_sessions')
          .doc(sessionId)
          .get();
      
      // Only update if session exists  
      if (sessionDoc.exists) {
        // Update session state in Firestore
        await _firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update({
          'state': CameraSessionState.disconnected.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
        
        final deviceId = sessionDoc.data()?['deviceId'] as String?;
        if (deviceId != null) {
          // Send stop command to device
          await _sendCameraCommand(deviceId, 'stop_camera', {
            'sessionId': sessionId,
          });
        }
        
        debugPrint('[VideoCall] Ended session: $sessionId');
      } else {
        debugPrint('[VideoCall] Session not found: $sessionId');
      }
      
      // Clear current session if it matches
      if (_currentSession?.sessionId == sessionId) {
        _currentSession = null;
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('[VideoCall] Error ending call: $e');
      rethrow;
    }
  }
  
  /// Change video quality during call
  Future<void> changeQuality(String sessionId, StreamQuality quality) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty');
    }
    
    try {
      final session = _currentSession;
      if (session == null || session.sessionId != sessionId) {
        throw StateError('No active session');
      }
      
      await _firestore
          .collection('video_sessions')
          .doc(sessionId)
          .update({'quality': quality.name});
      
      await _sendCameraCommand(session.deviceId, 'change_quality', {
        'sessionId': sessionId,
        'quality': quality.name,
      });
      
      _currentSession = session.copyWith(quality: quality);
      notifyListeners();
      
      debugPrint('[VideoCall] Changed quality to: ${quality.name}');
      
    } catch (e) {
      debugPrint('[VideoCall] Error changing quality: $e');
      rethrow;
    }
  }
  
  /// Capture snapshot from video stream
  Future<CameraSnapshot> captureSnapshot({
    required String sessionId,
    required String deviceId,
    required String userId,
  }) async {
    if (sessionId.isEmpty || deviceId.isEmpty || userId.isEmpty) {
      throw ArgumentError('All IDs must be provided');
    }
    
    try {
      // Send snapshot command
      await _sendCameraCommand(deviceId, 'capture_snapshot', {
        'sessionId': sessionId,
      });
      
      // Wait for snapshot to be uploaded
      // In real implementation, this would listen to a completion event
      await Future.delayed(const Duration(seconds: 2));
      
      // Create snapshot record (device would upload to Firebase Storage)
      final snapshotId = _firestore.collection('camera_snapshots').doc().id;
      final snapshot = CameraSnapshot(
        id: snapshotId,
        deviceId: deviceId,
        userId: userId,
        sessionId: sessionId,
        capturedAt: DateTime.now(),
        imageUrl: 'gs://baby-care-app.appspot.com/snapshots/$deviceId/$snapshotId.jpg',
        width: 640,
        height: 480,
        sizeBytes: 102400, // Placeholder
      );
      
      await _firestore
          .collection('camera_snapshots')
          .doc(snapshotId)
          .set(snapshot.toJson());
      
      debugPrint('[VideoCall] Captured snapshot: $snapshotId');
      return snapshot;
      
    } catch (e) {
      debugPrint('[VideoCall] Error capturing snapshot: $e');
      rethrow;
    }
  }
  
  /// Listen to session updates
  Stream<VideoCallSession> watchSession(String sessionId) {
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty');
    }
    
    return _firestore
        .collection('video_sessions')
        .doc(sessionId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Session not found: $sessionId');
      }
      
      final session = VideoCallSession.fromJson(
        snapshot.data() as Map<String, dynamic>,
      );
      
      _currentSession = session;
      notifyListeners();
      
      return session;
    });
  }
  
  /// Get session history for a device
  Stream<List<VideoCallSession>> getSessionHistory(String deviceId) {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    
    return _firestore
        .collection('video_sessions')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VideoCallSession.fromJson(doc.data()))
          .toList();
    });
  }
  
  /// Get snapshots for a device
  Stream<List<CameraSnapshot>> getSnapshots(String deviceId) {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    
    return _firestore
        .collection('camera_snapshots')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('capturedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CameraSnapshot.fromJson(doc.data()))
          .toList();
    });
  }
  
  /// Send camera command to device via Firestore
  Future<void> _sendCameraCommand(
    String deviceId,
    String command,
    Map<String, dynamic> params,
  ) async {
    await _firestore.collection('device_commands').add({
      'deviceId': deviceId,
      'command': command,
      ...params,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    debugPrint('[VideoCall] Sent command: $command to $deviceId');
  }
  
  /// Update session with WebRTC signaling data
  Future<void> updateSignalingData(
    String sessionId,
    Map<String, dynamic> signalingData,
  ) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty');
    }
    
    try {
      await _firestore
          .collection('video_sessions')
          .doc(sessionId)
          .update({'signalingData': signalingData});
      
      if (_currentSession?.sessionId == sessionId) {
        _currentSession = _currentSession!.copyWith(
          signalingData: signalingData,
        );
        notifyListeners();
      }
      
      debugPrint('[VideoCall] Updated signaling data');
      
    } catch (e) {
      debugPrint('[VideoCall] Error updating signaling: $e');
      rethrow;
    }
  }
  
  /// Clean up old sessions (called periodically)
  Future<void> cleanupOldSessions({int maxAgeHours = 24}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: maxAgeHours));
      
      final oldSessions = await _firestore
          .collection('video_sessions')
          .where('startedAt', isLessThan: cutoff)
          .where('state', isEqualTo: CameraSessionState.disconnected.name)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldSessions.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('[VideoCall] Cleaned up ${oldSessions.docs.length} old sessions');
      
    } catch (e) {
      debugPrint('[VideoCall] Error cleaning up sessions: $e');
    }
  }
}
