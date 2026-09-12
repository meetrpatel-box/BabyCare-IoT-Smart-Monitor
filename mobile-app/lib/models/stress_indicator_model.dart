import 'package:cloud_firestore/cloud_firestore.dart';

/// Stress level categories
enum StressLevel {
  low,      // 0-30
  moderate, // 31-60
  high,     // 61-85
  critical, // 86-100
}

/// Extension for stress level display
extension StressLevelExtension on StressLevel {
  String get displayName {
    switch (this) {
      case StressLevel.low:
        return 'Low';
      case StressLevel.moderate:
        return 'Moderate';
      case StressLevel.high:
        return 'High';
      case StressLevel.critical:
        return 'Critical';
    }
  }

  String get parentFriendlyMessage {
    switch (this) {
      case StressLevel.low:
        return 'Baby is sleeping peacefully with minimal disturbances';
      case StressLevel.moderate:
        return 'Baby shows some restlessness during sleep';
      case StressLevel.high:
        return 'Baby appears to be experiencing sleep disruptions';
      case StressLevel.critical:
        return 'Baby may need extra comfort and attention during sleep';
    }
  }
}

/// Stress indicator model
/// Combines calculated stress (from sleep patterns) and measured stress (from device sensors)
class StressIndicator {
  final String id;
  final String babyId;
  final DateTime timestamp;

  // Calculated stress from sleep patterns
  final double? calculatedStressLevel; // 0-100
  final Map<String, dynamic>? calculatedFactors; // Contributing factors

  // Measured stress from device (HRV/cortisol sensors - optional)
  final double? measuredHRV; // Heart rate variability (ms)
  final double? measuredCortisol; // Cortisol level (if available)
  final double? measuredStressScore; // Device-computed stress (0-100)

  // Combined assessment
  final double overallStressLevel; // Weighted avg of calculated + measured
  final StressLevel stressLevelCategory;

  // Metadata
  final DateTime createdAt;
  final DateTime? expiresAt; // Stress indicators expire after 7 days

  const StressIndicator({
    required this.id,
    required this.babyId,
    required this.timestamp,
    this.calculatedStressLevel,
    this.calculatedFactors,
    this.measuredHRV,
    this.measuredCortisol,
    this.measuredStressScore,
    required this.overallStressLevel,
    required this.stressLevelCategory,
    required this.createdAt,
    this.expiresAt,
  });

  /// Create from map (Firestore)
  factory StressIndicator.fromMap(Map<String, dynamic> map) {
    final overallStress = (map['overallStressLevel'] as num?)?.toDouble() ?? 0.0;

    return StressIndicator(
      id: map['id'] as String,
      babyId: map['babyId'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      calculatedStressLevel: (map['calculatedStressLevel'] as num?)?.toDouble(),
      calculatedFactors: map['calculatedFactors'] as Map<String, dynamic>?,
      measuredHRV: (map['measuredHRV'] as num?)?.toDouble(),
      measuredCortisol: (map['measuredCortisol'] as num?)?.toDouble(),
      measuredStressScore: (map['measuredStressScore'] as num?)?.toDouble(),
      overallStressLevel: overallStress,
      stressLevelCategory: _getStressLevelFromScore(overallStress),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: map['expiresAt'] != null
        ? (map['expiresAt'] as Timestamp).toDate()
        : null,
    );
  }

  /// Convert to map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'babyId': babyId,
      'timestamp': Timestamp.fromDate(timestamp),
      'calculatedStressLevel': calculatedStressLevel,
      'calculatedFactors': calculatedFactors,
      'measuredHRV': measuredHRV,
      'measuredCortisol': measuredCortisol,
      'measuredStressScore': measuredStressScore,
      'overallStressLevel': overallStressLevel,
      'stressLevelCategory': stressLevelCategory.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  /// Determine stress level category from score
  static StressLevel _getStressLevelFromScore(double score) {
    if (score <= 30) return StressLevel.low;
    if (score <= 60) return StressLevel.moderate;
    if (score <= 85) return StressLevel.high;
    return StressLevel.critical;
  }

  /// Create a copy with updated fields
  StressIndicator copyWith({
    String? id,
    String? babyId,
    DateTime? timestamp,
    double? calculatedStressLevel,
    Map<String, dynamic>? calculatedFactors,
    double? measuredHRV,
    double? measuredCortisol,
    double? measuredStressScore,
    double? overallStressLevel,
    StressLevel? stressLevelCategory,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return StressIndicator(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      timestamp: timestamp ?? this.timestamp,
      calculatedStressLevel: calculatedStressLevel ?? this.calculatedStressLevel,
      calculatedFactors: calculatedFactors ?? this.calculatedFactors,
      measuredHRV: measuredHRV ?? this.measuredHRV,
      measuredCortisol: measuredCortisol ?? this.measuredCortisol,
      measuredStressScore: measuredStressScore ?? this.measuredStressScore,
      overallStressLevel: overallStressLevel ?? this.overallStressLevel,
      stressLevelCategory: stressLevelCategory ?? this.stressLevelCategory,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'StressIndicator(id: $id, babyId: $babyId, overallStress: $overallStressLevel, category: ${stressLevelCategory.displayName})';
  }
}
