import 'dart:convert';

/// Stores one successful cry-analysis result for the history tab.
class CryHistoryEntry {
  final String
      prediction; // 'hungry', 'tired', 'discomfort', 'belly_pain', 'burping'
  final double confidence; // 0–100
  final String reliability; // 'high' | 'medium' | 'low'
  final DateTime timestamp;
  final String? fileName; // recording label or upload filename

  const CryHistoryEntry({
    required this.prediction,
    required this.confidence,
    required this.reliability,
    required this.timestamp,
    this.fileName,
  });

  String get emoji {
    const map = {
      'hungry': '🍼',
      'tired': '😴',
      'discomfort': '😣',
      'belly_pain': '🤢',
      'burping': '💨',
    };
    return map[prediction] ?? '🍼';
  }

  String get displayName => prediction.replaceAll('_', ' ').toUpperCase();

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'prediction': prediction,
        'confidence': confidence,
        'reliability': reliability,
        'timestamp': timestamp.toIso8601String(),
        'fileName': fileName,
      };

  factory CryHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CryHistoryEntry(
        prediction: json['prediction'] as String? ?? 'unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        reliability: json['reliability'] as String? ?? 'medium',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        fileName: json['fileName'] as String?,
      );

  // ── Helpers for SharedPrefs list ──────────────────────────────────────────

  String toJsonString() => jsonEncode(toJson());

  static CryHistoryEntry? fromJsonString(String s) {
    try {
      return CryHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
