import 'package:cloud_firestore/cloud_firestore.dart';

/// Parenting tip model - AI-generated or curated tips for parents
/// Age-appropriate advice, safety tips, developmental guidance
class TipModel {
  final String id;
  final String title;
  final String content;
  final TipCategory category;
  final int minAgeMonths;
  final int maxAgeMonths;
  final TipPriority priority;
  final List<String> tags;
  final String? sourceUrl;
  final String? imageUrl;
  final bool isAiGenerated;
  final DateTime createdAt;
  final DateTime updatedAt;

  TipModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.minAgeMonths,
    required this.maxAgeMonths,
    this.priority = TipPriority.normal,
    this.tags = const [],
    this.sourceUrl,
    this.imageUrl,
    this.isAiGenerated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if tip is relevant for a specific age in months
  bool isRelevantForAge(int ageInMonths) {
    return ageInMonths >= minAgeMonths && ageInMonths <= maxAgeMonths;
  }

  factory TipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TipModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: TipCategoryExtension.fromString(data['category'] ?? 'general'),
      minAgeMonths: data['minAgeMonths'] ?? 0,
      maxAgeMonths: data['maxAgeMonths'] ?? 120, // 10 years default
      priority: TipPriorityExtension.fromString(data['priority'] ?? 'normal'),
      tags: List<String>.from(data['tags'] ?? []),
      sourceUrl: data['sourceUrl'],
      imageUrl: data['imageUrl'],
      isAiGenerated: data['isAiGenerated'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'category': category.value,
      'minAgeMonths': minAgeMonths,
      'maxAgeMonths': maxAgeMonths,
      'priority': priority.value,
      'tags': tags,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'isAiGenerated': isAiGenerated,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TipModel copyWith({
    String? id,
    String? title,
    String? content,
    TipCategory? category,
    int? minAgeMonths,
    int? maxAgeMonths,
    TipPriority? priority,
    List<String>? tags,
    String? sourceUrl,
    String? imageUrl,
    bool? isAiGenerated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TipModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      minAgeMonths: minAgeMonths ?? this.minAgeMonths,
      maxAgeMonths: maxAgeMonths ?? this.maxAgeMonths,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TipModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ category.hashCode;

  @override
  String toString() {
    return 'TipModel(id: $id, title: $title, category: ${category.value}, '
        'ageRange: $minAgeMonths-$maxAgeMonths months, priority: ${priority.value})';
  }
}

/// Categories for parenting tips
enum TipCategory {
  sleep, // Sleep training, schedules, routines
  feeding, // Nutrition, bottle feeding, breastfeeding, solids
  health, // Medical advice, symptoms to watch, immunizations
  safety, // Baby-proofing, car seats, safe sleep
  development, // Milestones, activities, stimulation
  behavior, // Crying, tantrums, discipline
  care, // Bathing, diaper changes, clothing
  bonding, // Attachment, playtime, communication
  general, // Miscellaneous advice
}

extension TipCategoryExtension on TipCategory {
  String get value {
    switch (this) {
      case TipCategory.sleep:
        return 'sleep';
      case TipCategory.feeding:
        return 'feeding';
      case TipCategory.health:
        return 'health';
      case TipCategory.safety:
        return 'safety';
      case TipCategory.development:
        return 'development';
      case TipCategory.behavior:
        return 'behavior';
      case TipCategory.care:
        return 'care';
      case TipCategory.bonding:
        return 'bonding';
      case TipCategory.general:
        return 'general';
    }
  }

  String get displayName {
    switch (this) {
      case TipCategory.sleep:
        return 'Sleep';
      case TipCategory.feeding:
        return 'Feeding';
      case TipCategory.health:
        return 'Health';
      case TipCategory.safety:
        return 'Safety';
      case TipCategory.development:
        return 'Development';
      case TipCategory.behavior:
        return 'Behavior';
      case TipCategory.care:
        return 'Care';
      case TipCategory.bonding:
        return 'Bonding';
      case TipCategory.general:
        return 'General';
    }
  }

  String get icon {
    switch (this) {
      case TipCategory.sleep:
        return '😴';
      case TipCategory.feeding:
        return '🍼';
      case TipCategory.health:
        return '🏥';
      case TipCategory.safety:
        return '🛡️';
      case TipCategory.development:
        return '📈';
      case TipCategory.behavior:
        return '🧸';
      case TipCategory.care:
        return '🛁';
      case TipCategory.bonding:
        return '💝';
      case TipCategory.general:
        return '💡';
    }
  }

  static TipCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sleep':
        return TipCategory.sleep;
      case 'feeding':
        return TipCategory.feeding;
      case 'health':
        return TipCategory.health;
      case 'safety':
        return TipCategory.safety;
      case 'development':
        return TipCategory.development;
      case 'behavior':
        return TipCategory.behavior;
      case 'care':
        return TipCategory.care;
      case 'bonding':
        return TipCategory.bonding;
      default:
        return TipCategory.general;
    }
  }
}

/// Priority level for tips
enum TipPriority {
  low, // Nice to know
  normal, // Standard tip
  high, // Important information
  urgent, // Critical safety or health information
}

extension TipPriorityExtension on TipPriority {
  String get value {
    switch (this) {
      case TipPriority.low:
        return 'low';
      case TipPriority.normal:
        return 'normal';
      case TipPriority.high:
        return 'high';
      case TipPriority.urgent:
        return 'urgent';
    }
  }

  String get displayName {
    switch (this) {
      case TipPriority.low:
        return 'Low';
      case TipPriority.normal:
        return 'Normal';
      case TipPriority.high:
        return 'High';
      case TipPriority.urgent:
        return 'Urgent';
    }
  }

  static TipPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return TipPriority.low;
      case 'normal':
        return TipPriority.normal;
      case 'high':
        return TipPriority.high;
      case 'urgent':
        return TipPriority.urgent;
      default:
        return TipPriority.normal;
    }
  }
}
