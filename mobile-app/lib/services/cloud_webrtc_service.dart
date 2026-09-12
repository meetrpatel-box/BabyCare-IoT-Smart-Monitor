import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../config/relay_config.dart';
import 'package:audio_session/audio_session.dart';

/// Service managing WebRTC streaming from the babytrack cloud relay via go2rtc.
class CloudWebRTCService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  String? _currentStreamId;
  MediaStreamTrack? _remoteAudioTrack;
  bool _isAudioEnabled = true; // Enabled by default for continuous baby monitoring

  bool get isAudioEnabled => _isAudioEnabled;

  void setAudioEnabled(bool enable) {
    _isAudioEnabled = enable;
    if (_remoteAudioTrack != null) {
      try {
        _remoteAudioTrack!.enabled = enable;
        debugPrint('[CloudWebRTC] Remote audio track enabled: $enable');
      } catch (e) {
        debugPrint('[CloudWebRTC] Error setting audio track enabled: $e');
      }
    }
    notifyListeners();
  }

  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  String? get currentStreamId => _currentStreamId;

  /// Initialize video renderer
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await remoteRenderer.initialize();
      _isInitialized = true;
      notifyListeners();
      debugPrint('[CloudWebRTC] Renderer initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize video renderer: $e';
      notifyListeners();
      debugPrint('[CloudWebRTC] Renderer init error: $e');
    }
  }

  /// Connect to the camera stream on the cloud relay
  Future<void> connect(String streamId) async {
    if (_isConnecting) return;
    if (_isConnected && _currentStreamId == streamId) return;

    await disconnect();

    _isConnecting = true;
    _error = null;
    _currentStreamId = streamId;
    notifyListeners();

    try {
      if (!_isInitialized) {
        await initialize();
      }

      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
        await session.setActive(true);
      } catch (e) {
        debugPrint('[CloudWebRTC] AudioSession configure error: $e');
      }

      // Configuration with Google STUN servers
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add receive-only transceivers for Video and Audio
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // Handle incoming remote media tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[CloudWebRTC] onTrack event: ${event.track.kind}');
        if (event.track.kind == 'audio') {
          _remoteAudioTrack = event.track;
          try {
            _remoteAudioTrack!.enabled = _isAudioEnabled;
            Helper.setSpeakerphoneOn(true);
            debugPrint('[CloudWebRTC] Audio track attached, initial enabled: $_isAudioEnabled');
          } catch (e) {
            debugPrint('[CloudWebRTC] Failed to configure audio track: $e');
          }
        }
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          _isConnected = true;
          _isConnecting = false;
          _error = null;
          notifyListeners();
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[CloudWebRTC] PeerConnectionState changed: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isConnected = true;
          _isConnecting = false;
          _error = null;
          notifyListeners();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                   state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _isConnected = false;
          _isConnecting = false;
          _error = 'Connection lost ($state)';
          notifyListeners();
        }
      };

      // Create WebRTC Offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      debugPrint('[CloudWebRTC] Negotiating WebRTC with ${RelayConfig.webrtcUrl(streamId)}');

      // Post Offer SDP to go2rtc API
      final uri = Uri.parse(RelayConfig.webrtcUrl(streamId));
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/sdp'},
        body: offer.sdp,
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final answer = RTCSessionDescription(response.body, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        debugPrint('[CloudWebRTC] Remote SDP Answer set successfully!');
      } else {
        throw Exception('Cloud relay rejected offer: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CloudWebRTC] Connection error: $e');
      _error = e.toString();
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect stream
  Future<void> disconnect() async {
    try {
      remoteRenderer.srcObject = null;
      _remoteAudioTrack = null;
      _isAudioEnabled = true;
      await _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      debugPrint('[CloudWebRTC] Disconnect error: $e');
    } finally {
      _isConnected = false;
      _isConnecting = false;
      _currentStreamId = null;
      notifyListeners();
    }
  }

  /// Push-to-talk talk-back: send raw PCM chunk to ESP32 speaker via relay
  Future<bool> sendSpeakPcm(String streamId, Uint8List pcm) async {
    try {
      final uri = Uri.parse(RelayConfig.speakUrl(streamId));
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/octet-stream'},
        body: pcm,
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CloudWebRTC] Speak error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    disconnect();
    remoteRenderer.dispose();
    super.dispose();
  }
}
