import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/tip_model.dart';

/// Service for managing parenting tips and recommendations
///
/// Handles:
/// - CRUD operations for tips
/// - Age-based filtering and recommendations
/// - Real-time streaming
/// - User feedback and effectiveness tracking
/// - Tip seeding and content management
class TipService {
  final FirebaseFirestore _firestore;

  TipService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for tips
  CollectionReference<Map<String, dynamic>> get _tipsCollection {
    return _firestore.collection('tips');
  }

  // ============================================================
  // CREATE OPERATIONS
  // ============================================================

  /// Create a new tip
  Future<TipModel> createTip({
    required String title,
    required String content,
    required TipCategory category,
    required int minAgeMonths,
    required int maxAgeMonths,
    TipPriority priority = TipPriority.normal,
    List<String> tags = const [],
    String? sourceUrl,
    String? imageUrl,
    bool isAiGenerated = false,
  }) async {
    try {
      final tipDoc = _tipsCollection.doc();
      final now = DateTime.now();

      final tip = TipModel(
        id: tipDoc.id,
        title: title,
        content: content,
        category: category,
        minAgeMonths: minAgeMonths,
        maxAgeMonths: maxAgeMonths,
        priority: priority,
        tags: tags,
        sourceUrl: sourceUrl,
        imageUrl: imageUrl,
        isAiGenerated: isAiGenerated,
        createdAt: now,
        updatedAt: now,
      );

      await tipDoc.set(tip.toFirestore());

      debugPrint('TipService: Created tip ${tip.id}');

      return tip;
    } catch (e) {
      debugPrint('TipService: Create failed: $e');
      throw TipServiceException('Failed to create tip: $e');
    }
  }

  /// Seed initial tips database
  Future<void> seedTips(List<Map<String, dynamic>> tipData) async {
    try {
      final batch = _firestore.batch();

      for (final data in tipData) {
        final docRef = _tipsCollection.doc();
        final now = DateTime.now();

        final tip = TipModel(
          id: docRef.id,
          title: data['title'],
          content: data['content'],
          category: TipCategoryExtension.fromString(data['category']),
          minAgeMonths: data['minAgeMonths'],
          maxAgeMonths: data['maxAgeMonths'],
          priority:
              TipPriorityExtension.fromString(data['priority'] ?? 'normal'),
          tags: List<String>.from(data['tags'] ?? []),
          sourceUrl: data['sourceUrl'],
          imageUrl: data['imageUrl'],
          isAiGenerated: data['isAiGenerated'] ?? false,
          createdAt: now,
          updatedAt: now,
        );

        batch.set(docRef, tip.toFirestore());
      }

      await batch.commit();
      debugPrint('TipService: Seeded ${tipData.length} tips');
    } catch (e) {
      debugPrint('TipService: Seed failed: $e');
      throw TipServiceException('Failed to seed tips: $e');
    }
  }

  // ============================================================
  // READ OPERATIONS
  // ============================================================

  /// Get a single tip by ID
  Future<TipModel?> getTip(String tipId) async {
    try {
      final doc = await _tipsCollection.doc(tipId).get();
      if (!doc.exists) return null;
      return TipModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('TipService: Get tip failed: $e');
      return null;
    }
  }

