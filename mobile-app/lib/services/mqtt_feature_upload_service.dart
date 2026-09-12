import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Connection state for the MQTT service.
enum MqttServiceConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Callback for incoming MQTT messages (e.g., device status updates).
typedef MqttMessageCallback = void Function(String topic, Map<String, dynamic> payload);

/// MQTT Feature Upload Service — manages audio feature uploads from device to cloud
/// via an MQTT broker, with Firestore fallback.
///
/// Supports two transport modes:
/// 1. **MQTT broker** (primary): Connects to a broker (AWS IoT Core, HiveMQ, etc.)
///    for low-latency, bidirectional communication with IoT devices.
/// 2. **Firestore** (fallback): Direct Firestore writes when MQTT is unavailable.
///
/// Topic structure:
///   baby-track/{deviceId}/cry/features    — audio features payload
///   baby-track/{deviceId}/cry/raw-audio   — raw audio (if fullAudio consent)
///   baby-track/{deviceId}/status          — device online/offline heartbeat
///   baby-track/{deviceId}/commands        — commands TO device (start/stop recording)
class MqttFeatureUploadService {
  final FirebaseFirestore _firestore;
  MqttServerClient? _client;
  MqttServiceConnectionState _connectionState = MqttServiceConnectionState.disconnected;
  final StreamController<MqttServiceConnectionState> _connectionStateController =
      StreamController<MqttServiceConnectionState>.broadcast();
  final Map<String, List<MqttMessageCallback>> _subscriptions = {};
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  // MQTT broker configuration
  String? _brokerHost;
  int _brokerPort = 8883;
  String? _clientId;
  String? _username;
  String? _password;

  MqttFeatureUploadService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Current connection state.
  MqttServiceConnectionState get connectionState => _connectionState;

  /// Stream of connection state changes.
  Stream<MqttServiceConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Whether MQTT is currently connected.
  bool get isConnected => _connectionState == MqttServiceConnectionState.connected;

  // ============================================================
  // Connection Management
  // ============================================================

  /// Connect to the MQTT broker.
  ///
  /// [brokerHost]: Hostname of the MQTT broker (e.g., 'broker.hivemq.com')
  /// [port]: Broker port (default 8883 for TLS, 1883 for plain)
  /// [clientId]: Unique client identifier (typically userId or deviceId)
  /// [username]/[password]: Broker authentication credentials
  Future<bool> connect({
    required String brokerHost,
    int port = 8883,
    required String clientId,
    String? username,
    String? password,
  }) async {
    if (_connectionState == MqttServiceConnectionState.connected) {
      return true;
    }

    _brokerHost = brokerHost;
    _brokerPort = port;
    _clientId = clientId;
    _username = username;
    _password = password;

    return _doConnect();
  }

  Future<bool> _doConnect() async {
    if (_brokerHost == null || _clientId == null) return false;

    _setConnectionState(MqttServiceConnectionState.connecting);

    _client = MqttServerClient(_brokerHost!, _clientId!);
    _client!.port = _brokerPort;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = false; // We handle reconnection ourselves
    _client!.logging(on: false);
    _client!.setProtocolV311();

    // Set up last will for device offline detection
    final willTopic = 'baby-track/$_clientId/status';
    final willMessage = jsonEncode({
      'status': 'offline',
      'timestamp': DateTime.now().toIso8601String(),
    });

    final connectMsg = MqttConnectMessage()
        .withClientIdentifier(_clientId!)
        .withWillTopic(willTopic)
        .withWillMessage(willMessage)
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    // Add credentials if provided
    if (_username != null && _password != null) {
      connectMsg.authenticateAs(_username!, _password!);
    }

    _client!.connectionMessage = connectMsg;

    // Set disconnect callback
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    try {
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _setConnectionState(MqttServiceConnectionState.connected);
        _reconnectAttempts = 0;

        // Listen to incoming messages
        _client!.updates?.listen(_onMessage);

        // Re-subscribe to any previously active subscriptions
        for (final topic in _subscriptions.keys) {
          _client!.subscribe(topic, MqttQos.atLeastOnce);
        }

        // Publish online status
        await _publishStatus('online');

        return true;
      }
    } catch (e) {
      _setConnectionState(MqttServiceConnectionState.error);
    }

