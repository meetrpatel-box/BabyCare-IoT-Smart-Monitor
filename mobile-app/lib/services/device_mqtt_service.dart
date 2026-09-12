import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mqtt_service.dart';
import '../models/mqtt_device_model.dart';

/// Extended MQTT Service with device management
/// Handles multiple IoT devices with topic-based routing
class DeviceMqttService extends MqttService {
  // Device tracking
  final Map<String, MqttDeviceModel> _devices = {};
  final Map<String, StreamSubscription> _deviceSubscriptions = {};

  // Alert stream controller
  final StreamController<Map<String, dynamic>> _alertController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Map<String, dynamic>? _latestAlert;
  Map<String, dynamic>? get latestAlert => _latestAlert;

  // Staleness detection: mark device offline when no heartbeat for >30 s
  Timer? _stalenessTimer;
  static const _stalenessThreshold = Duration(seconds: 30);
  static const _stalenessCheckInterval = Duration(seconds: 15);

  DeviceMqttService() {
    _startStalenessTimer();
  }

  void _startStalenessTimer() {
    _stalenessTimer?.cancel();
    _stalenessTimer = Timer.periodic(_stalenessCheckInterval, (_) {
      bool changed = false;
      for (final id in _devices.keys) {
        final device = _devices[id]!;
        if (device.status == DeviceConnectionStatus.online &&
            DateTime.now().difference(device.lastSeenAt) > _stalenessThreshold) {
          _devices[id] = device.copyWith(status: DeviceConnectionStatus.offline);
          debugPrint('[DeviceMqtt] Stale heartbeat — marking $id offline');
          changed = true;
        }
      }
      if (changed) notifyListeners();
    });
  }

  /// Add device for MQTT communication
  Future<void> addDevice(MqttDeviceModel device) async {
    debugPrint('[DeviceMqtt] Adding device: ${device.deviceName}');

    _devices[device.deviceId] = device;

    // Subscribe to device status topic
    if (isConnected) {
      _subscribeToDevice(device);
    }
  }

  /// Remove device from tracking
  Future<void> removeDevice(String deviceId) async {
    debugPrint('[DeviceMqtt] Removing device: $deviceId');

    // Cancel subscription
    await _deviceSubscriptions[deviceId]?.cancel();
    _deviceSubscriptions.remove(deviceId);
    _devices.remove(deviceId);
  }

  /// Get tracked device
  MqttDeviceModel? getDevice(String deviceId) => _devices[deviceId];

  /// Get all tracked devices
  List<MqttDeviceModel> getAllDevices() => _devices.values.toList();

  /// Subscribe to a device's status updates
  void _subscribeToDevice(MqttDeviceModel device) {
    debugPrint(
        '[DeviceMqtt] Subscribing to device ${device.deviceId} topic: ${device.statusTopic}');

    // Cancel existing subscription
    _deviceSubscriptions[device.deviceId]?.cancel();

    // Subscribe to device status topic
    _deviceSubscriptions[device.deviceId] =
        subscribeToTopic(device.statusTopic).listen((message) {
      debugPrint(
          '[DeviceMqtt] Device ${device.deviceId} status: $message');

      // Parse and update device status
      _updateDeviceStatus(device.deviceId, message);
    });
  }

  /// Update device status from message
  void _updateDeviceStatus(String deviceId, String message) {
    if (!_devices.containsKey(deviceId)) return;

    final device = _devices[deviceId]!;

    // Parse status from message
    final status = message.contains('online')
        ? DeviceConnectionStatus.online
        : DeviceConnectionStatus.offline;

    // Update device
    _devices[deviceId] = device.copyWith(
      status: status,
      lastSeenAt: DateTime.now(),
      lastMessage: {'raw': message, 'timestamp': DateTime.now()},
    );

    notifyListeners();
  }