  /// Get tips for a specific age range
  Future<List<TipModel>> getTipsForAge(
    int ageInMonths, {
    TipCategory? category,
    TipPriority? minPriority,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _tipsCollection;

      // Filter by category
      if (category != null) {
        query = query.where('category', isEqualTo: category.value);
      }

      // Filter by age range
      // Get tips where minAgeMonths <= ageInMonths <= maxAgeMonths
      query = query
          .where('minAgeMonths', isLessThanOrEqualTo: ageInMonths)
          .orderBy('minAgeMonths')
          .orderBy('priority', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      final allTips =
          snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();

      // Filter tips that are relevant for the current age
      final relevantTips =
          allTips.where((tip) => tip.isRelevantForAge(ageInMonths)).toList();

      // Further filter by priority if specified
      if (minPriority != null) {
        final minPriorityIndex = TipPriority.values.indexOf(minPriority);
        return relevantTips
            .where((tip) =>
                TipPriority.values.indexOf(tip.priority) >= minPriorityIndex)
            .toList();
      }

      return relevantTips;
    } catch (e) {
      debugPrint('TipService: Get tips for age failed: $e');
      return [];
    }
  }

  /// Get recommended tips for a baby based on age and recent data
  Future<List<TipModel>> getRecommendedTips(
    String babyId,
    int ageInMonths, {
    Map<String, dynamic>? recentData,
    int limit = 10,
  }) async {
    try {
      // Start with age-appropriate tips
      final ageTips = await getTipsForAge(ageInMonths, limit: 100);

      // Score and rank tips based on relevance
      final scoredTips = ageTips.map((tip) {
        double score = 0.0;

        // Priority scoring
        switch (tip.priority) {
          case TipPriority.urgent:
            score += 100.0;
            break;
          case TipPriority.high:
            score += 50.0;
            break;
          case TipPriority.normal:
            score += 10.0;
            break;
          case TipPriority.low:
            score += 5.0;
            break;
        }

        // Relevance scoring based on recent data
        if (recentData != null) {
          // Sleep-related scoring
          if (tip.category == TipCategory.sleep &&
              recentData['avgSleepScore'] != null) {
            final sleepScore = recentData['avgSleepScore'] as num;
            if (sleepScore < 70) {
              score += 30.0; // Boost sleep tips if sleep quality is poor
            }
          }

          // Feeding-related scoring
          if (tip.category == TipCategory.feeding &&
              recentData['feedingIssues'] != null) {
            score += 25.0;
          }

          // Health-related scoring
          if (tip.category == TipCategory.health &&
              recentData['abnormalVitals'] != null) {
            score += 40.0;
          }

          // Development-related scoring
          if (tip.category == TipCategory.development &&
              recentData['missedMilestones'] != null) {
            score += 35.0;
          }
        }

        // Age precision bonus (tips closer to exact age)
        final ageRange = tip.maxAgeMonths - tip.minAgeMonths;
        final agePrecision = 1.0 / (ageRange + 1);
        score += agePrecision * 20.0;

        return MapEntry(tip, score);
      }).toList();

      // Sort by score descending
      scoredTips.sort((a, b) => b.value.compareTo(a.value));

      // Return top N tips
      return scoredTips.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('TipService: Get recommended tips failed: $e');
      return [];
    }
  }

  /// Stream tips (real-time updates)
  Stream<List<TipModel>> streamTips({
    TipCategory? category,
    int? ageInMonths,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _tipsCollection;

    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }

    if (ageInMonths != null) {
      query = query
          .where('minAgeMonths', isLessThanOrEqualTo: ageInMonths)
          .orderBy('minAgeMonths')
          .orderBy('priority', descending: true);
    } else {
      query = query.orderBy('priority', descending: true);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final allTips =
          snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();

      // Filter by age if specified
      if (ageInMonths != null) {
        return allTips
            .where((tip) => tip.isRelevantForAge(ageInMonths))
            .toList();
      }

      return allTips;
    });
  }

