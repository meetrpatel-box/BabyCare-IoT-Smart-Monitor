import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../services/device_service.dart';
import '../services/wifi_provisioning_service.dart';
import '../utils/provisioning_helpers.dart';

/// Device state provider
/// Manages IoT devices and provisioning
class DeviceProvider extends ChangeNotifier {
  final DeviceService _deviceService = DeviceService();
  final WifiProvisioningService _provisioningService =
      WifiProvisioningService();

  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;
  bool _isLoading = false;
  String? _error;

  // Provisioning state
  bool _isProvisioning = false;
  ProvisioningStep _provisioningStep = ProvisioningStep.idle;
  List<DiscoveredDevice> _discoveredDevices = [];
  List<WifiNetwork> _wifiNetworks = [];
  DiscoveredDevice? _selectedBleDevice;

  StreamSubscription? _devicesSubscription;

  // Getters
  List<DeviceModel> get devices => _devices;
  DeviceModel? get selectedDevice => _selectedDevice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasDevices => _devices.isNotEmpty;

  // Provisioning getters
  bool get isProvisioning => _isProvisioning;
  ProvisioningStep get provisioningStep => _provisioningStep;
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;
  List<WifiNetwork> get wifiNetworks => _wifiNetworks;
  DiscoveredDevice? get selectedBleDevice => _selectedBleDevice;

