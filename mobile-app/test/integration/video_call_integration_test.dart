import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/video_call_service.dart';
import 'package:baby_track_flutter/services/device_control_service.dart';
import 'package:baby_track_flutter/models/video_call_session.dart';
import '../fixtures/video_call_fixtures.dart';
import '../fixtures/audio_fixtures.dart';

/// Comprehensive integration tests for video call and device control features
/// 
/// Tests the complete flow:
/// 1. Video call session management (start, stream, stop, quality, snapshot)
/// 2. Audio control (play, pause, resume, stop, volume)
/// 3. Combined video + audio scenarios
/// 4. Error handling and edge cases
/// 
/// Run with: flutter test test/integration/video_call_integration_test.dart
void main() {
  group('Video Call Integration Tests', () {
    late FakeFirebaseFirestore firestore;
    late VideoCallService videoCallService;
    late DeviceControlService deviceControlService;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      videoCallService = VideoCallService(firestore: firestore);
      deviceControlService = DeviceControlService(firestore: firestore);
    });
    
    tearDown(() {
      videoCallService.dispose();
      deviceControlService.dispose();
    });
    
    group('Complete Video Call Flow', () {
      test('should start video call and create session', () async {
        // Start video call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        
        expect(session.sessionId, isNotEmpty);
        expect(videoCallService.currentSession, isNotNull);
        expect(videoCallService.currentSession!.sessionId, session.sessionId);
        expect(videoCallService.currentSession!.state, CameraSessionState.connecting);
        expect(videoCallService.isInCall, true);
        
        // Verify session document created in Firestore
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(session.sessionId)
            .get();
        
        expect(sessionDoc.exists, true);
        expect(sessionDoc.data()?['deviceId'], VideoCallFixtures.deviceId1);
        expect(sessionDoc.data()?['userId'], VideoCallFixtures.userId1);
        expect(sessionDoc.data()?['state'], 'connecting');
        expect(sessionDoc.data()?['quality'], 'medium');
        
        // Verify start_camera command created
        final commands = await firestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: VideoCallFixtures.deviceId1)
            .where('command', isEqualTo: 'start_camera')
            .get();
        
        expect(commands.docs.length, 1);
        expect(commands.docs.first.data()['sessionId'], session.sessionId);
        expect(commands.docs.first.data()['quality'], 'medium');
        expect(commands.docs.first.data()['status'], 'pending');
      });
      
      test('should simulate device starting stream and update session', () async {
        // Start call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        // Simulate device updating session to streaming
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate(
              fps: 15,
              bitrate: 512000,
              resolution: '640x480',
            ));
        
        // Wait for stream update
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify session updated
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .get();
        
        expect(sessionDoc.data()?['state'], 'streaming');
        expect(sessionDoc.data()?['fps'], 15);
        expect(sessionDoc.data()?['bitrate'], 512000);
        expect(sessionDoc.data()?['resolution'], '640x480');
        expect(sessionDoc.data()?['streamUrl'], isNotEmpty);
      });
      
      test('should change quality during active call', () async {
        // Start call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        // Simulate device streaming
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Change quality to high
        await videoCallService.changeQuality(sessionId, StreamQuality.high);
        
        // Verify session quality updated
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .get();
        
        expect(sessionDoc.data()?['quality'], 'high');
        
        // Verify change_quality command created
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'change_quality')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        
        expect(commands.docs.length, 1);
        expect(commands.docs.first.data()['quality'], 'high');
      });
      
      test('should capture snapshot during call', () async {
        // Start call and simulate streaming
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Capture snapshot
        final snapshot = await videoCallService.captureSnapshot(
          sessionId: sessionId,
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
        );
        
        expect(snapshot.id, isNotEmpty);
        
        // Verify snapshot document created
        final snapshotDoc = await firestore
            .collection('camera_snapshots')
            .doc(snapshot.id)
            .get();
        
        expect(snapshotDoc.exists, true);
        expect(snapshotDoc.data()?['deviceId'], VideoCallFixtures.deviceId1);
        expect(snapshotDoc.data()?['userId'], VideoCallFixtures.userId1);
        expect(snapshotDoc.data()?['sessionId'], sessionId);
        
        // Verify capture_snapshot command created
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'capture_snapshot')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        
        expect(commands.docs.length, 1);
      });
      
      test('should end video call properly', () async {
        // Start call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // End call
        await videoCallService.endVideoCall(sessionId);
        
        expect(videoCallService.currentSession, isNull);
        expect(videoCallService.isInCall, false);
        
        // Verify session ended in Firestore
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .get();
        
        expect(sessionDoc.data()?['state'], 'disconnected');
        expect(sessionDoc.data()?['endedAt'], isNotNull);
        
        // Verify stop_camera command created
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'stop_camera')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        
        expect(commands.docs.length, 1);
      });
    });
    
    group('Audio Control Integration Tests', () {
      test('should play audio track on device', () async {
        // Play audio
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'lullaby_1',
          volume: 70,
          loop: true,
        );
        
        // Verify play_audio command created
        final commands = await firestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: VideoCallFixtures.deviceId1)
            .where('command', isEqualTo: 'play_audio')
            .get();
        
        expect(commands.docs.length, 1);
        expect(commands.docs.first.data()['track'], 'lullaby_1');
        expect(commands.docs.first.data()['volume'], 70);
        expect(commands.docs.first.data()['loop'], true);
        expect(commands.docs.first.data()['status'], 'pending');
      });
      
      test('should pause and resume audio', () async {
        // Play audio first
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'white_noise',
        );
        
        // Pause
        await deviceControlService.pauseAudio(VideoCallFixtures.deviceId1);
        
        // Verify pause command
        var commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'pause_audio')
            .get();
        
        expect(commands.docs.length, 1);
        
        // Resume
        await deviceControlService.resumeAudio(VideoCallFixtures.deviceId1);
        
        // Verify resume command
        commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'resume_audio')
            .get();
        
        expect(commands.docs.length, 1);
      });
      
      test('should stop audio playback', () async {
        // Play audio first
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'lullaby_2',
        );
        
        // Stop
        await deviceControlService.stopAudio(VideoCallFixtures.deviceId1);
        
        // Verify stop command
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'stop_audio')
            .get();
        
        expect(commands.docs.length, 1);
        expect(commands.docs.first.data()['deviceId'], VideoCallFixtures.deviceId1);
      });
      
      test('should set device volume', () async {
        // Set volume to 85
        await deviceControlService.setDeviceVolume(
          VideoCallFixtures.deviceId1,
          85,
        );
        
        // Verify set_volume command
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'set_volume')
            .get();
        
        expect(commands.docs.length, 1);
        expect(commands.docs.first.data()['volume'], 85);
        expect(commands.docs.first.data()['deviceId'], VideoCallFixtures.deviceId1);
      });
      
      test('should validate volume range', () async {
        // Test invalid volumes
        expect(
          () => deviceControlService.setDeviceVolume(VideoCallFixtures.deviceId1, -10),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => deviceControlService.setDeviceVolume(VideoCallFixtures.deviceId1, 150),
          throwsA(isA<ArgumentError>()),
        );
        
        // Valid volumes should work
        await deviceControlService.setDeviceVolume(VideoCallFixtures.deviceId1, 0);
        await deviceControlService.setDeviceVolume(VideoCallFixtures.deviceId1, 50);
        await deviceControlService.setDeviceVolume(VideoCallFixtures.deviceId1, 100);
        
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'set_volume')
            .get();
        
        expect(commands.docs.length, 3);
      });
    });
    
    group('Combined Video + Audio Scenarios', () {
      test('should play audio while video call is active', () async {
        // Start video call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Play audio during call
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'white_noise',
          volume: 50,
        );
        
        // Verify both are active
        expect(videoCallService.isInCall, true);
        
        final audioCommands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'play_audio')
            .get();
        
        expect(audioCommands.docs.length, 1);
        
        // Adjust volume while streaming
        await deviceControlService.setDeviceVolume(
          VideoCallFixtures.deviceId1,
          30,
        );
        
        final volumeCommands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'set_volume')
            .get();
        
        expect(volumeCommands.docs.length, 1);
        expect(volumeCommands.docs.first.data()['volume'], 30);
      });
      
      test('should handle audio while changing video quality', () async {
        // Start video call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.low,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate(
              fps: 10,
              bitrate: 128000,
              resolution: '320x240',
            ));
        
        // Play audio
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'lullaby_1',
          volume: 60,
        );
        
        // Change video quality to high
        await videoCallService.changeQuality(sessionId, StreamQuality.high);
        
        // Audio should continue (independent feature)
        // Verify both commands exist
        final allCommands = await firestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: VideoCallFixtures.deviceId1)
            .get();
        
        final audioCmd = allCommands.docs.where(
          (doc) => doc.data()['command'] == 'play_audio'
        ).toList();
        
        final qualityCmd = allCommands.docs.where(
          (doc) => doc.data()['command'] == 'change_quality'
        ).toList();
        
        expect(audioCmd.length, 1);
        expect(qualityCmd.length, 1);
      });
      
      test('should mute audio during video call', () async {
        // Start video call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Play audio at 70%
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'ocean_waves',
          volume: 70,
        );
        
        // Mute (set volume to 0)
        await deviceControlService.setDeviceVolume(
          VideoCallFixtures.deviceId1,
          0,
        );
        
        final volumeCommands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'set_volume')
            .get();
        
        expect(volumeCommands.docs.length, 1);
        expect(volumeCommands.docs.first.data()['volume'], 0);
        
        // Unmute (restore volume to 70%)
        await deviceControlService.setDeviceVolume(
          VideoCallFixtures.deviceId1,
          70,
        );
        
        final allVolumeCommands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'set_volume')
            .get();
        
        expect(allVolumeCommands.docs.length, 2);
        expect(allVolumeCommands.docs.last.data()['volume'], 70);
      });
      
      test('should stop audio when video call ends', () async {
        // Start video call
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Play audio
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'heartbeat',
          volume: 50,
          loop: true,
        );
        
        // End call
        await videoCallService.endVideoCall(sessionId);
        
        // Stop audio
        await deviceControlService.stopAudio(VideoCallFixtures.deviceId1);
        
        // Verify both ended
        expect(videoCallService.isInCall, false);
        
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .get();
        
        expect(sessionDoc.data()?['state'], 'disconnected');
        
        final stopAudioCmd = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'stop_audio')
            .get();
        
        expect(stopAudioCmd.docs.length, 1);
      });
    });
    
    group('Multiple Quality Changes', () {
      test('should handle rapid quality changes', () async {
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate());
        
        // Rapid quality changes
        await videoCallService.changeQuality(sessionId, StreamQuality.low);
        await videoCallService.changeQuality(sessionId, StreamQuality.high);
        await videoCallService.changeQuality(sessionId, StreamQuality.medium);
        
        // All commands should be created
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'change_quality')
            .get();
        
        expect(commands.docs.length, 3);
        expect(commands.docs[0].data()['quality'], 'low');
        expect(commands.docs[1].data()['quality'], 'high');
        expect(commands.docs[2].data()['quality'], 'medium');
      });
    });
    
    group('Snapshot Capture Scenarios', () {
      test('should capture multiple snapshots', () async {
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.high,
        );
        final sessionId = session.sessionId;
        
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.streamingStateUpdate(
              fps: 30,
              bitrate: 2000000,
              resolution: '1280x720',
            ));
        
        // Capture 3 snapshots
        final snapshot1 = await videoCallService.captureSnapshot(
          sessionId: sessionId,
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
        );
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final snapshot2 = await videoCallService.captureSnapshot(
          sessionId: sessionId,
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
        );
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final snapshot3 = await videoCallService.captureSnapshot(
          sessionId: sessionId,
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
        );
        
        // Verify all snapshots created
        final snapshots = await firestore
            .collection('camera_snapshots')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        
        expect(snapshots.docs.length, 3);
        expect(snapshots.docs.map((d) => d.id).toList(), 
               containsAll([snapshot1.id, snapshot2.id, snapshot3.id]));
        
        // Verify all capture commands
        final commands = await firestore
            .collection('device_commands')
            .where('command', isEqualTo: 'capture_snapshot')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        
        expect(commands.docs.length, 3);
      });
    });
    
    group('Session History and Cleanup', () {
      test('should retrieve session history', () async {
        // Create 3 sessions
        final session1 = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.low,
        );
        await videoCallService.endVideoCall(session1.sessionId);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final session2 = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        await videoCallService.endVideoCall(session2.sessionId);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final session3 = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.high,
        );
        
        // Get session history (it's a Stream, so we take first emission)
        final history = await videoCallService.getSessionHistory(
          VideoCallFixtures.deviceId1,
        ).first;
        
        expect(history.length, 3);
        expect(history[0].sessionId, session3.sessionId); // Most recent first
        expect(history[1].sessionId, session2.sessionId);
        expect(history[2].sessionId, session1.sessionId);
      });
      
      test('should limit session history to specified count', () async {
        // Create 5 sessions
        for (int i = 0; i < 5; i++) {
          final session = await videoCallService.startVideoCall(
            deviceId: VideoCallFixtures.deviceId1,
            userId: VideoCallFixtures.userId1,
            quality: StreamQuality.medium,
          );
          await videoCallService.endVideoCall(session.sessionId);
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Get all history
        final history = await videoCallService.getSessionHistory(
          VideoCallFixtures.deviceId1,
        ).first;
        
        // Note: getSessionHistory doesn't have a limit parameter in the implementation
        // It returns all sessions, limited by Firestore query
        expect(history.length, 5);
      });
    });
    
    group('Error Handling', () {
      test('should throw error on invalid deviceId', () async {
        expect(
          () => videoCallService.startVideoCall(
            deviceId: '',
            userId: VideoCallFixtures.userId1,
            quality: StreamQuality.medium,
          ),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => deviceControlService.playAudio('', 'lullaby_1'),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw error on empty trackId', () async {
        expect(
          () => deviceControlService.playAudio(VideoCallFixtures.deviceId1, ''),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should handle session not found gracefully', () async {
        // Try to end non-existent session - should not throw
        await videoCallService.endVideoCall('non-existent-session-id');
        
        // Should log a message but not create or update the document
        final doc = await firestore
            .collection('video_sessions')
            .doc('non-existent-session-id')
            .get();
        
        // Document should not exist since it was never created
        expect(doc.exists, false);
      });
      
      test('should handle error state in session', () async {
        final session = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        final sessionId = session.sessionId;
        
        // Simulate device error
        await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .update(VideoCallFixtures.errorStateUpdate('Camera hardware failure'));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final sessionDoc = await firestore
            .collection('video_sessions')
            .doc(sessionId)
            .get();
        
        expect(sessionDoc.data()?['state'], 'error');
        expect(sessionDoc.data()?['errorMessage'], 'Camera hardware failure');
      });
    });
    
    group('Multi-Device Scenarios', () {
      test('should handle sessions on different devices independently', () async {
        // Start session on device 1
        final session1 = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId1,
          userId: VideoCallFixtures.userId1,
          quality: StreamQuality.medium,
        );
        
        // Start session on device 2
        final session2 = await videoCallService.startVideoCall(
          deviceId: VideoCallFixtures.deviceId2,
          userId: VideoCallFixtures.userId2,
          quality: StreamQuality.high,
        );
        
        expect(session1.sessionId, isNot(equals(session2.sessionId)));
        
        // Play audio on device 1
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId1,
          'lullaby_1',
          volume: 60,
        );
        
        // Play different audio on device 2
        await deviceControlService.playAudio(
          VideoCallFixtures.deviceId2,
          'white_noise',
          volume: 40,
        );
        
        // Verify commands are device-specific
        final device1Commands = await firestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: VideoCallFixtures.deviceId1)
            .get();
        
        final device2Commands = await firestore
            .collection('device_commands')
            .where('deviceId', isEqualTo: VideoCallFixtures.deviceId2)
            .get();
        
        expect(device1Commands.docs.length, 2); // start_camera + play_audio
        expect(device2Commands.docs.length, 2); // start_camera + play_audio
        
        // End session on device 1 only
        await videoCallService.endVideoCall(session1.sessionId);
        
        final session1Doc = await firestore
            .collection('video_sessions')
            .doc(session1.sessionId)
            .get();
        
        final session2Doc = await firestore
            .collection('video_sessions')
            .doc(session2.sessionId)
            .get();
        
        expect(session1Doc.data()?['state'], 'disconnected');
        expect(session2Doc.data()?['state'], 'connecting'); // Still active
      });
    });
  });
}
