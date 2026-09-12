import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../models/mqtt_device_model.dart';
import '../../providers/mqtt_provider.dart';
import '../../providers/auth_provider.dart';

/// Discovered device from MQTT scan
class _DiscoveredMqttDevice {
  final String deviceId;
  final String deviceName;
  final String status;
  final DateTime firstSeen;
  Map<String, dynamic> rawData;

  _DiscoveredMqttDevice({
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.firstSeen,
    required this.rawData,
  });
}

/// Device discovery screen — connects directly to MQTT broker and listens
/// for device announcements on the wildcard topic `cradle/+/status`.
class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  static const _brokerIp = '192.168.1.51';
  static const _brokerPort = 1883;
  static const _discoveryTopic = 'cradle/+/status';
  static const _scanDuration = Duration(seconds: 10);

  MqttServerClient? _client;
  bool _scanning = false;
  bool _connected = false;
  String _statusMsg = 'Tap Scan to discover nearby devices';
  final List<_DiscoveredMqttDevice> _discovered = [];
  Timer? _scanTimer;
  StreamSubscription? _msgSubscription;

  @override
  void dispose() {
    _scanTimer?.cancel();
    _msgSubscription?.cancel();
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _connected = false;
      _discovered.clear();
      _statusMsg = 'Connecting to MQTT broker...';
    });

    try {
      _client?.disconnect();
      _client = MqttServerClient(_brokerIp, 'flutter_discovery_${DateTime.now().millisecondsSinceEpoch}');
      _client!.port = _brokerPort;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 20;
      _client!.connectTimeoutPeriod = 5000;

      final connMsg = MqttConnectMessage()
          .withClientIdentifier('flutter_discovery_${DateTime.now().millisecondsSinceEpoch}')
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _client!.connectionMessage = connMsg;

      await _client!.connect();

      if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
        throw Exception('Connection failed: ${_client!.connectionStatus?.state}');
      }

      setState(() {
        _connected = true;
        _statusMsg = 'Scanning for devices on network...';
      });

      // Subscribe to wildcard status topic
      _client!.subscribe(_discoveryTopic, MqttQos.atMostOnce);

      // Listen for messages
      _msgSubscription?.cancel();
      _msgSubscription = _client!.updates!.listen(_handleMessage);

      // Stop scanning after duration
      _scanTimer?.cancel();
      _scanTimer = Timer(_scanDuration, _stopScan);
    } catch (e) {
      setState(() {
        _scanning = false;
        _connected = false;
        _statusMsg = 'Failed to connect: $e\n\nEnsure MQTT broker is running at $_brokerIp:$_brokerPort and you are on the same network.';
      });
    }
  }

  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final pub = msg.payload as MqttPublishMessage;
      final payload = String.fromCharCodes(pub.payload.message);

      // Extract deviceId from topic: cradle/<deviceId>/status
      final parts = topic.split('/');
      if (parts.length < 3) continue;
      final deviceId = parts[1];

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        data = {'raw': payload};
      }

      final deviceName = data['device'] as String? ?? deviceId;
      final status = data['status'] as String? ?? 'unknown';

      setState(() {
        final existing = _discovered.indexWhere((d) => d.deviceId == deviceId);
        if (existing >= 0) {
          _discovered[existing].rawData = data;
        } else {
          _discovered.add(_DiscoveredMqttDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            status: status,
            firstSeen: DateTime.now(),
            rawData: data,
          ));
        }
        _statusMsg = 'Found ${_discovered.length} device(s). Scan ends in a moment...';
      });
    }
  }

  void _stopScan() {
    _msgSubscription?.cancel();
    _client?.disconnect();
    setState(() {
      _scanning = false;
      _connected = false;
      _statusMsg = _discovered.isEmpty
          ? 'No devices found. Ensure ESP32 is powered on and connected to WiFi.'
          : 'Scan complete. Found ${_discovered.length} device(s).';
    });
  }

  Future<void> _addDevice(_DiscoveredMqttDevice device) async {
    final authProvider = context.read<AuthProvider>();
    final mqttProvider = context.read<DeviceMqttProvider>();

    final familyId = authProvider.firestoreUser?.familyIds.firstOrNull ?? '';
    if (familyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family found. Please complete onboarding.')),
      );
      return;
    }

    final mqttDevice = MqttDeviceModel(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      familyId: familyId,
      status: DeviceConnectionStatus.online,
    );

    await mqttProvider.addDevice(mqttDevice);
    await mqttProvider.initialize();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.deviceName} added successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Devices'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            color: _connected ? Colors.green.shade50 : Colors.grey.shade100,
            child: Row(
              children: [
                if (_scanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _connected ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: _connected ? Colors.green : Colors.grey,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMsg,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: _connected ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: _discovered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _scanning ? 'Listening for devices...' : 'No devices discovered yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: DesignTokens.fontSizeMd,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Broker: $_brokerIp:$_brokerPort',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: DesignTokens.fontSizeXs,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(DesignTokens.spaceMd),
                    itemCount: _discovered.length,
                    itemBuilder: (context, index) {
                      final device = _discovered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.memory, color: Colors.white),
                          ),
                          title: Text(
                            device.deviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${device.deviceId}'),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: device.status == 'online'
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(device.status),
                                ],
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _addDevice(device),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add'),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),

          // Scan button
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceLg),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: DesignTokens.fontSizeMd,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
