import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_config.dart';
import '../models/vital_sign.dart';
import 'mock_vitals_service.dart';

/// Vital Signs Service
/// Handles real-time streaming of vital signs from Firestore
class VitalSignsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream vital signs for a specific baby (real-time updates)
  Stream<List<VitalSign>> streamVitalSigns(String babyId, {int limit = 10}) {
    if (kMockVitals) return MockVitalsService.stream(babyId, limit: limit);
    return _firestore
        .collection('vital_signs')
        .where('babyId', isEqualTo: babyId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => VitalSign.fromFirestore(doc)).toList();
    });
  }

  /// Get latest vital sign for a baby
  Future<VitalSign?> getLatestVitalSign(String babyId) async {
    if (kMockVitals) return MockVitalsService.generate(babyId: babyId);
    final snapshot = await _firestore
        .collection('vital_signs')
        .where('babyId', isEqualTo: babyId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return VitalSign.fromFirestore(snapshot.docs.first);
  }

  /// Get vital signs for a specific time range
  Future<List<VitalSign>> getVitalSignsInRange(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (kMockVitals) {
      return MockVitalsService.generateRange(
        babyId: babyId,
        startDate: startDate,
        endDate: endDate,
      );
    }
    final snapshot = await _firestore
        .collection('vital_signs')
        .where('babyId', isEqualTo: babyId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => VitalSign.fromFirestore(doc)).toList();
  }

  /// Get vital signs for today
  Future<List<VitalSign>> getTodayVitalSigns(String babyId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getVitalSignsInRange(babyId, startOfDay, endOfDay);
  }

  /// Add a manual vital sign reading
  Future<void> addVitalSign(VitalSign vitalSign) async {
    await _firestore.collection('vital_signs').add(vitalSign.toMap());
  }

  /// Get average vital signs for today
  Future<Map<String, double>> getTodayAverages(String babyId) async {
    if (kMockVitals) return MockVitalsService.todayAverages(babyId);
    final vitals = await getTodayVitalSigns(babyId);

    if (vitals.isEmpty) {
      return {
        'heartRate': 0,
        'respiratoryRate': 0,
        'bodyTemperature': 0,
      };
    }

    final avgHR =
        vitals.map((v) => v.heartRate).reduce((a, b) => a + b) / vitals.length;
    final avgRR = vitals.map((v) => v.respiratoryRate).reduce((a, b) => a + b) /
        vitals.length;
    final avgTemp =
        vitals.map((v) => v.bodyTemperature).reduce((a, b) => a + b) /
            vitals.length;

    return {
      'heartRate': avgHR,
      'respiratoryRate': avgRR,
      'bodyTemperature': avgTemp,
    };
  }
}
