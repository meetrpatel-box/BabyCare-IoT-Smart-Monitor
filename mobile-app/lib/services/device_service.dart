import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';

/// Device service for IoT device management
/// Ported from React Native deviceService.ts
class DeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== Device Operations ====================

  /// Register a new device
  Future<String> registerDevice(DeviceModel device) async {
    final docRef =
        await _firestore.collection('devices').add(device.toFirestore());
    return docRef.id;
  }

  /// Get device by ID
  Future<DeviceModel?> getDevice(String deviceId) async {
    final doc = await _firestore.collection('devices').doc(deviceId).get();
    if (!doc.exists) return null;
    return DeviceModel.fromFirestore(doc);
  }

  /// Get devices for family
  Future<List<DeviceModel>> getFamilyDevices(String familyId) async {
    final snapshot = await _firestore
        .collection('devices')
        .where('familyId', isEqualTo: familyId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => DeviceModel.fromFirestore(doc)).toList();
  }

  /// Update device status
  Future<void> updateDeviceStatus(String deviceId, DeviceStatus status) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'status': status.value,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update device WiFi info
  Future<void> updateDeviceWiFi(String deviceId, WifiInfo wifiInfo) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'wifiInfo': wifiInfo.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assign device to baby
  Future<void> assignDeviceToBaby(String deviceId, String? babyId) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'assignedBabyId': babyId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update device name
  Future<void> updateDeviceName(String deviceId, String name) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete device
  Future<void> deleteDevice(String deviceId) async {
    await _firestore.collection('devices').doc(deviceId).delete();
  }

  /// Subscribe to device status
  Stream<DeviceModel?> subscribeToDeviceStatus(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) => doc.exists ? DeviceModel.fromFirestore(doc) : null);
  }

  /// Subscribe to family devices
  Stream<List<DeviceModel>> subscribeToFamilyDevices(String familyId) {
    return _firestore
        .collection('devices')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeviceModel.fromFirestore(doc))
            .toList());
  }

  // ==================== Device Commands ====================

  /// Send command to device
  Future<String> sendDeviceCommand({
    required String deviceId,
    required String commandType,
    Map<String, dynamic> payload = const {},
  }) async {
    final command = DeviceCommand(
      id: '',
      deviceId: deviceId,
      commandType: commandType,
      payload: payload,
      status: CommandStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('deviceCommands')
        .add(command.toFirestore());
    return docRef.id;
  }

  /// Get pending commands for device
  Future<List<DeviceCommand>> getPendingCommands(String deviceId) async {
    final snapshot = await _firestore
        .collection('deviceCommands')
        .where('deviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => DeviceCommand.fromFirestore(doc))
        .toList();
  }

  /// Update command status
  Future<void> updateCommandStatus(
    String commandId,
    CommandStatus status, {
    String? errorMessage,
  }) async {
    final data = <String, dynamic>{
      'status': status.value,
    };

    if (status == CommandStatus.completed || status == CommandStatus.failed) {
      data['executedAt'] = FieldValue.serverTimestamp();
    }

    if (errorMessage != null) {
      data['errorMessage'] = errorMessage;
    }

    await _firestore.collection('deviceCommands').doc(commandId).update(data);
  }

  // ==================== WiFi Provisioning ====================

  /// Start WiFi provisioning session
  Future<String> startWiFiProvisioning({
    required String deviceId,
    required String familyId,
  }) async {
    final docRef = await _firestore.collection('wifiProvisioning').add({
      'deviceId': deviceId,
      'familyId': familyId,
      'status': 'started',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update WiFi provisioning status
  Future<void> updateWiFiProvisioningStatus(
    String sessionId,
    String status, {
    String? ssid,
    String? errorMessage,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (ssid != null) data['ssid'] = ssid;
    if (errorMessage != null) data['errorMessage'] = errorMessage;

    await _firestore.collection('wifiProvisioning').doc(sessionId).update(data);
  }

  /// Complete WiFi provisioning
  Future<void> completeWiFiProvisioning(
    String sessionId, {
    required bool success,
    String? errorMessage,
  }) async {
    await _firestore.collection('wifiProvisioning').doc(sessionId).update({
      'status': success ? 'completed' : 'failed',
      'errorMessage': errorMessage,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}
