import 'package:flutter/foundation.dart';
import '../services/device_mqtt_service.dart';
import '../models/mqtt_device_model.dart';

class DeviceMqttProvider extends ChangeNotifier {
  final DeviceMqttService _mqttService;
  final Map<String, bool> _commandInProgress = {};

  DeviceMqttProvider({DeviceMqttService? mqttService})
      : _mqttService = mqttService ?? DeviceMqttService() {
    // Forward service change notifications to UI consumers.
    // Without this, Consumer<DeviceMqttProvider> never rebuilds when a
    // device is discovered or its status changes.
    _mqttService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() => notifyListeners();

  bool get isConnected => _mqttService.isConnected;
  List<MqttDeviceModel> get devices => _mqttService.getAllDevices();

  bool isCommandInProgress(String deviceId) =>
      _commandInProgress[deviceId] ?? false;

  Future<bool> initialize() async {
    final success = await _mqttService.connect();
    notifyListeners();
    return success;
  }

  Future<void> addDevice(MqttDeviceModel device) async {
    await _mqttService.addDevice(device);
    notifyListeners();
  }

  Future<void> removeDevice(String deviceId) async {
    await _mqttService.removeDevice(deviceId);
    notifyListeners();
  }

  Future<bool> _executeCommand(String deviceId, String cmd,
      [Map<String, dynamic>? params]) async {
    _commandInProgress[deviceId] = true;
    notifyListeners();

    try {
      final result = await _mqttService.sendDeviceCommand(deviceId, cmd, params);
      return result;
    } finally {
      _commandInProgress[deviceId] = false;
      notifyListeners();
    }
  }

  Future<bool> pingDevice(String deviceId) =>
      _executeCommand(deviceId, 'ping');

  Future<bool> rebootDevice(String deviceId) =>
      _executeCommand(deviceId, 'reboot');

  Future<bool> disconnectDevice(String deviceId) async {
    // Send the disconnect command (device will clear credentials and reboot).
    final result = await _executeCommand(deviceId, 'disconnect');

    // Remove from local tracking immediately so the card disappears from the
    // dashboard whether or not the command was delivered.
    // Also publish retain=true with empty payload to clear the broker's stored
    // "online" message — otherwise the device re-appears on next app launch.
    await _mqttService.publish(
      'cradle/$deviceId/status',
      '',
      retain: true,
    );
    await _mqttService.removeDevice(deviceId);
    notifyListeners();
    return result;
  }

  Future<bool> reconnectDevice(String deviceId) =>
      _executeCommand(deviceId, 'reconnect');

  Future<bool> startRecording(String deviceId) =>
      _executeCommand(deviceId, 'start_recording');

  Future<bool> stopRecording(String deviceId) =>
      _executeCommand(deviceId, 'stop_recording');

  Future<bool> startCryMonitor(String deviceId) =>
      _executeCommand(deviceId, 'start_cry_monitor');

  Future<bool> stopCryMonitor(String deviceId) =>
      _executeCommand(deviceId, 'stop_cry_monitor');

  Future<bool> sendCommand(String deviceId, String cmd,
      [Map<String, dynamic>? params]) =>
      _executeCommand(deviceId, cmd, params);

  /// Real-time stream of IoT alerts (e.g., cry detection)
  Stream<Map<String, dynamic>> get cryAlertStream => _mqttService.alertStream;

  /// Latest alert received from any device
  Map<String, dynamic>? get latestAlert => _mqttService.latestAlert;

  bool isDeviceOnline(String deviceId) => _mqttService.isDeviceOnline(deviceId);

  /// Latest vitals received from the board, or null if none received yet.
  MqttVitals? vitalsForDevice(String deviceId) =>
      _mqttService.getDevice(deviceId)?.latestVitals;

  /// First online device with vitals, for auto-detection.
  MqttVitals? get firstOnlineVitals {
    for (final d in _mqttService.getAllDevices()) {
      if (d.isOnline && d.latestVitals != null) return d.latestVitals;
    }
    return null;
  }

  /// Generic publish — used by LiveSpeakService to reuse this MQTT connection.
  Future<bool> publish(String topic, String payload) =>
      _mqttService.publish(topic, payload);

  /// Publish a raw audio chunk to the device speaker topic.
  /// [base64Data] is base64-encoded 16-bit PCM (16kHz, mono).
  Future<bool> publishSpeakChunk(
      String deviceId, String base64Data, int seq, int bytes) async {
    final payload =
        '{"seq":$seq,"bytes":$bytes,"data":"$base64Data"}';
    return _mqttService.publish('cradle/$deviceId/speak', payload);
  }

  @override
  Future<void> dispose() async {
    _mqttService.removeListener(_onServiceChanged);
    await _mqttService.dispose();
    super.dispose();
  }
}

