import 'package:cloud_firestore/cloud_firestore.dart';

/// IoT device model for baby monitoring pods
/// Ported from React Native Device type
class DeviceModel {
  final String id;
  final String name;
  final String familyId;
  final String? assignedBabyId;
  final DeviceStatus status;
  final DeviceCapabilities capabilities;
  final String? firmwareVersion;
  final int? batteryLevel;
  final WifiInfo? wifiInfo;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Ownership and permission fields
  final String ownerId;
  final List<String> authorizedUsers;
  final DateTime? registeredAt;

  DeviceModel({
    required this.id,
    required this.name,
    required this.familyId,
    this.assignedBabyId,
    this.status = DeviceStatus.offline,
    required this.capabilities,
    this.firmwareVersion,
    this.batteryLevel,
    this.wifiInfo,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.authorizedUsers = const [],
    this.registeredAt,
  });

  bool get isOnline => status == DeviceStatus.online;

  /// Check if a user can manage this device
  /// Owner always has access, authorized users have access
  bool canManage(String userId) {
    if (userId == ownerId) return true;
    if (authorizedUsers.contains(userId)) return true;
    return false;
  }

  factory DeviceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown Device',
      familyId: data['familyId'] ?? '',
      assignedBabyId: data['assignedBabyId'],
      status: DeviceStatus.fromString(data['status']),
      capabilities: DeviceCapabilities.fromMap(data['capabilities'] ?? {}),
      firmwareVersion: data['firmwareVersion'],
      batteryLevel: data['batteryLevel'],
      wifiInfo:
          data['wifiInfo'] != null ? WifiInfo.fromMap(data['wifiInfo']) : null,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerId: data['ownerId'] ?? '',
      authorizedUsers: List<String>.from(data['authorizedUsers'] ?? []),
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'familyId': familyId,
      'assignedBabyId': assignedBabyId,
      'status': status.value,
      'capabilities': capabilities.toMap(),
      'firmwareVersion': firmwareVersion,
      'batteryLevel': batteryLevel,
      'wifiInfo': wifiInfo?.toMap(),
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ownerId': ownerId,
      'authorizedUsers': authorizedUsers,
      'registeredAt': registeredAt != null ? Timestamp.fromDate(registeredAt!) : null,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? familyId,
    String? assignedBabyId,
    DeviceStatus? status,
    DeviceCapabilities? capabilities,
    String? firmwareVersion,
    int? batteryLevel,
    WifiInfo? wifiInfo,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerId,
    List<String>? authorizedUsers,
    DateTime? registeredAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      familyId: familyId ?? this.familyId,
      assignedBabyId: assignedBabyId ?? this.assignedBabyId,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      wifiInfo: wifiInfo ?? this.wifiInfo,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerId: ownerId ?? this.ownerId,
      authorizedUsers: authorizedUsers ?? this.authorizedUsers,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

/// Device status enum
enum DeviceStatus {
  online('online'),
  offline('offline'),
  provisioning('provisioning'),
  error('error');

  final String value;
  const DeviceStatus(this.value);

  static DeviceStatus fromString(String? value) {
    return DeviceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceStatus.offline,
    );
  }
}

/// Device capabilities
class DeviceCapabilities {
  final bool hasCamera;
  final bool hasMicrophone;
  final bool hasSpeaker;
  final bool hasVitalSensors;
  final bool supportsVideo;
  final bool supportsAudio;

  DeviceCapabilities({
    this.hasCamera = false,
    this.hasMicrophone = false,
    this.hasSpeaker = false,
    this.hasVitalSensors = true,
    this.supportsVideo = false,
    this.supportsAudio = false,
  });

  factory DeviceCapabilities.fromMap(Map<String, dynamic> map) {
    return DeviceCapabilities(
      hasCamera: map['hasCamera'] ?? false,
      hasMicrophone: map['hasMicrophone'] ?? false,
      hasSpeaker: map['hasSpeaker'] ?? false,
      hasVitalSensors: map['hasVitalSensors'] ?? true,
      supportsVideo: map['supportsVideo'] ?? false,
      supportsAudio: map['supportsAudio'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasCamera': hasCamera,
      'hasMicrophone': hasMicrophone,
      'hasSpeaker': hasSpeaker,
      'hasVitalSensors': hasVitalSensors,
      'supportsVideo': supportsVideo,
      'supportsAudio': supportsAudio,
    };
  }
}

/// WiFi connection info
class WifiInfo {
  final String ssid;
  final int signalStrength;
  final bool isConnected;

  WifiInfo({
    required this.ssid,
    this.signalStrength = 0,
    this.isConnected = false,
  });

  factory WifiInfo.fromMap(Map<String, dynamic> map) {
    return WifiInfo(
      ssid: map['ssid'] ?? '',
      signalStrength: map['signalStrength'] ?? 0,
      isConnected: map['isConnected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'signalStrength': signalStrength,
      'isConnected': isConnected,
    };
  }
}

/// Device command model
class DeviceCommand {
  final String id;
  final String deviceId;
  final String commandType;
  final Map<String, dynamic> payload;
  final CommandStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? executedAt;

  DeviceCommand({
    required this.id,
    required this.deviceId,
    required this.commandType,
    this.payload = const {},
    this.status = CommandStatus.pending,
    this.errorMessage,
    required this.createdAt,
    this.executedAt,
  });

  factory DeviceCommand.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceCommand(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      commandType: data['commandType'] ?? '',
      payload: Map<String, dynamic>.from(data['payload'] ?? {}),
      status: CommandStatus.fromString(data['status']),
      errorMessage: data['errorMessage'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      executedAt: (data['executedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'commandType': commandType,
      'payload': payload,
      'status': status.value,
      'errorMessage': errorMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'executedAt': executedAt != null ? Timestamp.fromDate(executedAt!) : null,
    };
  }
}

/// Command status enum
enum CommandStatus {
  pending('pending'),
  executing('executing'),
  completed('completed'),
  failed('failed');

  final String value;
  const CommandStatus(this.value);

  static CommandStatus fromString(String? value) {
    return CommandStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommandStatus.pending,
    );
  }
}
