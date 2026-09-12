import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for controlling device features remotely (music, camera, etc.)
class DeviceControlService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  
  DeviceControlService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Play audio on device
  /// 
  /// Sends MQTT command via Firestore trigger (Cloud Function publishes to MQTT)
  Future<bool> playAudio(
    String deviceId,
    String trackId, {
    int volume = 50,
    bool loop = false,
  }) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    if (trackId.isEmpty) {
      throw ArgumentError('trackId cannot be empty');
    }
    if (volume < 0 || volume > 100) {
      throw ArgumentError('volume must be between 0 and 100');
    }

    try {
      // Write command to Firestore
      // Cloud Function will pick it up and publish to MQTT
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'play_audio',
        'track': trackId,
        'volume': volume,
        'loop': loop,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent play_audio command: $trackId');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error sending play command: $e');
      rethrow;
    }
  }
  
  /// Stop audio playback
  Future<bool> stopAudio(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }

    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'stop_audio',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent stop_audio command');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error sending stop command: $e');
      return false;
    }
  }
  
  /// Pause audio playback
  Future<bool> pauseAudio(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }

    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'pause_audio',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent pause_audio command');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error sending pause command: $e');
      return false;
    }
  }
  
  /// Resume audio playback
  Future<bool> resumeAudio(String deviceId) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }

    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'resume_audio',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent resume_audio command');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error sending resume command: $e');
      return false;
    }
  }
  
  /// Set device volume
  Future<bool> setDeviceVolume(String deviceId, int volume) async {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    if (volume < 0 || volume > 100) {
      throw ArgumentError('volume must be between 0 and 100');
    }

    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'set_volume',
        'volume': volume,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent set_volume command: $volume');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error sending volume command: $e');
      rethrow;
    }
  }
  
  /// Listen to audio status updates from device
  Stream<DocumentSnapshot> getAudioStatus(String deviceId) {
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }

    return _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('status')
        .doc('audio')
        .snapshots();
  }
  
  /// Future: Camera control
  Future<bool> toggleCamera(String deviceId, bool enabled) async {
    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'set_camera',
        'enabled': enabled,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent camera toggle: $enabled');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error toggling camera: $e');
      return false;
    }
  }
  
  /// Future: Two-way audio (talk to baby)
  Future<bool> startTwoWayAudio(String deviceId) async {
    try {
      await _firestore
          .collection('device_commands')
          .add({
        'deviceId': deviceId,
        'command': 'start_two_way_audio',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      debugPrint('[DeviceControl] Sent start two-way audio command');
      return true;
    } catch (e) {
      debugPrint('[DeviceControl] Error starting two-way audio: $e');
      return false;
    }
  }
}
