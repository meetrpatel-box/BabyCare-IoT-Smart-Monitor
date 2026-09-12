/// Stub implementation for non-web platforms.
/// All methods are no-ops or return sensible defaults.
library;

/// Interop delegate — injected into WebRTCJsService.
/// On non-web platforms this stub is used; on web the real implementation.
class WebRTCInterop {
  dynamic remoteVideoElement;

  bool initialize({
    required Future<void> Function(Map<String, dynamic>) onIceCandidate,
    required void Function(dynamic) onTrack,
    required void Function(String) onConnectionStateChange,
  }) {
    // Not supported on non-web platforms
    return false;
  }

  void initializeVideoElements() {}

  Future<bool> createPeerConnection() async => false;

  Future<Map<String, dynamic>?> createOffer() async => null;

  Future<bool> setRemoteDescription(Map<String, dynamic> description) async => false;

  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {}

  void attachRemoteStream(dynamic stream) {}

  void close() {}

  void disposeVideoElements() {}
}
