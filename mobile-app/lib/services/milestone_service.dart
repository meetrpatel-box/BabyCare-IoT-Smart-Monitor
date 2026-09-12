import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/milestone_model.dart';

/// Service for managing baby milestones
///
/// Handles:
/// - CRUD operations for milestones
/// - Auto-detection from data patterns
/// - Real-time streaming
/// - Celebration triggers
class MilestoneService {
  final FirebaseFirestore _firestore;

  MilestoneService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for milestones subcollection
  CollectionReference<Map<String, dynamic>> _milestonesCollection(
      String babyId) {
    return _firestore.collection('babies').doc(babyId).collection('milestones');
  }

  // ============================================================
  // CREATE OPERATIONS
  // ============================================================

  /// Create a new milestone
  Future<MilestoneModel> createMilestone({
    required String babyId,
    required String title,
    String? description,
    required MilestoneCategory category,
    DateTime? achievedDate,
    int? ageInMonths,
    List<String>? photoUrls,
    String? notes,
  }) async {
    try {
      final milestoneDoc = _milestonesCollection(babyId).doc();
      final now = DateTime.now();

      final milestone = MilestoneModel(
        id: milestoneDoc.id,
        babyId: babyId,
        title: title,
        description: description,
        category: category,
        achievedDate: achievedDate ?? now,
        ageInMonths: ageInMonths ?? 0,
        photoUrls: photoUrls ?? [],
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await milestoneDoc.set(milestone.toFirestore());

      debugPrint('MilestoneService: Created milestone ${milestone.id}');

      return milestone;
    } catch (e) {
      debugPrint('MilestoneService: Create failed: $e');
      throw MilestoneServiceException('Failed to create milestone: $e');
    }
  }

  // ============================================================
  // READ OPERATIONS
  // ============================================================

  /// Get a single milestone by ID
  Future<MilestoneModel?> getMilestone(
      String babyId, String milestoneId) async {
    try {
      final doc = await _milestonesCollection(babyId).doc(milestoneId).get();
      if (!doc.exists) return null;
      return MilestoneModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('MilestoneService: Get milestone failed: $e');
      return null;
    }
  }

  /// Stream milestones for a baby (real-time updates)
  Stream<List<MilestoneModel>> streamMilestones(
    String babyId, {
    MilestoneCategory? category,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _milestonesCollection(babyId);

    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }

    query = query.orderBy('achievedDate', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MilestoneModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get milestones with pagination
  Future<List<MilestoneModel>> getMilestones(
    String babyId, {
    MilestoneCategory? category,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _milestonesCollection(babyId);

    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }

    query = query.orderBy('achievedDate', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MilestoneModel.fromFirestore(doc))
        .toList();
  }

  /// Get milestones by date range
  Future<List<MilestoneModel>> getMilestonesForDateRange(
    String babyId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _milestonesCollection(babyId)
        .where('achievedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('achievedDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('achievedDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MilestoneModel.fromFirestore(doc))
        .toList();
  }

  /// Get milestone count
  Future<int> getMilestoneCount(String babyId) async {
    final snapshot = await _milestonesCollection(babyId).count().get();
    return snapshot.count ?? 0;
  }

  /// Get milestones by category count
  Future<Map<MilestoneCategory, int>> getMilestoneCountByCategory(
      String babyId) async {
    final counts = <MilestoneCategory, int>{};

    for (final category in MilestoneCategory.values) {
      final snapshot = await _milestonesCollection(babyId)
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

  /// Update milestone
  Future<void> updateMilestone(
    String babyId,
    String milestoneId, {
    String? title,
    String? description,
    MilestoneCategory? category,
    DateTime? achievedDate,
    int? ageInMonths,
    List<String>? photoUrls,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category.value;
    if (achievedDate != null)
      updates['achievedDate'] = Timestamp.fromDate(achievedDate);
    if (ageInMonths != null) updates['ageInMonths'] = ageInMonths;
    if (photoUrls != null) updates['photoUrls'] = photoUrls;
    if (notes != null) updates['notes'] = notes;

    if (updates.length == 1) return; // Only updatedAt, no changes

    await _milestonesCollection(babyId).doc(milestoneId).update(updates);
    debugPrint('MilestoneService: Updated milestone $milestoneId');
  }

  /// Add photo to milestone
  Future<void> addPhotoToMilestone(
    String babyId,
    String milestoneId,
    String photoUrl,
  ) async {
    await _milestonesCollection(babyId).doc(milestoneId).update({
      'photoUrls': FieldValue.arrayUnion([photoUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove photo from milestone
  Future<void> removePhotoFromMilestone(
    String babyId,
    String milestoneId,
    String photoUrl,
  ) async {
    await _milestonesCollection(babyId).doc(milestoneId).update({
      'photoUrls': FieldValue.arrayRemove([photoUrl]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE OPERATIONS
  // ============================================================

  /// Delete milestone
  Future<void> deleteMilestone(String babyId, String milestoneId) async {
    await _milestonesCollection(babyId).doc(milestoneId).delete();
    debugPrint('MilestoneService: Deleted milestone $milestoneId');
  }

  // ============================================================
  // AUTO-DETECTION OPERATIONS
  // ============================================================

  /// Check for milestone achievements based on data patterns
  ///
  /// This is called when new data is added (sleep, vitals, etc.)
  /// to detect if any milestones have been achieved
  Future<List<MilestoneModel>> detectMilestones(
    String babyId,
    Map<String, dynamic> recentData,
  ) async {
    final detectedMilestones = <MilestoneModel>[];

    // Get baby's date of birth to calculate age
    final babyDoc = await _firestore.collection('babies').doc(babyId).get();
    if (!babyDoc.exists) return detectedMilestones;

    final dob = (babyDoc.data()?['dateOfBirth'] as Timestamp?)?.toDate();
    if (dob == null) return detectedMilestones;

    final ageInMonths = DateTime.now().difference(dob).inDays ~/ 30;

    // Example: First 6-hour sleep
    if (recentData['sleepDuration'] != null) {
      final sleepHours = (recentData['sleepDuration'] as num) / 60;
      if (sleepHours >= 6) {
        final existing = await _milestonesCollection(babyId)
            .where('title', isEqualTo: 'First 6-Hour Sleep')
            .get();

        if (existing.docs.isEmpty) {
          final milestone = await createMilestone(
            babyId: babyId,
            title: 'First 6-Hour Sleep',
            description:
                'Baby slept for 6 consecutive hours for the first time!',
            category: MilestoneCategory.sleep,
            ageInMonths: ageInMonths,
            notes:
                'Auto-detected: Sleep duration ${sleepHours.toStringAsFixed(1)} hours',
          );
          detectedMilestones.add(milestone);
        }
      }
    }

    // Example: First full week of good sleep (sleep score > 85)
    if (recentData['weeklyAvgSleepScore'] != null) {
      final avgScore = recentData['weeklyAvgSleepScore'] as num;
      if (avgScore >= 85) {
        final existing = await _milestonesCollection(babyId)
            .where('title', isEqualTo: 'First Week of Great Sleep')
            .get();

        if (existing.docs.isEmpty) {
          final milestone = await createMilestone(
            babyId: babyId,
            title: 'First Week of Great Sleep',
            description:
                'Baby maintained excellent sleep quality for a full week!',
            category: MilestoneCategory.sleep,
            ageInMonths: ageInMonths,
            notes: 'Auto-detected: Weekly avg sleep score $avgScore',
          );
          detectedMilestones.add(milestone);
        }
      }
    }

    // Example: 100 days old
    final ageInDays = DateTime.now().difference(dob).inDays;
    if (ageInDays == 100) {
      final existing = await _milestonesCollection(babyId)
          .where('title', isEqualTo: '100 Days Old')
          .get();

      if (existing.docs.isEmpty) {
        final milestone = await createMilestone(
          babyId: babyId,
          title: '100 Days Old',
          description: 'Baby reached the 100-day milestone!',
          category: MilestoneCategory.other,
          ageInMonths: ageInMonths,
        );
        detectedMilestones.add(milestone);
      }
    }

    // Example: Stable temperature for 30 days
    if (recentData['stableTemperatureDays'] != null) {
      final stableDays = recentData['stableTemperatureDays'] as int;
      if (stableDays >= 30) {
        final existing = await _milestonesCollection(babyId)
            .where('title', isEqualTo: '30 Days of Healthy Temperature')
            .get();

        if (existing.docs.isEmpty) {
          final milestone = await createMilestone(
            babyId: babyId,
            title: '30 Days of Healthy Temperature',
            description:
                'Baby maintained healthy temperature range for 30 consecutive days!',
            category: MilestoneCategory.other,
            ageInMonths: ageInMonths,
            notes: 'Auto-detected: $stableDays stable days',
          );
          detectedMilestones.add(milestone);
        }
      }
    }

    // TODO: Add more detection patterns:
    // - First sleeping through the night (8+ hours)
    // - First full week without crying at night
    // - Consistent sleep schedule (30 days)
    // - Weight/height percentile achievements
    // - etc.

    return detectedMilestones;
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Get milestone statistics for a baby
  Future<Map<String, dynamic>> getMilestoneStats(String babyId) async {
    final milestones = await getMilestones(babyId, limit: 1000);

    final categoryBreakdown = <MilestoneCategory, int>{};
    for (final category in MilestoneCategory.values) {
      categoryBreakdown[category] =
          milestones.where((m) => m.category == category).length;
    }

    // Group by month
    final byMonth = <int, int>{};
    for (final milestone in milestones) {
      final month = milestone.ageInMonths;
      byMonth[month] = (byMonth[month] ?? 0) + 1;
    }

    // Recent milestones (last 30 days)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentCount =
        milestones.where((m) => m.achievedDate.isAfter(thirtyDaysAgo)).length;

    return {
      'totalMilestones': milestones.length,
      'categoryBreakdown':
          categoryBreakdown.map((k, v) => MapEntry(k.value, v)),
      'byMonth': byMonth,
      'recentCount': recentCount,
      'mostRecentMilestone':
          milestones.isNotEmpty ? milestones.first.toFirestore() : null,
    };
  }
}

/// Exception for MilestoneService errors
class MilestoneServiceException implements Exception {
  final String message;
  MilestoneServiceException(this.message);

  @override
  String toString() => 'MilestoneServiceException: $message';
}
