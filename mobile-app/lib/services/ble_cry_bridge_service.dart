import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/cry_event_model.dart';
import 'cry_alert_service.dart';

/// BLE UUIDs for the BabyTrack Monitor device.
///
/// The device firmware exposes a custom GATT service with characteristics
/// for cry detection, classification, and sensor data.
class BabyTrackBleUuids {
  BabyTrackBleUuids._();

  /// Primary service UUID for BabyTrack cry detection
  static final service = Guid('00001234-0000-1000-8000-00805f9b34fb');

  /// Characteristic: cry detection status (notify)
  /// JSON payload: { type: 'detection'|'classification'|'cry_ended', ... }
  static final cryDetection = Guid('00001235-0000-1000-8000-00805f9b34fb');

  /// Characteristic: sensor context data (read/notify)
  /// JSON payload: { heartRate, bodyTemp, ... }
  static final sensorData = Guid('00001236-0000-1000-8000-00805f9b34fb');

  /// Characteristic: device status (read)
  /// JSON payload: { batteryLevel, firmwareVersion, ... }
  static final deviceStatus = Guid('00001237-0000-1000-8000-00805f9b34fb');
}

/// Connection state for the BLE bridge.
enum BleBridgeConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Bridge between the BLE BabyTrack device and the cry alert pipeline.
///
/// This service:
/// 1. Scans for and connects to BabyTrack Monitor BLE devices
/// 2. Subscribes to cry detection characteristic notifications
/// 3. Parses BLE payloads into structured cry events
/// 4. Forwards data to [CryAlertService] for progressive alerts
/// 5. Falls back to Firestore listener when BLE is unavailable
class BleCryBridgeService {
  final CryAlertService _alertService;
  final FirebaseFirestore _firestore;

  // BLE state
  BluetoothDevice? _connectedDevice;
  BleBridgeConnectionState _connectionState =
      BleBridgeConnectionState.disconnected;
  final StreamController<BleBridgeConnectionState> _connectionStateController =
      StreamController<BleBridgeConnectionState>.broadcast();

  // BLE subscriptions
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSub;
  StreamSubscription<List<int>>? _cryCharSub;
  StreamSubscription<List<int>>? _sensorCharSub;

  // Firestore fallback subscriptions
  final Map<String, StreamSubscription<QuerySnapshot>> _firestoreSubs = {};

  // Configuration
  String? _targetDeviceId;
  String? _babyId;
  static const Duration _scanTimeout = Duration(seconds: 15);

  // Latest sensor readings from BLE characteristic
  CrySensorContext? _latestSensorContext;

  BleCryBridgeService({
    required CryAlertService alertService,
    FirebaseFirestore? firestore,
  })  : _alertService = alertService,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Current BLE connection state.
  BleBridgeConnectionState get connectionState => _connectionState;

  /// Stream of connection state changes.
  Stream<BleBridgeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Whether a BLE device is connected.
  bool get isConnected =>
      _connectionState == BleBridgeConnectionState.connected;

  /// The connected device (null if not connected).
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // ============================================================
  // BLE Scanning & Connection
  // ============================================================

  /// Scan for and connect to a BabyTrack device.
  ///
  /// [deviceId]: Optional specific device ID to connect to.
  ///   If null, connects to the first BabyTrack device found.
  /// [babyId]: The baby associated with this device.
  Future<bool> scanAndConnect({
    String? deviceId,
    required String babyId,
  }) async {
    _targetDeviceId = deviceId;
    _babyId = babyId;

    _setConnectionState(BleBridgeConnectionState.scanning);

    try {
      // Check if Bluetooth is available and on
      if (await FlutterBluePlus.isSupported == false) {
        _setConnectionState(BleBridgeConnectionState.error);
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _setConnectionState(BleBridgeConnectionState.error);
        return false;
      }

      // Start scanning with service filter
      final completer = Completer<bool>();

      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          if (_isTargetDevice(result)) {
            FlutterBluePlus.stopScan();
            _connectToDevice(result.device).then((connected) {
              if (!completer.isCompleted) {
                completer.complete(connected);
              }
            });
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [BabyTrackBleUuids.service],
        timeout: _scanTimeout,
      );

      // If scan times out without finding device
      if (!completer.isCompleted) {
        _setConnectionState(BleBridgeConnectionState.disconnected);
        completer.complete(false);
      }

      return await completer.future;
    } catch (e) {
      _setConnectionState(BleBridgeConnectionState.error);
      return false;
    } finally {
      _scanSub?.cancel();
      _scanSub = null;
    }
  }

