/// Real web implementation using dart:html and dart:js interop.
library;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class WebRTCInterop {
  js.JsObject? _jsHandler;
  html.VideoElement? _localVideoElement;
  html.VideoElement? _remoteVideoElement;

  dynamic get remoteVideoElement => _remoteVideoElement;

  /// Initialize JS handler and register callbacks.
  /// Returns true if handler found.
  bool initialize({
    required Future<void> Function(Map<String, dynamic>) onIceCandidate,
    required void Function(dynamic) onTrack,
    required void Function(String) onConnectionStateChange,
  }) {
    try {
      _jsHandler = js.context['webrtcHandler'] as js.JsObject?;
      if (_jsHandler == null) {
        debugPrint('[WebRTC Interop] ❌ window.webrtcHandler not found');
        return false;
      }

      _jsHandler!['onIceCandidateCallback'] = js.allowInterop(
        (candidate) => onIceCandidate({
          'candidate': candidate['candidate'],
          'sdpMid': candidate['sdpMid'],
          'sdpMLineIndex': candidate['sdpMLineIndex'],
        }),
      );

      _jsHandler!['onTrackCallback'] = js.allowInterop(onTrack);

      _jsHandler!['onConnectionStateChangeCallback'] =
          js.allowInterop(onConnectionStateChange);

      debugPrint('[WebRTC Interop] ✅ JS handler + callbacks ready');
      return true;
    } catch (e) {
      debugPrint('[WebRTC Interop] ❌ Init error: $e');
      return false;
    }
  }

  void initializeVideoElements() {
    _localVideoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    _remoteVideoElement = html.VideoElement()
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
  }

  Future<bool> createPeerConnection() async {
    try {
      final iceServers = js.JsArray.from([
        js.JsObject.jsify({'urls': 'stun:stun.l.google.com:19302'}),
        js.JsObject.jsify({'urls': 'stun:stun1.l.google.com:19302'}),
      ]);
      final result = _jsHandler!.callMethod('createPeerConnection', [iceServers]);

      // JS returns a Promise — convert to Future
      if (result is js.JsObject) {
        final completer = Completer<bool>();
        result.callMethod('then', [
          js.allowInterop((v) => completer.complete(v == true)),
          js.allowInterop((e) => completer.complete(false)),
        ]);
        return completer.future;
      }
      return result == true;
    } catch (e) {
      debugPrint('[WebRTC Interop] createPeerConnection error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> createOffer() async {
    try {
      final result = _jsHandler!.callMethod('createOffer', []);

      if (result is js.JsObject) {
        final completer = Completer<Map<String, dynamic>?>();
        result.callMethod('then', [
          js.allowInterop((obj) {
            if (obj == null) {
              completer.complete(null);
            } else {
              completer.complete({
                'type': obj['type'],
                'sdp': obj['sdp'],
              });
            }
          }),
          js.allowInterop((e) {
            debugPrint('[WebRTC Interop] createOffer rejected: $e');
            completer.complete(null);
          }),
        ]);
        return completer.future;
      }
      return null;
    } catch (e) {
      debugPrint('[WebRTC Interop] createOffer error: $e');
      return null;
    }
  }

  Future<bool> setRemoteDescription(Map<String, dynamic> description) async {
    try {
      final jsDesc = js.JsObject.jsify(description);
      final result = _jsHandler!.callMethod('setRemoteDescription', [jsDesc]);

      if (result is js.JsObject) {
        final completer = Completer<bool>();
        result.callMethod('then', [
          js.allowInterop((_) => completer.complete(true)),
          js.allowInterop((e) {
            debugPrint('[WebRTC Interop] setRemoteDescription rejected: $e');
            completer.complete(false);
          }),
        ]);
        return completer.future;
      }
      return false;
    } catch (e) {
      debugPrint('[WebRTC Interop] setRemoteDescription error: $e');
      return false;
    }
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      final jsCandidate = js.JsObject.jsify(candidate);
      final result = _jsHandler!.callMethod('addIceCandidate', [jsCandidate]);

      if (result is js.JsObject) {
        final completer = Completer<void>();
        result.callMethod('then', [
          js.allowInterop((_) => completer.complete()),
          js.allowInterop((e) {
            debugPrint('[WebRTC Interop] addIceCandidate rejected: $e');
            completer.complete();
          }),
        ]);
        return completer.future;
      }
    } catch (e) {
      debugPrint('[WebRTC Interop] addIceCandidate error: $e');
    }
  }

  void attachRemoteStream(dynamic stream) {
    if (_remoteVideoElement != null && stream != null) {
      try {
        // stream is a JsObject (native MediaStream) — can't cast to dart:html MediaStream.
        // Wrap the video element as a JsObject to set srcObject directly via JS interop.
        final jsElement = js.JsObject.fromBrowserObject(_remoteVideoElement!);
        jsElement['srcObject'] = stream;
        debugPrint('[WebRTC Interop] ✅ Remote stream → video element (via JS)');
      } catch (e) {
        debugPrint('[WebRTC Interop] ❌ Failed to attach remote stream: $e');
      }
    }
  }

  void close() {
    try {
      _jsHandler?.callMethod('close', []);
    } catch (_) {}
  }

  void disposeVideoElements() {
    _localVideoElement?.remove();
    _remoteVideoElement?.remove();
    _localVideoElement = null;
    _remoteVideoElement = null;
  }
}
