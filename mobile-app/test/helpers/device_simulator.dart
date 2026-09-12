import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Simulated IoT baby monitor device for testing
/// Simulates vital signs, connectivity, and device commands
class DeviceSimulator {
  final String deviceId;
  final String babyId;
  final FirebaseFirestore _firestore;

  Timer? _heartbeatTimer;
  Timer? _vitalSignsTimer;
  bool _isOnline = false;
  int _signalStrength = -50; // Start with good signal
  final Random _random = Random();

  DeviceSimulator({
    required this.deviceId,
    required this.babyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============== DEVICE CONTROL ==============

  /// Start device simulation
  Future<void> start() async {
    if (_isOnline) {
      debugPrint('[DeviceSimulator] Device already online');
      return;
    }

    _isOnline = true;
    debugPrint('[DeviceSimulator] Starting device $deviceId');

    // Update device status
    await _updateDeviceStatus('online');

    // Start heartbeat (every 10 seconds)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendHeartbeat(),
    );

    // Start vital signs (every 15 seconds)
    _vitalSignsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendVitalSigns(),
    );

    debugPrint('[DeviceSimulator] Device started successfully');
  }

  /// Stop device simulation
  Future<void> stop() async {
    if (!_isOnline) return;

    _isOnline = false;
    _heartbeatTimer?.cancel();
    _vitalSignsTimer?.cancel();

    await _updateDeviceStatus('offline');
    debugPrint('[DeviceSimulator] Device stopped');
  }

  /// Simulate device going offline temporarily
  Future<void> simulateDisconnect({Duration duration = const Duration(minutes: 2)}) async {
    debugPrint('[DeviceSimulator] Simulating disconnect for ${duration.inSeconds}s');

    await stop();
    await Future.delayed(duration);
    await start();

    debugPrint('[DeviceSimulator] Reconnected after disconnect');
  }

  /// Simulate weak WiFi signal
  void simulateWeakSignal() {
    _signalStrength = -85; // Weak signal
    debugPrint('[DeviceSimulator] Signal degraded to $_signalStrength dBm');
  }

  /// Simulate good WiFi signal
  void simulateGoodSignal() {
    _signalStrength = -45; // Excellent signal
    debugPrint('[DeviceSimulator] Signal improved to $_signalStrength dBm');
  }

  // ============== DEVICE HEARTBEAT ==============

  Future<void> _sendHeartbeat() async {
    if (!_isOnline) return;

    try {
      // Add small variation to signal strength
      final signalVariation = _random.nextInt(10) - 5;
      final currentSignal = _signalStrength + signalVariation;

      await _firestore.collection('devices').doc(deviceId).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'status': 'online',
        'wifiInfo': {
          'ssid': 'HomeWiFi-Simulator',
          'signalStrength': currentSignal,
          'isConnected': true,
        },
      });

