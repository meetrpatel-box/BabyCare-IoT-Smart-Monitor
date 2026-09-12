/// Configuration for the BabyTrack cloud relay infrastructure.
class RelayConfig {
  static const String host = 'relay.nxmplis.com';
  static const String baseUrl = 'https://relay.nxmplis.com';
  static const String token = '2af0a9e90c97421aa37972c3c5e28151157dc5360000a1f9fe7efd9875dd96c8';

  /// go2rtc WebRTC signaling endpoint (HTTP POST offer -> response answer)
  static String webrtcUrl(String streamId) =>
      '$baseUrl/api/webrtc?src=$streamId&token=$token';

  /// Push-to-talk PCM speak endpoint (HTTP fallback)
  static String speakUrl(String streamId) =>
      '$baseUrl/speak/$streamId?token=$token';

  /// Push-to-talk WebSocket endpoint for zero-latency live voice streaming
  static String speakWsUrl(String streamId) =>
      'wss://$host/speak/$streamId?token=$token';

  /// Raw microphone stream endpoint
  static String audioUrl(String streamId) =>
      '$baseUrl/audio/$streamId?token=$token';
}
