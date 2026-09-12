/// Live sensor readings received from the ESP32 board via MQTT.
class MqttVitals {
  final double bodyTemperature;
  final int heartRate;
  final int humidity;
  final int respiratoryRate;
  final int spo2;
  final double ambientTemperature;
  final double skinTemperature;
  final bool movementDetected;
  final String sleepState;
  final int sleepCount;
  final bool isSleeping;
  final DateTime timestamp;

  const MqttVitals({
    required this.bodyTemperature,
    required this.heartRate,
    required this.humidity,
    required this.respiratoryRate,
    required this.spo2,
    required this.ambientTemperature,
    required this.skinTemperature,
    required this.movementDetected,
    this.sleepState = 'AWAKE',
    this.sleepCount = 0,
    this.isSleeping = false,
    required this.timestamp,
  });

  factory MqttVitals.fromJson(Map<String, dynamic> json) {
    return MqttVitals(
      bodyTemperature: (json['bodyTemperature'] as num?)?.toDouble() ?? 36.6,
      heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      respiratoryRate: (json['respiratoryRate'] as num?)?.toInt() ?? 0,
      spo2: (json['spo2'] as num?)?.toInt() ?? 0,
      ambientTemperature: (json['ambientTemperature'] as num?)?.toDouble() ?? 22.0,
      skinTemperature: (json['skinTemperature'] as num?)?.toDouble() ?? 36.0,
      movementDetected: ((json['movement'] as num?)?.toDouble() ?? 0.0) > 0.0,
      sleepState: json['sleepState'] as String? ?? 'AWAKE',
      sleepCount: (json['sleepCount'] as num?)?.toInt() ?? 0,
      isSleeping: json['isSleeping'] as bool? ?? false,
      timestamp: DateTime.now(),
    );
  }
}

/// MQTT Device Representation
/// Maps Firestore device to MQTT communication
class MqttDeviceModel {
  final String deviceId;
  final String deviceName;
  final String familyId;
  final String? assignedBabyId;
  final DeviceConnectionStatus status;
  final DateTime lastSeenAt;
  final String? mqttTopic;
  final Map<String, dynamic>? lastMessage;
  final MqttVitals? latestVitals;
  final String? deviceIp; // board's LAN IP for MJPEG stream
  final String? streamId; // cloud relay stream ID (e.g. CAME36380)

  MqttDeviceModel({
    required this.deviceId,
    required this.deviceName,
    required this.familyId,
    this.assignedBabyId,
    this.status = DeviceConnectionStatus.offline,
    DateTime? lastSeenAt,
    this.mqttTopic,
    this.lastMessage,
    this.latestVitals,
    this.deviceIp,
    this.streamId = 'CAME36380',
  }) : lastSeenAt = lastSeenAt ?? DateTime.now();

  String get effectiveStreamId => streamId ?? 'CAME36380';

  /// Generate MQTT topic for this device
  String get cmdTopic => 'cradle/$deviceId/cmd';
  String get statusTopic => 'cradle/$deviceId/status';
  String get configTopic => 'cradle/$deviceId/config';

  /// Check if device is online
  bool get isOnline => status == DeviceConnectionStatus.online;

  /// Get time since last seen
  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeenAt);

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'familyId': familyId,
    'assignedBabyId': assignedBabyId,
    'status': status.value,
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'mqttTopic': mqttTopic,
    'streamId': streamId,
  };

  /// Create from JSON
  factory MqttDeviceModel.fromJson(Map<String, dynamic> json) {
    return MqttDeviceModel(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      familyId: json['familyId'] as String,
      assignedBabyId: json['assignedBabyId'] as String?,
      status: DeviceConnectionStatus.values.firstWhere(
        (e) => e.value == json['status'],
        orElse: () => DeviceConnectionStatus.offline,
      ),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : DateTime.now(),
      mqttTopic: json['mqttTopic'] as String?,
      streamId: json['streamId'] as String? ?? 'CAME36380',
    );
  }

  /// Copy with modifications
  MqttDeviceModel copyWith({
    String? deviceId,
    String? deviceName,
    String? familyId,
    String? assignedBabyId,
    DeviceConnectionStatus? status,
    DateTime? lastSeenAt,
    String? mqttTopic,
    Map<String, dynamic>? lastMessage,
    MqttVitals? latestVitals,
    String? deviceIp,
    String? streamId,
  }) {
    return MqttDeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      familyId: familyId ?? this.familyId,
      assignedBabyId: assignedBabyId ?? this.assignedBabyId,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      lastMessage: lastMessage ?? this.lastMessage,
      latestVitals: latestVitals ?? this.latestVitals,
      deviceIp: deviceIp ?? this.deviceIp,
      streamId: streamId ?? this.streamId,
    );
  }

  @override
  String toString() => '''MqttDeviceModel(
    deviceId: $deviceId,
    deviceName: $deviceName,
    status: ${status.value},
    isOnline: $isOnline,
    cmdTopic: $cmdTopic,
    statusTopic: $statusTopic
  )''';
}

/// Device connection status enum
enum DeviceConnectionStatus {
  online('online'),
  offline('offline'),
  error('error'),
  unknown('unknown');

  final String value;
  const DeviceConnectionStatus(this.value);

  factory DeviceConnectionStatus.fromString(String value) {
    return DeviceConnectionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceConnectionStatus.unknown,
    );
  }
}

/// MQTT Command Payload
class MqttCommand {
  final String command;
  final Map<String, dynamic>? params;
  final int? messageId;

  MqttCommand({
    required this.command,
    this.params,
    this.messageId,
  });

  Map<String, dynamic> toJson() => {
    'cmd': command,
    if (params != null) ...params!,
    if (messageId != null) 'msgId': messageId,
  };

  String toJsonString() {
    final map = toJson();
    final pairs = map.entries
        .map((e) {
          if (e.value is String) {
            return '"${e.key}":"${e.value}"';
          } else if (e.value is num) {
            return '"${e.key}":${e.value}';
          } else {
            return '"${e.key}":${e.value}';
          }
        })
        .join(',');
    return '{$pairs}';
  }

  factory MqttCommand.fromJson(Map<String, dynamic> json) {
    return MqttCommand(
      command: json['cmd'] as String,
      params: json,
      messageId: json['msgId'] as int?,
    );
  }
}

/// MQTT Status Response
class MqttStatusResponse {
  final String status;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  MqttStatusResponse({
    required this.status,
    DateTime? timestamp,
    this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MqttStatusResponse.fromJson(Map<String, dynamic> json) {
    return MqttStatusResponse(
      status: json['status'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      details: json,
    );
  }

  bool get isOnline => status.toLowerCase() == 'online';
}
