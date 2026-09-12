import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// MQTT Service for real-time device communication
/// Handles connection, subscription, and messaging with ESP32 devices
class MqttService extends ChangeNotifier {
  // MQTT Configuration — must match ESP32 broker IP
  static const String _brokerAddress = 'broker.hivemq.com';
  static const int _brokerPort = 1883;
  // Unique per instance to prevent session collision when multiple users/devices connect
  final String _clientId =
      'baby_track_${DateTime.now().millisecondsSinceEpoch}';
  static const Duration _connectionTimeout = Duration(seconds: 30);

  // Topics
  static const String statusTopic = 'cradle/device001/status';
  static const String cmdTopic = 'cradle/device001/cmd';
  static const String configTopic = 'cradle/device001/config';

  // State management
  late MqttServerClient _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _updatesSubscription;

  // Callbacks for message reception
  final Map<String, StreamController<String>> _topicControllers = {};

  MqttService() {
    _initializeClient();
  }

  /// Initialize MQTT client
  void _initializeClient() {
    try {
      _client = MqttServerClient(_brokerAddress, _clientId);
      _client.port = _brokerPort;
      _client.logging(on: true);
      _client.onConnected = _onConnected;
      _client.onDisconnected = _onDisconnected;
      _client.keepAlivePeriod = 60;
      _client.autoReconnect = true;
      _client.onAutoReconnect = () => debugPrint('[MQTT] Auto-reconnecting...');
      _client.onAutoReconnected = () async {
        debugPrint('[MQTT] Auto-reconnected');
        _isConnected = true;
        _isConnecting = false;
        notifyListeners();
        // Re-subscribe after reconnect (clean session doesn't persist server-side).
        await _subscribeToTopics();
      };

      debugPrint('[MQTT] Client initialized with broker: $_brokerAddress');
    } catch (e) {
      debugPrint('[MQTT] Error initializing client: $e');
      rethrow;
    }
  }

  /// Get connection status
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  /// Connect to MQTT broker
  Future<bool> connect() async {
    if (_isConnected || _isConnecting) {
      debugPrint('[MQTT] Already connected or connecting');
      return _isConnected;
    }

    _isConnecting = true;
    notifyListeners();

    try {
      debugPrint(
          '[MQTT] Attempting connection to $_brokerAddress:$_brokerPort');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client.connectionMessage = connMessage;

      final connStatus = await _client
          .connect()
          .timeout(_connectionTimeout, onTimeout: () => null);

      if (connStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _isConnecting = false;
        debugPrint('[MQTT] Successfully connected to broker');
        notifyListeners();

        await _subscribeToTopics();
        return true;
      } else {
        throw Exception('Connection failed: ${connStatus?.state}');
      }
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint('[MQTT] Connection error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to device topics
  Future<void> _subscribeToTopics() async {
    try {
      // Cancel any previous updates listener before adding a new one,
      // otherwise every reconnect stacks an extra duplicate listener.
      await _updatesSubscription?.cancel();
      _updatesSubscription = null;

      // Wildcard subscriptions catch any device ID.
      // DeviceMqttService.onMessage() extracts the deviceId from the topic.
      _client.subscribe('cradle/+/status', MqttQos.atMostOnce);
      _client.subscribe('cradle/+/response', MqttQos.atMostOnce);
      _client.subscribe('cradle/+/vitals', MqttQos.atMostOnce);
      _client.subscribe('cradle/+/alert', MqttQos.atLeastOnce);
      debugPrint('[MQTT] Subscribed to cradle/+/status, response, vitals, alert');

      _updatesSubscription =
          _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final message in c) {
          _handleMessage(message);
        }
      });
    } catch (e) {
      debugPrint('[MQTT] Error subscribing to topics: $e');
      rethrow;
    }
  }

  /// Handle incoming MQTT messages
  void _handleMessage(MqttReceivedMessage<MqttMessage> message) {
    final receivedTopic = message.topic;
    final msgBytes = message.payload as MqttPublishMessage;

    // Extract message payload
    final payload = String.fromCharCodes(msgBytes.payload.message);

    debugPrint('[MQTT] Received on $receivedTopic: $payload');

    // Route message to topic-specific controller
    if (_topicControllers.containsKey(receivedTopic)) {
      _topicControllers[receivedTopic]!.add(payload);
    }

    // Hook for subclasses to intercept all messages
    onMessage(receivedTopic, payload);

    notifyListeners();
  }

  /// Override in subclasses to intercept all incoming messages.
  void onMessage(String topic, String payload) {}

  /// Called when connected
  void _onConnected() {
    debugPrint('[MQTT] Connection callback triggered');
  }

  /// Called when disconnected
  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    debugPrint('[MQTT] Disconnected from broker');
    notifyListeners();
  }

  /// Publish message to topic.
  /// Set [retain] to true to store the message on the broker for late subscribers.
  /// Publish with [retain]=true and empty [message] to clear a retained message.
  Future<bool> publish(String topic, String message,
      {bool retain = false}) async {
    if (!_isConnected) {
      debugPrint('[MQTT] Not connected, cannot publish to $topic');
      return false;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      _client.publishMessage(
        topic,
        MqttQos.atMostOnce,
        builder.payload!,
        retain: retain,
      );

      debugPrint('[MQTT] Published to $topic: $message');
      return true;
    } catch (e) {
      debugPrint('[MQTT] Error publishing to $topic: $e');
      return false;
    }
  }

  /// Publish command to device
  Future<bool> publishCommand(String command,
      [Map<String, dynamic>? params]) async {
    try {
      final payload = {
        'cmd': command,
        if (params != null) ...params,
      };

      // Simple JSON-like string (can upgrade to json package)
      final jsonString = _mapToJson(payload);
      return await publish(cmdTopic, jsonString);
    } catch (e) {
      debugPrint('[MQTT] Error publishing command: $e');
      return false;
    }
  }

  /// Publish status
  Future<bool> publishStatus(String status) async {
    return await publish(statusTopic, '{"status":"$status"}');
  }

  /// Subscribe to specific topic stream
  Stream<String> subscribeToTopic(String topic) {
    if (!_topicControllers.containsKey(topic)) {
      _topicControllers[topic] = StreamController<String>.broadcast();
    }
    return _topicControllers[topic]!.stream;
  }

  /// Simple map to JSON string converter
  String _mapToJson(Map<String, dynamic> map) {
    final pairs = map.entries.map((e) {
      if (e.value is String) {
        return '"${e.key}":"${e.value}"';
      } else {
        return '"${e.key}":${e.value}';
      }
    }).join(',');
    return '{$pairs}';
  }

  /// Disconnect from broker
  Future<void> disconnect() async {
    if (!_isConnected && !_isConnecting) {
      return;
    }

    try {
      _client.disconnect();
      _isConnected = false;
      _isConnecting = false;
      debugPrint('[MQTT] Disconnected from broker');
    } catch (e) {
      debugPrint('[MQTT] Error disconnecting: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Reconnect to broker
  Future<bool> reconnect() async {
    debugPrint('[MQTT] Reconnecting...');
    await disconnect();
    await Future.delayed(const Duration(seconds: 2));
    return await connect();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _updatesSubscription?.cancel();
    await _connectionStateSubscription?.cancel();
    await _messageSubscription?.cancel();
    for (final controller in _topicControllers.values) {
      await controller.close();
    }
    super.dispose();
  }
}