  /// Auto-discover devices and route all incoming MQTT messages.
  /// Called for every MQTT message — no manual addDevice() needed.
  @override
  void onMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length != 3) return;

    final deviceId = parts[1];
    final subtopic = parts[2];

    if (subtopic == 'status') {
      _handleStatusMessage(deviceId, payload);
    } else if (subtopic == 'vitals') {
      _handleVitalsMessage(deviceId, payload);
    } else if (subtopic == 'alert') {
      _handleAlertMessage(deviceId, payload);
    }
  }

  void _handleStatusMessage(String deviceId, String payload) {
    // Reject foreign devices: payload must contain "deviceId" matching topic.
    final idMatch = RegExp(r'"deviceId"\s*:\s*"([^"]+)"').firstMatch(payload);
    if (idMatch == null || idMatch.group(1) != deviceId) return;

    final ipMatch = RegExp(r'"ip"\s*:\s*"([^"]+)"').firstMatch(payload);
    final ip = ipMatch?.group(1);

    // Auto-register on first heartbeat
    if (!_devices.containsKey(deviceId)) {
      final nameMatch = RegExp(r'"device"\s*:\s*"([^"]+)"').firstMatch(payload);
      final deviceName = nameMatch?.group(1) ?? deviceId;
      _devices[deviceId] = MqttDeviceModel(
        deviceId: deviceId,
        deviceName: deviceName,
        familyId: '',
        status: DeviceConnectionStatus.online,
        lastSeenAt: DateTime.now(),
        deviceIp: ip,
      );
      debugPrint('[DeviceMqtt] Auto-discovered: $deviceId ip=$ip');
      notifyListeners();
    } else if (ip != null && ip != _devices[deviceId]?.deviceIp) {
      // Update IP if it changed (e.g. DHCP renewal)
      _devices[deviceId] = _devices[deviceId]!.copyWith(deviceIp: ip);
    }

    _updateDeviceStatus(deviceId, payload);
  }

  void _handleVitalsMessage(String deviceId, String payload) {
    if (!_devices.containsKey(deviceId)) return; // must see status first

    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;

      // Guard: deviceId in payload must match topic
      final payloadId = json['deviceId'] as String?;
      if (payloadId != null && payloadId != deviceId) return;

      final vitals = MqttVitals.fromJson(json);
      _devices[deviceId] = _devices[deviceId]!.copyWith(
        latestVitals: vitals,
        lastSeenAt: DateTime.now(),
      );
      debugPrint('[DeviceMqtt] Vitals for $deviceId: '
          'temp=${vitals.bodyTemperature} hr=${vitals.heartRate}');
      notifyListeners();
    } catch (e) {
      debugPrint('[DeviceMqtt] Vitals parse error: $e');
    }
  }

  void _handleAlertMessage(String deviceId, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      data['deviceId'] = deviceId;
      data['receivedAt'] = DateTime.now().toIso8601String();
      _latestAlert = data;
      _alertController.add(data);
      debugPrint('🚨 [DeviceMqtt] Alert received from $deviceId: $data');
      notifyListeners();
    } catch (e) {
      debugPrint('[DeviceMqtt] Alert parse error: $e');
    }
  }

  /// Resubscribe to all device topics after reconnect
  @override
  Future<bool> connect() async {
    final success = await super.connect();

    if (success) {
      for (final device in _devices.values) {
        _subscribeToDevice(device);
      }
    }

    return success;
  }

  /// Send command to device with error handling
  Future<bool> sendDeviceCommand(
    String deviceId,
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    final device = _devices[deviceId];
    if (device == null) {
      debugPrint('[DeviceMqtt] ❌ Device not found: $deviceId');
      return false;
    }

    if (!device.isOnline) {
      debugPrint('[DeviceMqtt] ⚠️  Device offline: $deviceId - Command "$command" queued');
    }

    final cmd = MqttCommand(command: command, params: params);
    debugPrint('[DeviceMqtt] 📤 Sending $command to $deviceId via topic: ${device.cmdTopic}');

    try {
      final result = await publish(device.cmdTopic, cmd.toJsonString());
      if (result) {
        debugPrint('[DeviceMqtt] ✓ Command "$command" sent to $deviceId');
      } else {
        debugPrint('[DeviceMqtt] ✗ Failed to send command "$command" to $deviceId');
      }
      return result;
    } catch (e) {
      debugPrint('[DeviceMqtt] ✗ Exception sending command to $deviceId: $e');
      return false;
    }
  }

  /// Get device status by ID
  DeviceConnectionStatus getDeviceStatus(String deviceId) {
    return _devices[deviceId]?.status ?? DeviceConnectionStatus.unknown;
  }

  /// Check if device is online
  bool isDeviceOnline(String deviceId) =>
      _devices[deviceId]?.isOnline ?? false;

  /// Get time since device was last seen
  Duration? getDeviceTimeSinceLastSeen(String deviceId) {
    return _devices[deviceId]?.timeSinceLastSeen;
  }

  @override
  Future<void> dispose() async {
    _stalenessTimer?.cancel();
    _stalenessTimer = null;

    for (final subscription in _deviceSubscriptions.values) {
      await subscription.cancel();
    }
    _deviceSubscriptions.clear();
    _devices.clear();
    await _alertController.close();

    await super.dispose();
  }
}
