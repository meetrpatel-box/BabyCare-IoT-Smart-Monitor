import 'package:cloud_firestore/cloud_firestore.dart';

/// Vital Signs Model
/// Matches the data structure from device simulator
class VitalSign {
  final String id;
  final String babyId;
  final String deviceId;
  final int heartRate;
  final int respiratoryRate;
  final double bodyTemperature;
  final double skinTemperature;
  final double ambientTemperature;
  final int humidity;
  final DateTime timestamp;
  final String quality;
  final String movement;

  VitalSign({
    required this.id,
    required this.babyId,
    required this.deviceId,
    required this.heartRate,
    required this.respiratoryRate,
    required this.bodyTemperature,
    required this.skinTemperature,
    required this.ambientTemperature,
    required this.humidity,
    required this.timestamp,
    required this.quality,
    required this.movement,
  });

  factory VitalSign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitalSign(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      deviceId: data['deviceId'] ?? '',
      heartRate: data['heartRate'] ?? 0,
      respiratoryRate: data['respiratoryRate'] ?? 0,
      bodyTemperature: (data['bodyTemperature'] ?? 0).toDouble(),
      skinTemperature: (data['skinTemperature'] ?? 0).toDouble(),
      ambientTemperature: (data['ambientTemperature'] ?? 0).toDouble(),
      humidity: data['humidity'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      quality: data['quality'] ?? 'unknown',
      movement: data['movement'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'babyId': babyId,
      'deviceId': deviceId,
      'heartRate': heartRate,
      'respiratoryRate': respiratoryRate,
      'bodyTemperature': bodyTemperature,
      'skinTemperature': skinTemperature,
      'ambientTemperature': ambientTemperature,
      'humidity': humidity,
      'timestamp': Timestamp.fromDate(timestamp),
      'quality': quality,
      'movement': movement,
    };
  }

  bool get isHealthy {
    return heartRate >= 100 &&
        heartRate <= 180 &&
        respiratoryRate >= 30 &&
        respiratoryRate <= 60 &&
        bodyTemperature >= 36.5 &&
        bodyTemperature <= 37.5;
  }

  String get healthStatus {
    if (!isHealthy) {
      if (heartRate < 100 || heartRate > 180) return 'Heart rate abnormal';
      if (respiratoryRate < 30 || respiratoryRate > 60)
        return 'Respiratory rate abnormal';
      if (bodyTemperature < 36.5) return 'Temperature low';
      if (bodyTemperature > 37.5) return 'Temperature high';
    }
    return 'All vitals normal';
  }
}