      debugPrint('[DeviceSimulator] Heartbeat sent (Signal: $currentSignal dBm)');
    } catch (e) {
      debugPrint('[DeviceSimulator] Error sending heartbeat: $e');
    }
  }

  // ============== VITAL SIGNS SIMULATION ==============

  Future<void> _sendVitalSigns() async {
    if (!_isOnline) return;

    try {
      final vitals = _generateRealisticVitals();

      // Update baby's latestVitals (embedded field)
      await _firestore.collection('babies').doc(babyId).update({
        'latestVitals': vitals,
      });

      // Also add to vitalLogs subcollection (historical)
      await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('vitalLogs')
          .add(vitals);

      debugPrint('[DeviceSimulator] Vital signs sent: HR=${vitals['heartRate']}, '
          'Temp=${vitals['temperature']}°C');
    } catch (e) {
      debugPrint('[DeviceSimulator] Error sending vitals: $e');
    }
  }

  /// Generate realistic baby vital signs
  Map<String, dynamic> _generateRealisticVitals() {
    // Baby vital sign ranges (newborn to 1 year)
    final heartRate = 100 + _random.nextInt(40); // 100-140 bpm
    final temperature = 36.5 + (_random.nextDouble() * 1.0); // 36.5-37.5°C
    final humidity = 40 + _random.nextInt(20); // 40-60%
    final oxygenLevel = 95 + _random.nextInt(5); // 95-100%

    return {
      'heartRate': heartRate,
      'temperature': double.parse(temperature.toStringAsFixed(1)),
      'humidity': humidity,
      'oxygenLevel': oxygenLevel,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceId': deviceId,
      'babyId': babyId,
    };
  }

  // ============== SPECIAL EVENTS ==============

  /// Simulate abnormal heart rate (for alert testing)
  Future<void> simulateAbnormalHeartRate({bool tooHigh = true}) async {
    if (!_isOnline) return;

    final abnormalHR = tooHigh ? 180 : 70; // Too high or too low

    final vitals = {
      'heartRate': abnormalHR,
      'temperature': 36.8,
      'humidity': 45,
      'oxygenLevel': 98,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceId': deviceId,
      'babyId': babyId,
      'alert': true,
      'alertType': tooHigh ? 'heartRateTooHigh' : 'heartRateTooLow',
    };

    await _firestore.collection('babies').doc(babyId).update({
      'latestVitals': vitals,
    });

    // Create alert
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('alerts')
        .add({
      'type': tooHigh ? 'heartRateTooHigh' : 'heartRateTooLow',
      'priority': 'critical',
      'value': abnormalHR,
      'timestamp': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });

    debugPrint('[DeviceSimulator] Abnormal heart rate alert: $abnormalHR bpm');
  }

  /// Simulate cry detection
  Future<void> simulateCryDetection({int durationSeconds = 30}) async {
    if (!_isOnline) return;

    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .add({
      'startTime': FieldValue.serverTimestamp(),
      'durationSeconds': durationSeconds,
      'intensity': _random.nextInt(5) + 1, // 1-5
      'deviceId': deviceId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('[DeviceSimulator] Cry detected: ${durationSeconds}s');
  }

  /// Simulate wetness detection
  Future<void> simulateWetnessDetection() async {
    if (!_isOnline) return;

    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('wetnessEvents')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
      'deviceId': deviceId,
      'wetLevel': _random.nextInt(3) + 1, // 1-3
    });

    debugPrint('[DeviceSimulator] Wetness detected');
  }

  /// Start sleep session
  Future<String> startSleepSession() async {
    if (!_isOnline) throw Exception('Device offline');

    final sessionRef = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .add({
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'deviceId': deviceId,
      'babyId': babyId,
    });

    debugPrint('[DeviceSimulator] Sleep session started: ${sessionRef.id}');
    return sessionRef.id;
  }

  /// End sleep session
  Future<void> endSleepSession(String sessionId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .update({
      'endTime': FieldValue.serverTimestamp(),
    });

    debugPrint('[DeviceSimulator] Sleep session ended: $sessionId');
  }

  // ============== COMMAND HANDLING ==============

  /// Listen for device commands and respond
  StreamSubscription<QuerySnapshot> listenForCommands() {
    debugPrint('[DeviceSimulator] Listening for commands');

    return _firestore
        .collection('deviceCommands')
        .where('deviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _handleCommand(doc.id, doc.data());
      }
    });
  }

  Future<void> _handleCommand(String commandId, Map<String, dynamic> command) async {
    final commandType = command['commandType'] as String;
    debugPrint('[DeviceSimulator] Received command: $commandType');

    // Simulate command execution delay
    await Future.delayed(const Duration(seconds: 1));

    switch (commandType) {
      case 'playAudio':
        debugPrint('[DeviceSimulator] Playing audio: ${command['payload']?['trackId']}');
        break;
      case 'stopAudio':
        debugPrint('[DeviceSimulator] Stopping audio');
        break;
      case 'startVideoCall':
        debugPrint('[DeviceSimulator] Starting video call');
        break;
      case 'reboot':
        debugPrint('[DeviceSimulator] Rebooting device');
        await simulateDisconnect(duration: const Duration(seconds: 30));
        break;
      default:
        debugPrint('[DeviceSimulator] Unknown command: $commandType');
    }

    // Mark command as completed
    await _firestore.collection('deviceCommands').doc(commandId).update({
      'status': 'completed',
      'executedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============== HELPERS ==============

  Future<void> _updateDeviceStatus(String status) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'status': status,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clean up resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _vitalSignsTimer?.cancel();
  }
}

// ============== TEST HELPER FACTORY ==============

/// Factory for creating test devices
class DeviceSimulatorFactory {
  final FirebaseFirestore _firestore;

  DeviceSimulatorFactory({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a fully configured test device
  Future<DeviceSimulator> createTestDevice({
    required String babyId,
    required String familyId,
    required String ownerId,
    String? deviceName,
  }) async {
    // Create device document
    final deviceRef = await _firestore.collection('devices').add({
      'name': deviceName ?? 'Test Device',
      'familyId': familyId,
      'assignedBabyId': babyId,
      'status': 'offline',
      'ownerId': ownerId,
      'authorizedUsers': [ownerId],
      'capabilities': {
        'hasCamera': true,
        'hasMicrophone': true,
        'hasSpeaker': true,
        'hasVitalSensors': true,
        'supportsVideo': true,
        'supportsAudio': true,
      },
      'firmwareVersion': '1.0.0-simulator',
      'batteryLevel': 100,
      'wifiInfo': {
        'ssid': 'TestWiFi',
        'signalStrength': -50,
        'isConnected': false,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'registeredAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[DeviceSimulatorFactory] Created test device: ${deviceRef.id}');

    return DeviceSimulator(
      deviceId: deviceRef.id,
      babyId: babyId,
      firestore: _firestore,
    );
  }

  /// Create multiple test devices
  Future<List<DeviceSimulator>> createMultipleDevices({
    required String babyId,
    required String familyId,
    required String ownerId,
    int count = 3,
  }) async {
    final devices = <DeviceSimulator>[];

    for (int i = 0; i < count; i++) {
      final device = await createTestDevice(
        babyId: babyId,
        familyId: familyId,
        ownerId: ownerId,
        deviceName: 'Test Device ${i + 1}',
      );
      devices.add(device);
    }

    return devices;
  }
}
