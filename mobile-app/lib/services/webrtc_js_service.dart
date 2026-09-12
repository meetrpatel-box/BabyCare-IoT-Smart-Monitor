import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Conditional imports: real implementation on web, stub elsewhere
import 'webrtc_js_interop_stub.dart'
    if (dart.library.html) 'webrtc_js_interop_web.dart' as webrtc_interop;

/// JavaScript Interop WebRTC Service for Web Platform
///
/// On web: uses native browser WebRTC via dart:js interop
/// On other platforms: no-op stubs (not supported)
class WebRTCJsService extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  // Session management
  String? _currentSessionId;
  StreamSubscription? _signalingSubscription;

  // Connection state
  String _connectionState = 'new';
  bool _hasRemoteStream = false;
  bool _isInitialized = false;
  bool _disposed = false;

  // Signaling guards — prevent duplicate setRemoteDescription / addIceCandidate
  bool _answerApplied = false;
  int _appliedRemoteCandidateCount = 0;

  // Platform interop delegate
  final webrtc_interop.WebRTCInterop _interop;

  WebRTCJsService({FirebaseFirestore? firestore, webrtc_interop.WebRTCInterop? interop})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _interop = interop ?? webrtc_interop.WebRTCInterop() {
    _initializeJsHandler();
  }

  // Getters
  String get connectionState => _connectionState;
  bool get isConnected => _connectionState == 'connected';
  bool get hasRemoteStream => _hasRemoteStream;
  bool get isInitialized => _isInitialized;

  dynamic get remoteVideoElement => _interop.remoteVideoElement;

  /// Initialize JavaScript handler
  void _initializeJsHandler() {
    if (!kIsWeb) {
      debugPrint('[WebRTC JS] Not on web platform - JS interop disabled');
      return;
    }

    _isInitialized = _interop.initialize(
      onIceCandidate: _handleIceCandidate,
      onTrack: _handleTrack,
      onConnectionStateChange: _handleConnectionStateChange,
    );
  }

  /// Initialize video renderers
  Future<void> initializeRenderers() async {
    if (!kIsWeb) return;
    _interop.initializeVideoElements();
    debugPrint('[WebRTC JS] Video elements created');
  }

  /// Start WebRTC session as caller (creates offer)
  Future<void> startSession({
    required String sessionId,
    required String deviceId,
    bool isOffer = true,
  }) async {
    if (!_isInitialized) {
      throw Exception('JavaScript handler not initialized. Is webrtc_handler.js loaded?');
    }

    debugPrint('[WebRTC JS] Starting session: $sessionId (isOffer=$isOffer)');
    _currentSessionId = sessionId;

    try {
      // Create peer connection
      final connected = await _interop.createPeerConnection();
      if (!connected) throw Exception('Failed to create peer connection');
      debugPrint('[WebRTC JS] ✅ Peer connection created');

      // Start signaling
      if (isOffer) {
        await _createAndSendOffer(sessionId, deviceId);
      }

      // Listen for remote signaling data
      _listenForSignaling(sessionId);

      notifyListeners();
    } catch (e) {
      debugPrint('[WebRTC JS] ❌ Error starting session: $e');
      rethrow;
    }
  }

  /// Create WebRTC offer and push to Firestore
  Future<void> _createAndSendOffer(String sessionId, String deviceId) async {
    final offer = await _interop.createOffer();
    if (offer == null) throw Exception('Failed to create offer');
    debugPrint('[WebRTC JS] ✅ Offer created (type=${offer['type']})');

    await _firestore.collection('video_sessions').doc(sessionId).update({
      'webrtc': {
        'offer': {'type': offer['type'], 'sdp': offer['sdp']},
        'offerTimestamp': FieldValue.serverTimestamp(),
      },
      'relayServerRequired': true,
      'deviceId': deviceId,
    });
    debugPrint('[WebRTC JS] ✅ Offer sent to Firestore');
  }

  /// Listen for signaling data from Firestore and apply to peer connection
  void _listenForSignaling(String sessionId) {
    debugPrint('[WebRTC JS] 📡 Starting signaling listener...');

    _signalingSubscription = _firestore
        .collection('video_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;
      if (data['webrtc'] == null) return;

      final webrtc = data['webrtc'] as Map<String, dynamic>;

      // Handle answer from remote (only apply once — re-application causes WebRTC state errors)
      // Set flag BEFORE await to prevent race: multiple snapshots can pass the check
      // while the first setRemoteDescription is still in flight on the event loop.
      if (!_answerApplied && webrtc['answer'] != null) {
        _answerApplied = true; // Optimistic lock — set before await
        final answer = webrtc['answer'] as Map<String, dynamic>;
        final ok = await _interop.setRemoteDescription(answer);
        if (ok) {
          debugPrint('[WebRTC JS] ✅ Remote description (answer) applied');
        } else {
          _answerApplied = false; // Reset only on failure so we can retry
          debugPrint('[WebRTC JS] ❌ setRemoteDescription failed, will retry');
        }
      }

      // Handle remote ICE candidates (only apply new ones — duplicates cause DOMException)
      // Increment counter BEFORE await to prevent the same race condition.
      if (webrtc['iceCandidates'] != null) {
        final candidates = webrtc['iceCandidates'] as List<dynamic>;
        if (candidates.length > _appliedRemoteCandidateCount) {
          final newCandidates = candidates
              .skip(_appliedRemoteCandidateCount)
              .whereType<Map<String, dynamic>>()
              .toList();
          _appliedRemoteCandidateCount += newCandidates.length; // Claim all before awaiting
          for (final candidate in newCandidates) {
            await _interop.addIceCandidate(candidate);
            debugPrint('[WebRTC JS] ✅ Remote ICE candidate applied ($_appliedRemoteCandidateCount total)');
          }
        }
      }
    }, onError: (e) => debugPrint('[WebRTC JS] Signaling error: $e'));
  }

  /// ICE candidate callback from JS — push to Firestore
  Future<void> _handleIceCandidate(Map<String, dynamic> candidate) async {
    debugPrint('[WebRTC JS] 🧊 ICE candidate generated!');
    if (_currentSessionId == null) return;

    try {
      await _firestore
          .collection('video_sessions')
          .doc(_currentSessionId)
          .update({
        'webrtc.localIceCandidates': FieldValue.arrayUnion([candidate]),
      });
      debugPrint('[WebRTC JS] ✅ ICE candidate → Firestore');
    } catch (e) {
      debugPrint('[WebRTC JS] ❌ ICE send error: $e');
    }
  }

  /// Track callback from JS — wire remote stream to video element
  void _handleTrack(dynamic stream) {
    debugPrint('[WebRTC JS] ⭐ Remote track received!');
    _interop.attachRemoteStream(stream);
    _hasRemoteStream = true;
    // Use scheduleMicrotask so notifyListeners() is never called synchronously
    // from a JS event (dart:js allowInterop callback). Calling it synchronously
    // from JS can interrupt Flutter's widget build/unmount cycle and trigger
    // the "_dependents.isEmpty" assertion in InheritedElement.unmount().
    scheduleMicrotask(() { if (!_disposed) notifyListeners(); });
  }

  /// Connection state callback from JS
  void _handleConnectionStateChange(String state) {
    debugPrint('[WebRTC JS] 🔌 Connection state → $state');
    _connectionState = state;
    // Same: defer to Dart microtask queue to avoid interrupting Flutter frame.
    scheduleMicrotask(() { if (!_disposed) notifyListeners(); });
  }

  /// End the current WebRTC session
  Future<void> endSession() async {
    if (_disposed) return;
    debugPrint('[WebRTC JS] Ending session');
    await _signalingSubscription?.cancel();
    _signalingSubscription = null;

    _interop.close();

    _currentSessionId = null;
    _connectionState = 'new';
    _hasRemoteStream = false;
    _answerApplied = false;
    _appliedRemoteCandidateCount = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Synchronously cancel subscription and close — no await needed
    _signalingSubscription?.cancel();
    _signalingSubscription = null;
    _interop.close();
    _interop.disposeVideoElements();
    super.dispose();
  }
}