  /// Load devices for family
  Future<void> loadDevicesForFamily(String familyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _devices = await _deviceService.getFamilyDevices(familyId);
      if (_devices.isNotEmpty && _selectedDevice == null) {
        _selectedDevice = _devices.first;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to family devices
  void subscribeToFamilyDevices(String familyId) {
    _devicesSubscription?.cancel();
    _devicesSubscription =
        _deviceService.subscribeToFamilyDevices(familyId).listen(
      (devices) {
        _devices = devices;
        if (_selectedDevice != null) {
          final updated = devices.firstWhere(
            (d) => d.id == _selectedDevice!.id,
            orElse: () => _selectedDevice!,
          );
          _selectedDevice = updated;
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error subscribing to devices: $e');
      },
    );
  }

  /// Select a device
  void selectDevice(DeviceModel device) {
    _selectedDevice = device;
    notifyListeners();
  }

  /// Assign device to baby
  Future<void> assignDeviceToBaby(String deviceId, String? babyId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _deviceService.assignDeviceToBaby(deviceId, babyId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update device name
  Future<void> updateDeviceName(String deviceId, String name) async {
    await _deviceService.updateDeviceName(deviceId, name);
  }

  /// Send command to device
  Future<void> sendCommand(String deviceId, String commandType,
      [Map<String, dynamic>? payload]) async {
    await _deviceService.sendDeviceCommand(
      deviceId: deviceId,
      commandType: commandType,
      payload: payload ?? {},
    );
  }

  // ==================== WiFi Provisioning ====================

  /// Enable demo mode for testing
  void setDemoMode(bool enabled) {
    _provisioningService.setDemoMode(enabled);
  }

  /// Start provisioning flow
  Future<void> startProvisioning() async {
    _isProvisioning = true;
    _provisioningStep = ProvisioningStep.checkingPermissions;
    _error = null;
    notifyListeners();

    try {
      // Check permissions
      final hasPermissions = await _provisioningService.requestPermissions();
      if (!hasPermissions) {
        _error = 'Bluetooth and location permissions are required';
        _provisioningStep = ProvisioningStep.idle;
        _isProvisioning = false;
        notifyListeners();
        return;
      }

      // Check Bluetooth state
      _provisioningStep = ProvisioningStep.checkingBluetooth;
      notifyListeners();

      final btState = await _provisioningService.checkBluetoothState();
      if (btState != BluetoothState.on) {
        _error = _getBluetoothErrorMessage(btState);
        _provisioningStep = ProvisioningStep.idle;
        _isProvisioning = false;
        notifyListeners();
        return;
      }

      // Start scanning for devices
      _provisioningStep = ProvisioningStep.scanning;
      notifyListeners();

      _discoveredDevices = await _provisioningService.scanForDevices();

      _provisioningStep = ProvisioningStep.selectingDevice;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _provisioningStep = ProvisioningStep.idle;
      _isProvisioning = false;
      notifyListeners();
    }
  }

  /// Select BLE device and connect
  Future<void> selectAndConnectDevice(DiscoveredDevice device) async {
    _selectedBleDevice = device;
    _provisioningStep = ProvisioningStep.connecting;
    notifyListeners();

    try {
      final connected = await _provisioningService.connectToDevice(device);
      if (!connected) {
        _error = 'Failed to connect to device';
        _provisioningStep = ProvisioningStep.selectingDevice;
        notifyListeners();
        return;
      }

      // Scan WiFi networks
      _provisioningStep = ProvisioningStep.scanningWifi;
      notifyListeners();

      _wifiNetworks = await _provisioningService.scanWifiNetworks();

      _provisioningStep = ProvisioningStep.selectingWifi;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _provisioningStep = ProvisioningStep.selectingDevice;
      notifyListeners();
    }
  }

  /// Provision WiFi credentials
  Future<bool> provisionWifi(
    String ssid,
    String password, {
    required String familyId,
    required String userId,
  }) async {
    _provisioningStep = ProvisioningStep.provisioning;
    _error = null;
    notifyListeners();

    try {
      final result = await _provisioningService.provisionWifi(
        ssid: ssid,
        password: password,
        claimToken: '',
      );

      if (result.success) {
        _provisioningStep = ProvisioningStep.completed;
        notifyListeners();
        debugPrint('✅ WiFi provisioning successful');

        // Persist last-used device and WiFi password for future quick-connect / auto-fill
        final bleDevice = _selectedBleDevice;
        if (bleDevice != null) {
          ProvisioningHelpers.saveLastDevice(bleDevice);
          ProvisioningHelpers.saveWiFiPassword(ssid, password);
        }

        // Register device in Firestore in background — don't block the success screen
        _registerDeviceInBackground(familyId: familyId, userId: userId);

        return true;
      } else {
        _error = result.message;
        _provisioningStep = ProvisioningStep.selectingWifi;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _provisioningStep = ProvisioningStep.selectingWifi;
      notifyListeners();
      return false;
    }
  }

  void _registerDeviceInBackground({
    required String familyId,
    required String userId,
  }) {
    Future(() async {
      try {
        final bleDevice = _selectedBleDevice;
        final deviceName = bleDevice?.name ?? 'BabyTrack Device';
        final deviceInfo = await _provisioningService.getDeviceInfo();

        final device = DeviceModel(
          id: '',
          name: deviceName,
          familyId: familyId,
          ownerId: userId,
          status: DeviceStatus.online,
          capabilities: DeviceCapabilities(
            hasCamera: false,
            hasMicrophone: true,
            hasSpeaker: true,
            hasVitalSensors: true,
            supportsVideo: false,
            supportsAudio: true,
          ),
          firmwareVersion: deviceInfo?.firmwareVersion,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newDeviceId = await _deviceService.registerDevice(device);
        debugPrint('✅ Device registered in Firestore: $newDeviceId');
      } catch (e) {
        debugPrint('⚠️ Firestore registration failed (device still provisioned): $e');
      }
    });
  }

  /// Cancel provisioning
  Future<void> cancelProvisioning() async {
    // Signal first so the disconnect handler doesn't misread the drop as success
    _provisioningService.signalCancellation();
    await _provisioningService.stopScan();
    await _provisioningService.disconnectDevice();

    _isProvisioning = false;
    _provisioningStep = ProvisioningStep.idle;
    _discoveredDevices = [];
    _wifiNetworks = [];
    _selectedBleDevice = null;
    _error = null;
    notifyListeners();
  }

  /// Reset provisioning to scan again
  Future<void> rescanDevices() async {
    _provisioningStep = ProvisioningStep.scanning;
    _discoveredDevices = [];
    _error = null;
    notifyListeners();

    // Disconnect existing BLE device before scanning so the radio is free
    await _provisioningService.disconnectDevice();

    try {
      _discoveredDevices = await _provisioningService.scanForDevices();
      _provisioningStep = ProvisioningStep.selectingDevice;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _provisioningStep = ProvisioningStep.selectingDevice;
      notifyListeners();
    }
  }

  /// Register provisioned device
  Future<String> registerDevice({
    required String name,
    required String familyId,
    required String ownerId,
  }) async {
    final deviceInfo = await _provisioningService.getDeviceInfo();

    final device = DeviceModel(
      id: '',
      name: name,
      familyId: familyId,
      ownerId: ownerId,
      status: DeviceStatus.online,
      capabilities: DeviceCapabilities(
        hasCamera: true,
        hasMicrophone: true,
        hasSpeaker: true,
        hasVitalSensors: true,
        supportsVideo: true,
        supportsAudio: true,
      ),
      firmwareVersion: deviceInfo?.firmwareVersion,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final deviceId = await _deviceService.registerDevice(device);

    // Cleanup provisioning
    await cancelProvisioning();

    return deviceId;
  }

  String _getBluetoothErrorMessage(BluetoothState state) {
    switch (state) {
      case BluetoothState.off:
        return 'Please enable Bluetooth';
      case BluetoothState.unauthorized:
        return 'Bluetooth permission denied';
      case BluetoothState.unsupported:
        return 'Bluetooth not supported on this device';
      default:
        return 'Bluetooth not available';
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear state (on logout)
  Future<void> clear() async {
    await _devicesSubscription?.cancel();
    await _provisioningService.dispose();
    _devices = [];
    _selectedDevice = null;
    _isLoading = false;
    _error = null;
    _isProvisioning = false;
    _provisioningStep = ProvisioningStep.idle;
    _discoveredDevices = [];
    _wifiNetworks = [];
    _selectedBleDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    // Note: Can't await in synchronous dispose, cleanup will happen async
    _provisioningService.dispose();
    super.dispose();
  }
}

/// Provisioning flow steps
enum ProvisioningStep {
  idle,
  checkingPermissions,
  checkingBluetooth,
  scanning,
  selectingDevice,
  connecting,
  scanningWifi,
  selectingWifi,
  provisioning,
  completed,
}
