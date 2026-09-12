import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// WiFi provisioning service using a custom BLE GATT protocol.
///
/// ESP32 firmware advertises as "BabyCare-XXXX" and exposes service 0xFFF0:
///   0xFFF4  WiFi scan results — JSON array (read)
///   0xFFF1  SSID             — write (string)
///   0xFFF2  Password         — write (string, triggers connect)
///   0xFFF3  Status           — read + notify ("idle"|"connecting"|"connected"|"failed")
class WifiProvisioningService {
  static const String _namePrefix = 'BabyCare';
  // flutter_blue_plus returns 16-bit UUIDs in short form (e.g. "fff0")
  // Use the 4-char short form for comparisons
  static const String _svcUuid    = 'fff0';
  static const String _scanUuid   = 'fff4';
  static const String _ssidUuid   = 'fff1';
  static const String _passUuid   = 'fff2';
  static const String _statusUuid = 'fff3';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _scanChar;
  StreamSubscription? _scanSub;
  bool _demoMode = false;
  bool _isCancelled = false;

  void setDemoMode(bool enabled) {
    _demoMode = enabled;
  }

  /// Signal an in-progress provisionWifi call to abort cleanly.
  /// Called before disconnecting the BLE device so the disconnect handler
  /// doesn't misinterpret the drop as a success.
  void signalCancellation() {
    _isCancelled = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final scan    = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      final loc     = await Permission.locationWhenInUse.request();
      return scan.isGranted && connect.isGranted && loc.isGranted;
    } else if (Platform.isIOS) {
      return (await Permission.bluetooth.request()).isGranted;
    }
    return true;
  }

  Future<BluetoothState> checkBluetoothState() async {
    if (_demoMode || kIsWeb) return BluetoothState.on;
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return BluetoothState.unsupported;
      final state = await FlutterBluePlus.adapterState.first;
      switch (state) {
        case BluetoothAdapterState.on:           return BluetoothState.on;
        case BluetoothAdapterState.off:          return BluetoothState.off;
        case BluetoothAdapterState.unauthorized: return BluetoothState.unauthorized;
        default:                                 return BluetoothState.unknown;
      }
    } catch (_) {
      return BluetoothState.unknown;
    }
  }

  /// Scan for ESP32 devices advertising the "BabyCare-" name.
  Future<List<DiscoveredDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_demoMode) {
      await Future.delayed(const Duration(seconds: 2));
      return [
        DiscoveredDevice(id: 'DEMO_AA11', name: 'BabyCare-AA11', rssi: -45),
        DiscoveredDevice(id: 'DEMO_BB22', name: 'BabyCare-BB22', rssi: -62),
      ];
    }

    final devices   = <DiscoveredDevice>[];
    final seenIds   = <String>{};

    try {
      await _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          if (name.startsWith(_namePrefix) &&
              !seenIds.contains(r.device.remoteId.str)) {
            seenIds.add(r.device.remoteId.str);
            devices.add(DiscoveredDevice(
              id:     r.device.remoteId.str,
              name:   name,
              rssi:   r.rssi,
              device: r.device,
            ));
          }
        }
      });

      // Scan without service UUID filter — more reliable on Android;
      // we filter by "BabyCare-" name prefix in the listener above.
      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (e) {
      throw Exception('BLE scan failed: $e');
    } finally {
      await _scanSub?.cancel();
      _scanSub = null;
    }

    return devices;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Connect to the selected ESP32 device and discover provisioning service.
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_demoMode) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    if (device.device == null) return false;

    try {
      await device.device!.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device.device;

      // Request larger MTU for WiFi scan JSON — non-fatal if unsupported
      try {
        await device.device!.requestMtu(247);
      } catch (_) {}

      // Small delay to let GATT server stabilise after connect
      await Future.delayed(const Duration(milliseconds: 500));

      // Discover GATT services and cache characteristics
      final services = await device.device!.discoverServices();

      BluetoothService? provSvc;
      for (final s in services) {
        if (s.serviceUuid.toString().toLowerCase() == _svcUuid) {
          provSvc = s;
          break;
        }
      }
      if (provSvc == null) {
        final found = services.map((s) => s.serviceUuid.toString()).join(', ');
        throw Exception('Service 0xFFF0 not found. Got: $found');
      }

      for (final c in provSvc.characteristics) {
        final uuid = c.characteristicUuid.toString().toLowerCase();
        if (uuid == _scanUuid)   _scanChar   = c;
        if (uuid == _ssidUuid)   _ssidChar   = c;
        if (uuid == _passUuid)   _passChar   = c;
        if (uuid == _statusUuid) _statusChar = c;
      }

      if (_ssidChar == null || _passChar == null || _statusChar == null) {
        throw Exception('Missing characteristics (ssid=$_ssidChar pass=$_passChar status=$_statusChar)');
      }

      return true;
    } catch (e) {
      await disconnectDevice();
      // Re-throw so DeviceProvider shows the real error in the UI
      rethrow;
    }
  }

  Future<void> disconnectDevice() async {
    if (_demoMode) return;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _ssidChar = null;
    _passChar = null;
    _statusChar = null;
    _scanChar = null;
  }

  /// Read the WiFi scan JSON from the ESP32 and parse into WifiNetwork list.
  Future<List<WifiNetwork>> scanWifiNetworks() async {
    if (_demoMode) {
      await Future.delayed(const Duration(seconds: 2));
      return [
        WifiNetwork(ssid: 'Home WiFi',      signalStrength: -40, isSecure: true),
        WifiNetwork(ssid: 'Office Network', signalStrength: -55, isSecure: true),
        WifiNetwork(ssid: 'Guest',          signalStrength: -70, isSecure: false),
      ];
    }

    if (_scanChar == null) return [];

    try {
      final raw     = await _scanChar!.read();
      final jsonStr = String.fromCharCodes(raw).trim();
      if (jsonStr.isEmpty || jsonStr == '[]') return [];

      final List<dynamic> list = jsonDecode(jsonStr) as List;
      return list.map((n) {
        // Support both compact ("s","r","a") and legacy ("ssid","rssi","auth") keys
        final ssid = (n['s'] ?? n['ssid'])  as String? ?? '';
        final rssi = (n['r'] ?? n['rssi'])  as int?    ?? -80;
        final auth = (n['a'] ?? n['auth'])  as int?    ?? 0;
        return WifiNetwork(ssid: ssid, signalStrength: rssi, isSecure: auth > 0);
      }).where((n) => n.ssid.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Send WiFi credentials to ESP32 and wait for connection result.
  ///
  /// Three parallel mechanisms to detect success/failure:
  ///   1. GATT notification from status characteristic (fast path)
  ///   2. Polling status characteristic every 2 s (fallback — bypasses notification issues)
  ///   3. BLE disconnect handler (firmware explicitly disconnects after success)
  Future<ProvisioningResult> provisionWifi({
    required String ssid,
    required String password,
    required String claimToken,
  }) async {
    if (_demoMode) {
      await Future.delayed(const Duration(seconds: 3));
      return ProvisioningResult(
        success: true,
        message: 'Device connected to WiFi (Demo)',
      );
    }

    if (_ssidChar == null || _passChar == null || _statusChar == null) {
      return ProvisioningResult(success: false, message: 'Not connected to device');
    }

    _isCancelled = false;
    final completer = Completer<ProvisioningResult>();
    bool credentialsSent = false;

    // Enable GATT notifications — fast path, but may silently fail on some Android devices
    try {
      await _statusChar!.setNotifyValue(true);
      debugPrint('[BLE] Notifications enabled on status char');
    } catch (e) {
      debugPrint('[BLE] setNotifyValue failed: $e — polling will be used instead');
    }

    final notifSub = _statusChar!.onValueReceived.listen((value) {
      if (completer.isCompleted || _isCancelled) return;
      final status = String.fromCharCodes(value).trim();
      debugPrint('[BLE] Notification: $status');
      if (status == 'connecting') {
        credentialsSent = true;
      } else if (status == 'connected') {
        completer.complete(ProvisioningResult(success: true, message: 'Connected to WiFi successfully!'));
      } else if (status == 'failed') {
        completer.complete(ProvisioningResult(success: false, message: 'Failed to connect — check WiFi password'));
      }
    });

    // BLE disconnect handler — firmware disconnects BLE after provisioning succeeds.
    // If credentials were already sent and not cancelled, treat BLE drop as success.
    StreamSubscription? disconnectSub;
    if (_connectedDevice != null) {
      disconnectSub = _connectedDevice!.connectionState.listen((state) {
        if (completer.isCompleted) return;
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Disconnected. credentialsSent=$credentialsSent cancelled=$_isCancelled');
          if (_isCancelled) {
            completer.complete(ProvisioningResult(success: false, message: 'Provisioning cancelled'));
            return;
          }
          if (credentialsSent) {
            // Firmware disconnects BLE intentionally after WiFi success.
            // Wait briefly to let any in-flight notification arrive, then resolve.
            Future.delayed(const Duration(seconds: 3), () {
              if (!completer.isCompleted) {
                completer.complete(ProvisioningResult(success: true, message: 'Device connecting to WiFi...'));
              }
            });
          } else {
            completer.complete(ProvisioningResult(success: false, message: 'BLE disconnected before credentials were sent'));
          }
        }
      });
    }

    Timer? pollTimer;

    try {
      await _ssidChar!.write(ssid.codeUnits, withoutResponse: false);
      debugPrint('[BLE] SSID written');
      await Future.delayed(const Duration(milliseconds: 300));

      await _passChar!.write(password.codeUnits, withoutResponse: false);
      debugPrint('[BLE] Password written — credentials sent');
      credentialsSent = true;

      // Polling fallback: read status characteristic directly every 2 s.
      // This bypasses notification reliability issues on Android.
      // ESP32-S3 coexistence keeps BLE alive while WiFi connects, so polling works.
      pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (completer.isCompleted || _isCancelled) { timer.cancel(); return; }
        try {
          final raw = await _statusChar!.read();
          final status = String.fromCharCodes(raw).trim();
          debugPrint('[BLE] Polled status: $status');
          if (status == 'connected' && !completer.isCompleted) {
            timer.cancel();
            completer.complete(ProvisioningResult(success: true, message: 'Connected to WiFi successfully!'));
          } else if (status == 'failed' && !completer.isCompleted) {
            timer.cancel();
            completer.complete(ProvisioningResult(success: false, message: 'Failed to connect — check WiFi password'));
          }
        } catch (_) {
          // Read failed — BLE dropped; disconnect handler will take over
          timer.cancel();
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => ProvisioningResult(
          success: false,
          message: 'Timed out — device did not confirm WiFi connection.\n'
              'Check the ESP32 serial log, ensure the SSID is 2.4GHz, and try again.',
        ),
      );
    } catch (e) {
      return ProvisioningResult(success: false, message: 'Provisioning error: $e');
    } finally {
      pollTimer?.cancel();
      await notifSub.cancel();
      await disconnectSub?.cancel();
    }
  }

  Future<DeviceInfo?> getDeviceInfo() async {
    if (_demoMode) {
      return DeviceInfo(
        deviceId: 'demo-001',
        firmwareVersion: '1.0.0',
        hardwareVersion: 'ESP32-S3',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );
    }
    if (_connectedDevice == null) return null;
    final name = _connectedDevice!.platformName;
    return DeviceInfo(
      deviceId: 'esp32-${name.replaceFirst('BabyCare-', '').toLowerCase()}',
      firmwareVersion: 'unknown',
      hardwareVersion: 'ESP32-S3',
      macAddress: name.replaceFirst('BabyCare-', ''),
    );
  }

  Future<void> dispose() async {
    await stopScan();
    await disconnectDevice();
  }
}

// ─────────────────────── Data models ────────────────────────

class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice? device;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.device,
  });

  int get signalPercentage {
    final clamped = rssi.clamp(-100, -30);
    return ((clamped + 100) * 100 / 70).round();
  }
}

class WifiNetwork {
  final String ssid;
  final int signalStrength;
  final bool isSecure;

  WifiNetwork({
    required this.ssid,
    required this.signalStrength,
    this.isSecure = true,
  });

  int get signalBars {
    if (signalStrength >= -50) return 4;
    if (signalStrength >= -60) return 3;
    if (signalStrength >= -70) return 2;
    return 1;
  }
}

class DeviceInfo {
  final String deviceId;
  final String firmwareVersion;
  final String hardwareVersion;
  final String macAddress;

  DeviceInfo({
    required this.deviceId,
    required this.firmwareVersion,
    required this.hardwareVersion,
    required this.macAddress,
  });
}

class ProvisioningResult {
  final bool success;
  final String message;
  ProvisioningResult({required this.success, required this.message});
}

enum BluetoothState { on, off, unauthorized, unsupported, unknown }
