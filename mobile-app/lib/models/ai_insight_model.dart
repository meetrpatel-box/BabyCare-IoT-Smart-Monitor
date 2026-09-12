import 'package:cloud_firestore/cloud_firestore.dart';

/// AI-generated insight model
/// Ported from React Native AIInsight type
class AIInsight {
  final String id;
  final String babyId;
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String description;
  final List<String>? recommendations;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AIInsight({
    required this.id,
    required this.babyId,
    required this.type,
    this.priority = InsightPriority.low,
    required this.title,
    required this.description,
    this.recommendations,
    this.metadata,
    this.isRead = false,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isHighPriority =>
      priority == InsightPriority.high || priority == InsightPriority.critical;

  factory AIInsight.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIInsight(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      type: InsightType.fromString(data['type']),
      priority: InsightPriority.fromString(data['priority']),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      recommendations: data['recommendations'] != null
          ? List<String>.from(data['recommendations'])
          : null,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'type': type.value,
      'priority': priority.value,
      'title': title,
      'description': description,
      'recommendations': recommendations,
      'metadata': metadata,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  AIInsight copyWith({
    String? id,
    String? babyId,
    InsightType? type,
    InsightPriority? priority,
    String? title,
    String? description,
    List<String>? recommendations,
    Map<String, dynamic>? metadata,
    bool? isRead,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AIInsight(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// AI insight type enum
enum InsightType {
  sleepPattern('sleep_pattern'),
  healthAlert('health_alert'),
  recommendation('recommendation'),
  milestone('milestone'),
  trend('trend');

  final String value;
  const InsightType(this.value);

  static InsightType fromString(String? value) {
    return InsightType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InsightType.recommendation,
    );
  }

  String get displayName {
    switch (this) {
      case InsightType.sleepPattern:
        return 'Sleep Pattern';
      case InsightType.healthAlert:
        return 'Health Alert';
      case InsightType.recommendation:
        return 'Recommendation';
      case InsightType.milestone:
        return 'Milestone';
      case InsightType.trend:
        return 'Trend';
    }
  }
}

/// AI insight priority enum
enum InsightPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const InsightPriority(this.value);

  static InsightPriority fromString(String? value) {
    return InsightPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InsightPriority.low,
    );
  }
}

/// Daily AI summary model
class AIDailySummary {
  final String id;
  final String babyId;
  final DateTime date;
  final String summary;
  final Map<String, dynamic> metrics;
  final List<String> highlights;
  final List<String> concerns;
  final DateTime createdAt;

  AIDailySummary({
    required this.id,
    required this.babyId,
    required this.date,
    required this.summary,
    this.metrics = const {},
    this.highlights = const [],
    this.concerns = const [],
    required this.createdAt,
  });

  factory AIDailySummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIDailySummary(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: data['summary'] ?? '',
      metrics: Map<String, dynamic>.from(data['metrics'] ?? {}),
      highlights: List<String>.from(data['highlights'] ?? []),
      concerns: List<String>.from(data['concerns'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'date': Timestamp.fromDate(date),
      'summary': summary,
      'metrics': metrics,
      'highlights': highlights,
      'concerns': concerns,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