  /// Get tips by category
  Future<List<TipModel>> getTipsByCategory(
    TipCategory category, {
    int limit = 50,
  }) async {
    final snapshot = await _tipsCollection
        .where('category', isEqualTo: category.value)
        .orderBy('priority', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();
  }

  /// Get tips by priority
  Future<List<TipModel>> getTipsByPriority(
    TipPriority priority, {
    int limit = 50,
  }) async {
    final snapshot = await _tipsCollection
        .where('priority', isEqualTo: priority.value)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();
  }

  /// Get urgent tips
  Future<List<TipModel>> getUrgentTips({int limit = 20}) async {
    return getTipsByPriority(TipPriority.urgent, limit: limit);
  }

  /// Search tips by tags
  Future<List<TipModel>> searchByTags(
    List<String> tags, {
    int limit = 50,
  }) async {
    final snapshot = await _tipsCollection
        .where('tags', arrayContainsAny: tags)
        .orderBy('priority', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();
  }

  /// Get tip count
  Future<int> getTipCount() async {
    final snapshot = await _tipsCollection.count().get();
    return snapshot.count ?? 0;
  }

  /// Get tip count by category
  Future<Map<TipCategory, int>> getTipCountByCategory() async {
    final counts = <TipCategory, int>{};

    for (final category in TipCategory.values) {
      final snapshot = await _tipsCollection
          .where('category', isEqualTo: category.value)
          .count()
          .get();
      counts[category] = snapshot.count ?? 0;
    }

    return counts;
  }

  // ============================================================
  // UPDATE OPERATIONS
  // ============================================================

  /// Update tip
  Future<void> updateTip(
    String tipId, {
    String? title,
    String? content,
    TipCategory? category,
    int? minAgeMonths,
    int? maxAgeMonths,
    TipPriority? priority,
    List<String>? tags,
    String? sourceUrl,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (category != null) updates['category'] = category.value;
    if (minAgeMonths != null) updates['minAgeMonths'] = minAgeMonths;
    if (maxAgeMonths != null) updates['maxAgeMonths'] = maxAgeMonths;
    if (priority != null) updates['priority'] = priority.value;
    if (tags != null) updates['tags'] = tags;
    if (sourceUrl != null) updates['sourceUrl'] = sourceUrl;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;

    if (updates.length == 1) return; // Only updatedAt, no changes

    await _tipsCollection.doc(tipId).update(updates);
    debugPrint('TipService: Updated tip $tipId');
  }

  // ============================================================
  // DELETE OPERATIONS
  // ============================================================

  /// Delete tip
  Future<void> deleteTip(String tipId) async {
    await _tipsCollection.doc(tipId).delete();
    debugPrint('TipService: Deleted tip $tipId');
  }

  // ============================================================
  // USER FEEDBACK OPERATIONS
  // ============================================================

  /// Record tip feedback (helpful/not helpful)
  Future<void> recordFeedback(
    String tipId,
    String userId, {
    required bool isHelpful,
    String? comment,
  }) async {
    try {
      await _tipsCollection.doc(tipId).collection('feedback').add({
        'userId': userId,
        'isHelpful': isHelpful,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('TipService: Recorded feedback for tip $tipId');
    } catch (e) {
      debugPrint('TipService: Record feedback failed: $e');
    }
  }

  /// Get tip effectiveness (helpfulness ratio)
  Future<double> getTipEffectiveness(String tipId) async {
    try {
      final feedbackSnapshot =
          await _tipsCollection.doc(tipId).collection('feedback').get();

      if (feedbackSnapshot.docs.isEmpty) return 0.0;

      final helpfulCount = feedbackSnapshot.docs
          .where((doc) => doc.data()['isHelpful'] == true)
          .length;

      return helpfulCount / feedbackSnapshot.docs.length;
    } catch (e) {
      debugPrint('TipService: Get effectiveness failed: $e');
      return 0.0;
    }
  }

  /// Get feedback stats for a tip
  Future<Map<String, dynamic>> getFeedbackStats(String tipId) async {
    try {
      final feedbackSnapshot =
          await _tipsCollection.doc(tipId).collection('feedback').get();

      final totalFeedback = feedbackSnapshot.docs.length;
      final helpfulCount = feedbackSnapshot.docs
          .where((doc) => doc.data()['isHelpful'] == true)
          .length;
      final notHelpfulCount = totalFeedback - helpfulCount;

      return {
        'totalFeedback': totalFeedback,
        'helpfulCount': helpfulCount,
        'notHelpfulCount': notHelpfulCount,
        'helpfulRatio': totalFeedback > 0 ? helpfulCount / totalFeedback : 0.0,
      };
    } catch (e) {
      debugPrint('TipService: Get feedback stats failed: $e');
      return {
        'totalFeedback': 0,
        'helpfulCount': 0,
        'notHelpfulCount': 0,
        'helpfulRatio': 0.0,
      };
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Get tip statistics
  Future<Map<String, dynamic>> getTipStats() async {
    try {
      final totalCount = await getTipCount();
      final categoryBreakdown = await getTipCountByCategory();

      // Priority breakdown
      final priorityBreakdown = <TipPriority, int>{};
      for (final priority in TipPriority.values) {
        final snapshot = await _tipsCollection
            .where('priority', isEqualTo: priority.value)
            .count()
            .get();
        priorityBreakdown[priority] = snapshot.count ?? 0;
      }

      // AI vs curated
      final aiGeneratedSnapshot = await _tipsCollection
          .where('isAiGenerated', isEqualTo: true)
          .count()
          .get();
      final aiGeneratedCount = aiGeneratedSnapshot.count ?? 0;
      final curatedCount = totalCount - aiGeneratedCount;

      return {
        'totalTips': totalCount,
        'categoryBreakdown':
            categoryBreakdown.map((k, v) => MapEntry(k.value, v)),
        'priorityBreakdown':
            priorityBreakdown.map((k, v) => MapEntry(k.value, v)),
        'aiGeneratedCount': aiGeneratedCount,
        'curatedCount': curatedCount,
      };
    } catch (e) {
      debugPrint('TipService: Get stats failed: $e');
      return {
        'totalTips': 0,
        'categoryBreakdown': {},
        'priorityBreakdown': {},
        'aiGeneratedCount': 0,
        'curatedCount': 0,
      };
    }
  }

  /// Get most effective tips
  Future<List<TipModel>> getMostEffectiveTips({int limit = 10}) async {
    try {
      final allTips = await _tipsCollection.limit(100).get();
      final tipsWithEffectiveness = <MapEntry<TipModel, double>>[];

      for (final doc in allTips.docs) {
        final tip = TipModel.fromFirestore(doc);
        final effectiveness = await getTipEffectiveness(tip.id);
        tipsWithEffectiveness.add(MapEntry(tip, effectiveness));
      }

      // Sort by effectiveness descending
      tipsWithEffectiveness.sort((a, b) => b.value.compareTo(a.value));

      return tipsWithEffectiveness.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('TipService: Get most effective tips failed: $e');
      return [];
    }
  }
}

/// Exception for TipService errors
class TipServiceException implements Exception {
  final String message;
  TipServiceException(this.message);

  @override
  String toString() => 'TipServiceException: $message';
}