  bool _isTargetDevice(ScanResult result) {
    // Match by specific device ID if provided
    if (_targetDeviceId != null) {
      return result.device.remoteId.str == _targetDeviceId;
    }
    // Otherwise match by advertised service UUID
    return result.advertisementData.serviceUuids
        .contains(BabyTrackBleUuids.service);
  }

  Future<bool> _connectToDevice(BluetoothDevice device) async {
    _setConnectionState(BleBridgeConnectionState.connecting);

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      _connectedDevice = device;

      // Listen for disconnection
      _deviceConnectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Discover services and subscribe to characteristics
      await _discoverAndSubscribe(device);

      _setConnectionState(BleBridgeConnectionState.connected);

      // Stop Firestore fallback now that BLE is connected
      if (_targetDeviceId != null) {
        _stopFirestoreFallback(_targetDeviceId!);
      }

      return true;
    } catch (e) {
      _setConnectionState(BleBridgeConnectionState.error);
      return false;
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid != BabyTrackBleUuids.service) continue;

      for (final char in service.characteristics) {
        if (char.uuid == BabyTrackBleUuids.cryDetection) {
          await char.setNotifyValue(true);
          _cryCharSub = char.onValueReceived.listen(_handleCryCharacteristic);
        } else if (char.uuid == BabyTrackBleUuids.sensorData) {
          await char.setNotifyValue(true);
          _sensorCharSub =
              char.onValueReceived.listen(_handleSensorCharacteristic);
        }
      }
    }
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _cryCharSub?.cancel();
    _sensorCharSub?.cancel();
    _deviceConnectionSub?.cancel();
    _setConnectionState(BleBridgeConnectionState.disconnected);

    // Fall back to Firestore listener
    if (_targetDeviceId != null && _babyId != null) {
      startFirestoreFallback(
        deviceId: _targetDeviceId!,
        babyId: _babyId!,
      );
    }
  }

  /// Disconnect from the BLE device.
  Future<void> disconnect() async {
    _cryCharSub?.cancel();
    _sensorCharSub?.cancel();
    _deviceConnectionSub?.cancel();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _setConnectionState(BleBridgeConnectionState.disconnected);
  }

  void _setConnectionState(BleBridgeConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  // ============================================================
  // BLE Characteristic Handlers
  // ============================================================

  void _handleCryCharacteristic(List<int> value) {
    try {
      final json = utf8.decode(value);
      final data = jsonDecode(json) as Map<String, dynamic>;
      _processDetection(data);
    } catch (_) {
      // Malformed BLE payload — ignore
    }
  }

  void _handleSensorCharacteristic(List<int> value) {
    try {
      final json = utf8.decode(value);
      final data = jsonDecode(json) as Map<String, dynamic>;
      _latestSensorContext = CrySensorContext.fromMap(data);
    } catch (_) {
      // Malformed sensor payload — ignore
    }
  }

  Future<void> _processDetection(Map<String, dynamic> data) async {
    final babyId = _babyId;
    if (babyId == null) return;

    final type = data['type'] as String?;
    final deviceId =
        data['deviceId'] as String? ?? _targetDeviceId ?? '';

    switch (type) {
      case 'detection':
        final intensity = (data['intensity'] as num?)?.toDouble() ?? 0.7;
        final sensorContext = data['sensorContext'] != null
            ? CrySensorContext.fromMap(
                data['sensorContext'] as Map<String, dynamic>)
            : _latestSensorContext;

        await _alertService.handleBleDetection(
          babyId: babyId,
          deviceId: deviceId,
          intensity: intensity,
          sensorContext: sensorContext,
        );
        break;

      case 'classification':
        final classification = CryClassification.fromString(
            data['classification'] as String?);
        final confidence =
            (data['confidence'] as num?)?.toDouble() ?? 0.5;

        await _alertService.handleBleClassification(
          babyId: babyId,
          classification: classification,
          confidence: confidence,
        );
        break;

      case 'cry_ended':
        await _alertService.handleCryEnded(babyId: babyId);
        break;

      case 'audio_features_uploaded':
        // Cloud Function handles classification from here
        break;
    }
  }

  // ============================================================
  // Firestore Fallback
  // ============================================================

  /// Start listening via Firestore when BLE is unavailable.
  ///
  /// This is the same Firestore-based approach from the original service.
  /// Used as fallback when BLE connection drops.
  void startFirestoreFallback({
    required String deviceId,
    required String babyId,
  }) {
    if (_firestoreSubs.containsKey(deviceId)) return;

    final sub = _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('cryDetections')
        .where('processed', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        _handleFirestoreDetection(doc, babyId);
      }
    });

    _firestoreSubs[deviceId] = sub;
  }

  void _stopFirestoreFallback(String deviceId) {
    _firestoreSubs[deviceId]?.cancel();
    _firestoreSubs.remove(deviceId);
  }

  /// Start listening for cry detection events from a device (Firestore mode).
  ///
  /// Kept for backward compatibility. Equivalent to [startFirestoreFallback].
  void startListening({
    required String deviceId,
    required String babyId,
  }) {
    startFirestoreFallback(deviceId: deviceId, babyId: babyId);
  }

  /// Stop listening for a specific device.
  void stopListening(String deviceId) {
    _stopFirestoreFallback(deviceId);
  }

  /// Stop all Firestore listeners.
  void stopAll() {
    for (final sub in _firestoreSubs.values) {
      sub.cancel();
    }
    _firestoreSubs.clear();
  }

  Future<void> _handleFirestoreDetection(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String babyId,
  ) async {
    final data = doc.data();
    if (data == null) return;

    // Mark as processed
    await doc.reference.update({'processed': true});

    // Set babyId temporarily for _processDetection
    final prevBabyId = _babyId;
    _babyId = babyId;
    await _processDetection(data);
    _babyId = prevBabyId;
  }

  // ============================================================
  // Simulation (for testing / demo mode)
  // ============================================================

  /// Simulate a BLE detection via Firestore.
  Future<void> simulateDetection({
    required String deviceId,
    required String babyId,
    double intensity = 0.8,
    CrySensorContext? sensorContext,
  }) async {
    await _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('cryDetections')
        .add({
      'type': 'detection',
      'deviceId': deviceId,
      'babyId': babyId,
      'intensity': intensity,
      'sensorContext': sensorContext?.toMap(),
      'processed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Simulate edge classification via Firestore.
  Future<void> simulateClassification({
    required String deviceId,
    required CryClassification classification,
    double confidence = 0.7,
  }) async {
    await _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('cryDetections')
        .add({
      'type': 'classification',
      'deviceId': deviceId,
      'classification': classification.name,
      'confidence': confidence,
      'processed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Simulate cry ended via Firestore.
  Future<void> simulateCryEnded({required String deviceId}) async {
    await _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('cryDetections')
        .add({
      'type': 'cry_ended',
      'deviceId': deviceId,
      'processed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Dispose of all resources.
  void dispose() {
    disconnect();
    stopAll();
    _connectionStateController.close();
  }
}
