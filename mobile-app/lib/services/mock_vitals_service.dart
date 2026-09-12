import 'dart:async';
import 'dart:math';
import '../models/vital_sign.dart';
import '../models/sleep_model.dart';

/// Generates realistic mock baby vitals for development/testing.
/// Gate usage with kMockVitals from app_config.dart — never call in release.
class MockVitalsService {
  static final _rng = Random();

  // ── Single VitalSign ────────────────────────────────────────────────────

  static VitalSign generate({
    required String babyId,
    String deviceId = 'mock-esp32-001',
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final bodyTemp = _round(36.4 + _rng.nextDouble() * 1.1, 1); // 36.4–37.5°C
    return VitalSign(
      id: 'mock_${now.millisecondsSinceEpoch}',
      babyId: babyId,
      deviceId: deviceId,
      heartRate: 110 + _rng.nextInt(36),           // 110–145 bpm
      respiratoryRate: 30 + _rng.nextInt(21),       // 30–50 /min
      bodyTemperature: bodyTemp,
      skinTemperature: _round(bodyTemp - 0.1 - _rng.nextDouble() * 0.3, 1),
      ambientTemperature: _round(22.0 + _rng.nextDouble() * 4.0, 1), // 22–26°C
      humidity: 45 + _rng.nextInt(21),              // 45–65 %
      timestamp: now,
      quality: 'good',
      movement: _rng.nextInt(5) == 0 ? 'detected' : 'none', // ~20% chance
    );
  }

  /// Spaced readings over a date range — used by getVitalSignsInRange mock.
  static List<VitalSign> generateRange({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
    int count = 48,
  }) {
    final span = endDate.difference(startDate);
    final step = Duration(
      minutes: span.inMinutes ~/ count.clamp(1, 288),
    );
    return List.generate(count, (i) {
      final ts = startDate.add(step * i);
      return generate(babyId: babyId, timestamp: ts);
    });
  }

  /// Streaming: yields a new list every [interval], newest-first.
  static Stream<List<VitalSign>> stream(
    String babyId, {
    int limit = 10,
    Duration interval = const Duration(seconds: 5),
  }) async* {
    final buffer = <VitalSign>[];
    final now = DateTime.now();
    for (int i = limit - 1; i >= 0; i--) {
      buffer.add(generate(
        babyId: babyId,
        timestamp: now.subtract(Duration(seconds: i * interval.inSeconds)),
      ));
    }
    yield List.from(buffer);

    await for (final _ in Stream.periodic(interval)) {
      buffer.insert(0, generate(babyId: babyId));
      if (buffer.length > limit) buffer.removeLast();
      yield List.from(buffer);
    }
  }

  // ── VitalLog (Trends screen — includes SpO2) ────────────────────────────

  static VitalLog generateLog({
    required String babyId,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return VitalLog(
      id: 'mock_log_${now.millisecondsSinceEpoch}_${_rng.nextInt(9999)}',
      babyId: babyId,
      heartRate: 110 + _rng.nextInt(36),            // 110–145 bpm
      spO2: 95 + _rng.nextInt(6),                   // 95–100 %
      temperature: _round(36.4 + _rng.nextDouble() * 1.1, 1),
      timestamp: now,
    );
  }

  static List<VitalLog> generateVitalLogs({
    required String babyId,
    int count = 60,
    int days = 7,
  }) {
    final now = DateTime.now();
    final step = Duration(minutes: (days * 24 * 60) ~/ count.clamp(1, 1000));
    return List.generate(count, (i) {
      final ts = now.subtract(step * (count - 1 - i));
      return generateLog(babyId: babyId, timestamp: ts);
    });
  }

  // ── Latest-vitals map (matches BabyProvider._latestVitals shape) ────────

  static Map<String, dynamic> latestVitalsMap(String babyId) {
    final v = generate(babyId: babyId);
    return {
      'heartRate': v.heartRate,
      'respiratoryRate': v.respiratoryRate,
      'bodyTemperature': v.bodyTemperature,
      'humidity': v.humidity,
      'movement': v.movement,
      'timestamp': v.timestamp.toIso8601String(),
    };
  }

  // ── Averages map (matches VitalSignsService.getTodayAverages shape) ─────

  static Map<String, double> todayAverages(String babyId) {
    return {
      'heartRate': 110.0 + _rng.nextInt(36),
      'respiratoryRate': 30.0 + _rng.nextInt(21),
      'bodyTemperature': _round(36.4 + _rng.nextDouble() * 1.1, 1),
    };
  }

  static double _round(double v, int decimals) {
    final factor = pow(10, decimals).toDouble();
    return (v * factor).round() / factor;
  }
}
