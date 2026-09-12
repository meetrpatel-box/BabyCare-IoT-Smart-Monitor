import 'package:cloud_firestore/cloud_firestore.dart';

/// Baby profile model
/// Ported from React Native Baby type
class BabyModel {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String? photoUrl;
  final String parentId;
  final String? familyId;
  final String? assignedDeviceId;
  final LatestVitals? latestVitals;
  final DateTime createdAt;
  final DateTime updatedAt;

  BabyModel({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    this.photoUrl,
    required this.parentId,
    this.familyId,
    this.assignedDeviceId,
    this.latestVitals,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate age in months
  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - dateOfBirth.year) * 12 + (now.month - dateOfBirth.month);
  }

  /// Get age display string
  String get ageDisplay {
    final months = ageInMonths;
    if (months < 1) {
      final days = DateTime.now().difference(dateOfBirth).inDays;
      return '$days days';
    } else if (months < 12) {
      return '$months months';
    } else {
      final years = months ~/ 12;
      final remainingMonths = months % 12;
      if (remainingMonths == 0) {
        return '$years ${years == 1 ? 'year' : 'years'}';
      }
      return '$years ${years == 1 ? 'year' : 'years'}, $remainingMonths months';
    }
  }

  factory BabyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BabyModel(
      id: doc.id,
      name: data['name'] ?? '',
      dateOfBirth:
          (data['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: data['gender'] ?? 'unknown',
      photoUrl: data['photoUrl'],
      parentId: data['parentId'] ?? '',
      familyId: data['familyId'],
      assignedDeviceId: data['assignedDeviceId'],
      latestVitals: data['latestVitals'] != null
          ? LatestVitals.fromMap(data['latestVitals'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender,
      'photoUrl': photoUrl,
      'parentId': parentId,
      'familyId': familyId,
      'assignedDeviceId': assignedDeviceId,
      'latestVitals': latestVitals?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BabyModel copyWith({
    String? id,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
    String? parentId,
    String? familyId,
    String? assignedDeviceId,
    LatestVitals? latestVitals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BabyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      parentId: parentId ?? this.parentId,
      familyId: familyId ?? this.familyId,
      assignedDeviceId: assignedDeviceId ?? this.assignedDeviceId,
      latestVitals: latestVitals ?? this.latestVitals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Latest vitals data embedded in baby document
class LatestVitals {
  final int? spO2;
  final VitalStatus spO2Status;
  final double? temperature;
  final TemperatureStatus temperatureStatus;
  final bool isCrying;
  final bool isWet;
  final PressureStatus pressureStatus;
  final int? heartRate;
  final DateTime? lastUpdated;

  LatestVitals({
    this.spO2,
    this.spO2Status = VitalStatus.unknown,
    this.temperature,
    this.temperatureStatus = TemperatureStatus.normal,
    this.isCrying = false,
    this.isWet = false,
    this.pressureStatus = PressureStatus.unknown,
    this.heartRate,
    this.lastUpdated,
  });

  factory LatestVitals.fromMap(Map<String, dynamic> map) {
    return LatestVitals(
      spO2: map['spO2'],
      spO2Status: VitalStatus.fromString(map['spO2Status']),
      temperature: (map['temperature'] as num?)?.toDouble(),
      temperatureStatus: TemperatureStatus.fromString(map['temperatureStatus']),
      isCrying: map['isCrying'] ?? false,
      isWet: map['isWet'] ?? false,
      pressureStatus: PressureStatus.fromString(map['pressureStatus']),
      heartRate: map['heartRate'],
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spO2': spO2,
      'spO2Status': spO2Status.value,
      'temperature': temperature,
      'temperatureStatus': temperatureStatus.value,
      'isCrying': isCrying,
      'isWet': isWet,
      'pressureStatus': pressureStatus.value,
      'heartRate': heartRate,
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }
}

/// SpO2 vital status enum
enum VitalStatus {
  normal('Normal'),
  low('Low'),
  critical('Critical'),
  unknown('Unknown');

  final String value;
  const VitalStatus(this.value);

  static VitalStatus fromString(String? value) {
    return VitalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VitalStatus.unknown,
    );
  }
}

/// Temperature status enum
enum TemperatureStatus {
  normal('Normal'),
  slightlyElevated('Slightly Elevated'),
  fever('Fever');

  final String value;
  const TemperatureStatus(this.value);

  static TemperatureStatus fromString(String? value) {
    return TemperatureStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TemperatureStatus.normal,
    );
  }
}

/// Pressure status enum
enum PressureStatus {
  optimal('Optimal'),
  check('Check'),
  unknown('Unknown');

  final String value;
  const PressureStatus(this.value);

  static PressureStatus fromString(String? value) {
    return PressureStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PressureStatus.unknown,
    );
  }
}
