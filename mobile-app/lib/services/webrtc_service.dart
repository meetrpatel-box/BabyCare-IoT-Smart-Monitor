import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// WebRTC service for real-time audio/video communication
///
/// Architecture: Flutter App <--WebRTC--> Cloud Relay <--HTTP/WebSocket--> ESP32
///
/// This service handles the WebRTC peer connection between the Flutter app
/// and the cloud relay server. The relay server transcodes between WebRTC
/// and the simpler protocols used by ESP32 (MJPEG + WebSocket).
class WebRTCService extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  // WebRTC peer connection
  RTCPeerConnection? _peerConnection;

  // Media streams
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Renderers for video display
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  // Session management
  String? _currentSessionId;
  StreamSubscription? _signalingSubscription;

  // Connection state
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;

  // ICE configuration (STUN/TURN servers)
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    // Don't use max-bundle - it requires BUNDLE group in SDP which we don't have
    'bundlePolicy': 'balanced',
    'rtcpMuxPolicy': 'require',
    'iceCandidatePoolSize': 0, // Let browser handle candidate gathering timing
  };

  // Media constraints
  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '15',
      },
      'optional': [],
    }
  };

  WebRTCService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Getters
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  RTCPeerConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// Initialize video renderers
  Future<void> initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
  }

  /// Start WebRTC session
  ///
  /// This creates a peer connection and starts the signaling process
  /// with the cloud relay server via Firestore.
  Future<void> startSession({
    required String sessionId,
    required String deviceId,
    bool isOffer = true,
  }) async {
    debugPrint('[WebRTC] Starting session: $sessionId');
    _currentSessionId = sessionId;

    try {
      // Create peer connection
      _peerConnection = await createPeerConnection(_iceServers);

      // Set up event handlers
      _setupPeerConnectionListeners();

      // Get user media (camera + mic)
      if (isOffer && !kIsWeb) {
        // Only get local media if we're the offerer and not on web
        // On web, we'll receive media from the relay server
        _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);

        // Add tracks to peer connection
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });

        // Set local video
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
        }
      }

      // Start signaling
      if (isOffer) {
        await _createOffer(sessionId, deviceId);
      }

      // Listen for remote signaling data
      _listenForSignaling(sessionId);

      notifyListeners();
    } catch (e) {
      debugPrint('[WebRTC] Error starting session: $e');
      rethrow;
    }
  }

  /// Create WebRTC offer
  Future<void> _createOffer(String sessionId, String deviceId) async {
    try {
      // Create offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      debugPrint('[WebRTC] 📝 Local description set (offer)');
      debugPrint('[WebRTC] 🔍 Checking ICE gathering state...');

      // Log peer connection state for debugging
      final signalingState = await _peerConnection!.getSignalingState();
      final iceGatheringState = await _peerConnection!.getIceGatheringState();
      final iceConnectionState = await _peerConnection!.getIceConnectionState();

      debugPrint('[WebRTC] Signaling state: $signalingState');
      debugPrint('[WebRTC] ICE gathering state: $iceGatheringState');
      debugPrint('[WebRTC] ICE connection state: $iceConnectionState');

      // Send offer to Firestore (signaling server)
      await _firestore
          .collection('video_sessions')
          .doc(sessionId)
          .update({
        'webrtc': {
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
          'offerTimestamp': FieldValue.serverTimestamp(),
        },
        'relayServerRequired': true, // Signal that relay server should connect
        'deviceId': deviceId,
      });

      debugPrint('[WebRTC] Offer created and sent to Firestore');
    } catch (e) {
      debugPrint('[WebRTC] Error creating offer: $e');
      rethrow;
    }
  }

  /// Listen for signaling data from Firestore
  void _listenForSignaling(String sessionId) {
    debugPrint('[WebRTC] 📡 Starting to listen for signaling data...');

    _signalingSubscription = _firestore
        .collection('video_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) async {
      debugPrint('[WebRTC] 📡 Received signaling update');

      if (!snapshot.exists) {
        debugPrint('[WebRTC] ⚠️ Snapshot does not exist');
        return;
      }

      final data = snapshot.data();
      if (data == null) {
        debugPrint('[WebRTC] ⚠️ Data is null');
        return;
      }

      if (data['webrtc'] == null) {
        debugPrint('[WebRTC] ⚠️ No webrtc field in data');
        return;
      }

      final webrtc = data['webrtc'] as Map<String, dynamic>;
      debugPrint('[WebRTC] 📡 WebRTC data keys: ${webrtc.keys.toList()}');

      // Handle answer
      if (webrtc['answer'] != null && _peerConnection != null) {
        debugPrint('[WebRTC] 🎯 Answer found in Firestore!');

        final answer = webrtc['answer'] as Map<String, dynamic>;
        final remoteDesc = RTCSessionDescription(
          answer['sdp'] as String,
          answer['type'] as String,
        );

        if (_peerConnection!.getRemoteDescription() == null) {
          debugPrint('[WebRTC] 📝 Setting remote description (answer)...');
          await _peerConnection!.setRemoteDescription(remoteDesc);
          debugPrint('[WebRTC] ✅ Remote description set (answer)');
        } else {
          debugPrint('[WebRTC] ℹ️ Remote description already set');
        }
      } else {
        if (webrtc['answer'] == null) {
          debugPrint('[WebRTC] ⏳ Waiting for answer from simulator...');
        }
        if (_peerConnection == null) {
          debugPrint('[WebRTC] ⚠️ Peer connection is null!');
        }
      }

      // Handle ICE candidates
      if (webrtc['iceCandidates'] != null) {
        final candidates = webrtc['iceCandidates'] as List<dynamic>;
        debugPrint('[WebRTC] 🧊 Found ${candidates.length} ICE candidates');

        for (var candidateData in candidates) {
          if (candidateData is Map<String, dynamic>) {
            try {
              final candidate = RTCIceCandidate(
                candidateData['candidate'] as String,
                candidateData['sdpMid'] as String,
                candidateData['sdpMLineIndex'] as int,
              );
              await _peerConnection!.addCandidate(candidate);
              debugPrint('[WebRTC] ✅ Added ICE candidate');
            } catch (e) {
              debugPrint('[WebRTC] ❌ Error adding ICE candidate: $e');
            }
          }
        }
      } else {
        debugPrint('[WebRTC] 🧊 No ICE candidates yet');
      }
    });
  }

  /// Set up peer connection event listeners
  void _setupPeerConnectionListeners() {
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      debugPrint('[WebRTC] 🧊 New ICE candidate generated!');
      debugPrint('[WebRTC]   candidate: ${candidate.candidate}');
      debugPrint('[WebRTC]   sdpMid: ${candidate.sdpMid}');

      // Send ICE candidate to Firestore
      if (_currentSessionId != null) {
        await _firestore
            .collection('video_sessions')
            .doc(_currentSessionId)
            .update({
          'webrtc.localIceCandidates': FieldValue.arrayUnion([
            {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }
          ]),
        });
        debugPrint('[WebRTC] ✅ ICE candidate sent to Firestore');
      }
    };

    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('[WebRTC] 🔍 ICE gathering state: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] 🔗 ICE connection state: $state');
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] ⭐ Connection state changed: $state');
      _connectionState = state;

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[WebRTC] ✅ WebRTC CONNECTED!');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('[WebRTC] ❌ WebRTC FAILED!');
      }

      notifyListeners();
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] ⭐ New track received: ${event.track.kind}');
      debugPrint('[WebRTC] Track enabled: ${event.track.enabled}');
      debugPrint('[WebRTC] Track muted: ${event.track.muted}');
      debugPrint('[WebRTC] Streams count: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        debugPrint('[WebRTC] ✅ Remote stream assigned!');
        debugPrint('[WebRTC] Remote stream ID: ${_remoteStream!.id}');
        debugPrint('[WebRTC] Video tracks: ${_remoteStream!.getVideoTracks().length}');
        debugPrint('[WebRTC] Audio tracks: ${_remoteStream!.getAudioTracks().length}');

        // Set remote video
        if (_remoteRenderer != null) {
          _remoteRenderer!.srcObject = _remoteStream;
          debugPrint('[WebRTC] ✅ Remote stream set to renderer!');
        } else {
          debugPrint('[WebRTC] ⚠️ Remote renderer is null!');
        }

        notifyListeners();
      } else {
        debugPrint('[WebRTC] ⚠️ No streams in track event!');
      }
    };
  }

  /// Toggle microphone
  Future<void> toggleMicrophone(bool enabled) async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    for (var track in audioTracks) {
      track.enabled = enabled;
    }

    debugPrint('[WebRTC] Microphone ${enabled ? "enabled" : "muted"}');

    // Update Firestore
    if (_currentSessionId != null) {
      await _firestore
          .collection('video_sessions')
          .doc(_currentSessionId)
          .update({
        'signalingData.micEnabled': enabled,
      });
    }
  }

  /// Toggle speaker (mute remote audio)
  Future<void> toggleSpeaker(bool enabled) async {
    if (_remoteStream == null) return;

    final audioTracks = _remoteStream!.getAudioTracks();
    for (var track in audioTracks) {
      track.enabled = enabled;
    }

    debugPrint('[WebRTC] Speaker ${enabled ? "enabled" : "muted"}');

    // Update Firestore
    if (_currentSessionId != null) {
      await _firestore
          .collection('video_sessions')
          .doc(_currentSessionId)
          .update({
        'signalingData.speakerEnabled': enabled,
      });
    }
  }

  /// End WebRTC session
  Future<void> endSession() async {
    debugPrint('[WebRTC] Ending session');

    // Cancel signaling subscription
    await _signalingSubscription?.cancel();
    _signalingSubscription = null;

    // Stop local stream
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;

    // Close peer connection
    await _peerConnection?.close();
    _peerConnection = null;

    // Clear remote stream
    _remoteStream = null;

    _currentSessionId = null;
    _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;

    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    endSession();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }
}