    _scheduleReconnect();
    return false;
  }

  /// Disconnect from the MQTT broker.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_client != null) {
      await _publishStatus('offline');
      _client!.disconnect();
      _client = null;
    }

    _setConnectionState(MqttServiceConnectionState.disconnected);
  }

  void _onDisconnected() {
    _setConnectionState(MqttServiceConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    // Subscription confirmed by broker
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setConnectionState(MqttServiceConnectionState.error);
      return;
    }

    _reconnectTimer?.cancel();
    // Exponential backoff: 2s, 4s, 8s, 16s, ... capped at 60s
    final delay = Duration(
      milliseconds: (_baseReconnectDelay.inMilliseconds *
              (1 << _reconnectAttempts))
          .clamp(0, 60000),
    );
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () async {
      await _doConnect();
    });
  }

  void _setConnectionState(MqttServiceConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  // ============================================================
  // Publishing — Feature Uploads
  // ============================================================

  /// Upload audio features via MQTT, falling back to Firestore if disconnected.
  ///
  /// Returns true if published via MQTT, false if fell back to Firestore.
  Future<bool> uploadFeatures({
    required String deviceId,
    required String babyId,
    required String eventId,
    required Map<String, dynamic> features,
    Map<String, dynamic>? sensorContext,
  }) async {
    final payload = {
      'babyId': babyId,
      'eventId': eventId,
      'features': features,
      if (sensorContext != null) 'sensorContext': sensorContext,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Try MQTT first
    if (isConnected) {
      final topic = 'baby-track/$deviceId/cry/features';
      final published = _publish(topic, payload);
      if (published) return true;
    }

    // Fallback to Firestore
    await _uploadViaFirestore(
      babyId: babyId,
      eventId: eventId,
      features: features,
      sensorContext: sensorContext,
    );
    return false;
  }

  /// Upload raw audio clip via MQTT (if fullAudio consent).
  Future<bool> uploadRawAudio({
    required String deviceId,
    required String babyId,
    required String eventId,
    required Uint8List audioData,
    String format = 'wav',
  }) async {
    if (!isConnected) return false;

    final topic = 'baby-track/$deviceId/cry/raw-audio';
    final payload = {
      'babyId': babyId,
      'eventId': eventId,
      'format': format,
      'audioBase64': base64Encode(audioData),
      'timestamp': DateTime.now().toIso8601String(),
    };

    return _publish(topic, payload);
  }

  /// Send a command to a device (e.g., start/stop recording).
  Future<bool> sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, dynamic>? params,
  }) async {
    if (!isConnected) return false;

    final topic = 'baby-track/$deviceId/commands';
    final payload = {
      'command': command,
      if (params != null) 'params': params,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return _publish(topic, payload);
  }

  bool _publish(String topic, Map<String, dynamic> payload) {
    if (_client == null || !isConnected) return false;

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _publishStatus(String status) async {
    if (_client == null || _clientId == null) return;
    final topic = 'baby-track/$_clientId/status';
    final payload = {
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _publish(topic, payload);
  }

  // ============================================================
  // Subscribing — Device Status & Detections
  // ============================================================

  /// Subscribe to a device's cry detection events.
  ///
  /// Callbacks receive parsed JSON payloads from:
  ///   baby-track/{deviceId}/cry/features
  ///   baby-track/{deviceId}/status
  void subscribeToDevice(String deviceId, MqttMessageCallback callback) {
    final featuresTopic = 'baby-track/$deviceId/cry/features';
    final statusTopic = 'baby-track/$deviceId/status';

    _addSubscription(featuresTopic, callback);
    _addSubscription(statusTopic, callback);
  }

  /// Unsubscribe from a device.
  void unsubscribeFromDevice(String deviceId) {
    final featuresTopic = 'baby-track/$deviceId/cry/features';
    final statusTopic = 'baby-track/$deviceId/status';

    _removeSubscription(featuresTopic);
    _removeSubscription(statusTopic);
  }

  void _addSubscription(String topic, MqttMessageCallback callback) {
    _subscriptions.putIfAbsent(topic, () => []);
    _subscriptions[topic]!.add(callback);

    if (isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _removeSubscription(String topic) {
    _subscriptions.remove(topic);
    if (isConnected && _client != null) {
      _client!.unsubscribe(topic);
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final pubMsg = msg.payload as MqttPublishMessage;
      final payloadStr =
          MqttPublishPayload.bytesToStringAsString(pubMsg.payload.message);

      try {
        final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        final callbacks = _subscriptions[topic];
        if (callbacks != null) {
          for (final cb in callbacks) {
            cb(topic, payload);
          }
        }
      } catch (_) {
        // Ignore malformed messages
      }
    }
  }

  // ============================================================
  // Firestore Fallback
  // ============================================================

  /// Upload features inline to the cry event Firestore document.
  Future<void> uploadInlineFeatures({
    required String babyId,
    required String eventId,
    required Map<String, dynamic> features,
  }) async {
    await _uploadViaFirestore(
      babyId: babyId,
      eventId: eventId,
      features: features,
    );
  }

  Future<void> _uploadViaFirestore({
    required String babyId,
    required String eventId,
    required Map<String, dynamic> features,
    Map<String, dynamic>? sensorContext,
  }) async {
    final update = <String, dynamic>{
      'audioFeatures': features,
      'hasAudioFeatures': true,
    };
    if (sensorContext != null) {
      update['sensorContext'] = sensorContext;
    }

    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .doc(eventId)
        .update(update);
  }

  /// Upload features to a Firestore staging queue.
  ///
  /// Used when the device doesn't have direct Firestore access.
  /// A Cloud Function processes the queue and moves data to the event doc.
  Future<String> uploadToQueue({
    required String deviceId,
    required String babyId,
    required String eventId,
    required Map<String, dynamic> features,
    Map<String, dynamic>? sensorContext,
  }) async {
    final doc = await _firestore.collection('featureUploadQueue').add({
      'deviceId': deviceId,
      'babyId': babyId,
      'eventId': eventId,
      'features': features,
      'sensorContext': sensorContext,
      'transportUsed': isConnected ? 'mqtt' : 'firestore',
      'status': 'pending',
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Check upload status of a queued item.
  Future<String> getUploadStatus(String queueId) async {
    final doc =
        await _firestore.collection('featureUploadQueue').doc(queueId).get();
    if (!doc.exists) return 'not_found';
    return doc.data()?['status'] as String? ?? 'unknown';
  }

  // ============================================================
  // Mock Features (for testing)
  // ============================================================

  /// Generate a mock feature payload for testing.
  static Map<String, dynamic> generateMockFeatures({
    double durationSeconds = 5.0,
    int sampleRate = 16000,
    int numFrames = 50,
  }) {
    final mfcc = List.generate(
      numFrames,
      (i) => List.generate(13, (j) => (j * 0.1) + (i * 0.01)),
    );

    final melSpectrogram = List.generate(
      numFrames,
      (i) => List.generate(
          64, (j) => (j / 64.0) * 0.5 + (i / numFrames) * 0.3),
    );

    final rmsEnergy = List.generate(
      numFrames,
      (i) => 0.3 + 0.4 * (i / numFrames),
    );

    final f0 = List.generate(
      numFrames,
      (i) => 300.0 + 100.0 * (i % 10) / 10.0,
    );

    return {
      'mfcc': mfcc,
      'melSpectrogram': melSpectrogram,
      'rmsEnergy': rmsEnergy,
      'zeroCrossingRate':
          List.generate(numFrames, (i) => 0.05 + 0.02 * (i % 5)),
      'spectralCentroid':
          List.generate(numFrames, (i) => 2000.0 + 500.0 * (i % 8) / 8.0),
      'f0': f0,
      'durationSeconds': durationSeconds,
      'sampleRate': sampleRate,
    };
  }

  /// Dispose of resources.
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    disconnect();
    _connectionStateController.close();
  }
}
