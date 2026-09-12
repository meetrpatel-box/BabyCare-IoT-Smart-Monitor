import 'package:cloud_firestore/cloud_firestore.dart';

/// Developmental milestone model for tracking baby achievements
/// Examples: first smile, rolled over, first word, first step
class MilestoneModel {
  final String id;
  final String babyId;
  final String title;
  final String? description;
  final MilestoneCategory category;
  final DateTime achievedDate;
  final int ageInMonths;
  final List<String> photoUrls;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MilestoneModel({
    required this.id,
    required this.babyId,
    required this.title,
    this.description,
    required this.category,
    required this.achievedDate,
    required this.ageInMonths,
    this.photoUrls = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MilestoneModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneModel(
      id: doc.id,
      babyId: data['babyId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      category: MilestoneCategoryExtension.fromString(
        data['category'] ?? 'other',
      ),
      achievedDate:
          (data['achievedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ageInMonths: data['ageInMonths'] ?? 0,
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'babyId': babyId,
      'title': title,
      'description': description,
      'category': category.value,
      'achievedDate': Timestamp.fromDate(achievedDate),
      'ageInMonths': ageInMonths,
      'photoUrls': photoUrls,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MilestoneModel copyWith({
    String? id,
    String? babyId,
    String? title,
    String? description,
    MilestoneCategory? category,
    DateTime? achievedDate,
    int? ageInMonths,
    List<String>? photoUrls,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MilestoneModel(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      achievedDate: achievedDate ?? this.achievedDate,
      ageInMonths: ageInMonths ?? this.ageInMonths,
      photoUrls: photoUrls ?? this.photoUrls,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          babyId == other.babyId &&
          title == other.title &&
          category == other.category;

  @override
  int get hashCode =>
      id.hashCode ^ babyId.hashCode ^ title.hashCode ^ category.hashCode;

  @override
  String toString() {
    return 'MilestoneModel(id: $id, babyId: $babyId, title: $title, '
        'category: ${category.value}, achievedDate: $achievedDate, '
        'ageInMonths: $ageInMonths)';
  }
}

/// Categories for developmental milestones
enum MilestoneCategory {
  physical, // Rolling over, crawling, walking
  cognitive, // Object permanence, problem solving
  language, // First words, babbling, sentences
  social, // Smiling, waving, playing with others
  emotional, // Self-soothing, expressing emotions
  feeding, // Solid foods, self-feeding, drinking from cup
  sleep, // Sleeping through night, nap transitions
  other, // Custom milestones
}

extension MilestoneCategoryExtension on MilestoneCategory {
  String get value {
    switch (this) {
      case MilestoneCategory.physical:
        return 'physical';
      case MilestoneCategory.cognitive:
        return 'cognitive';
      case MilestoneCategory.language:
        return 'language';
      case MilestoneCategory.social:
        return 'social';
      case MilestoneCategory.emotional:
        return 'emotional';
      case MilestoneCategory.feeding:
        return 'feeding';
      case MilestoneCategory.sleep:
        return 'sleep';
      case MilestoneCategory.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case MilestoneCategory.physical:
        return 'Physical';
      case MilestoneCategory.cognitive:
        return 'Cognitive';
      case MilestoneCategory.language:
        return 'Language';
      case MilestoneCategory.social:
        return 'Social';
      case MilestoneCategory.emotional:
        return 'Emotional';
      case MilestoneCategory.feeding:
        return 'Feeding';
      case MilestoneCategory.sleep:
        return 'Sleep';
      case MilestoneCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case MilestoneCategory.physical:
        return '🏃';
      case MilestoneCategory.cognitive:
        return '🧠';
      case MilestoneCategory.language:
        return '💬';
      case MilestoneCategory.social:
        return '👥';
      case MilestoneCategory.emotional:
        return '❤️';
      case MilestoneCategory.feeding:
        return '🍼';
      case MilestoneCategory.sleep:
        return '😴';
      case MilestoneCategory.other:
        return '⭐';
    }
  }

  static MilestoneCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'physical':
        return MilestoneCategory.physical;
      case 'cognitive':
        return MilestoneCategory.cognitive;
      case 'language':
        return MilestoneCategory.language;
      case 'social':
        return MilestoneCategory.social;
      case 'emotional':
        return MilestoneCategory.emotional;
      case 'feeding':
        return MilestoneCategory.feeding;
      case 'sleep':
        return MilestoneCategory.sleep;
      default:
        return MilestoneCategory.other;
    }
  }
}
