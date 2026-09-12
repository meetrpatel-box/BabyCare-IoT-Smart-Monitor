import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_insight_model.dart';

/// AI insights service for health recommendations
/// Ported from React Native aiInsightsService.ts
class AIInsightsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate AI insights for baby (triggers cloud function)
  Future<void> generateAIInsights(String babyId) async {
    // Create a request document that triggers the cloud function
    await _firestore.collection('aiInsightRequests').add({
      'babyId': babyId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Get AI insights for baby
  Future<List<AIInsight>> getAIInsights(
    String babyId, {
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    Query query = _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (unreadOnly) {
      query = query.where('isRead', isEqualTo: false);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => AIInsight.fromFirestore(doc))
        .where((insight) => !insight.isExpired)
        .toList();
  }

  /// Get high priority insights
  Future<List<AIInsight>> getHighPriorityInsights(String babyId) async {
    final snapshot = await _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .where('priority', whereIn: ['high', 'critical'])
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => AIInsight.fromFirestore(doc))
        .where((insight) => !insight.isExpired)
        .toList();
  }

  /// Get insights by type
  Future<List<AIInsight>> getInsightsByType(
    String babyId,
    InsightType type, {
    int limit = 10,
  }) async {
    final snapshot = await _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .where('type', isEqualTo: type.value)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => AIInsight.fromFirestore(doc)).toList();
  }

  /// Mark insight as read
  Future<void> markInsightAsRead(String insightId) async {
    await _firestore.collection('aiInsights').doc(insightId).update({
      'isRead': true,
    });
  }

  /// Mark all insights as read for baby
  Future<void> markAllInsightsAsRead(String babyId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Get unread insight count
  Future<int> getUnreadInsightCount(String babyId) async {
    final snapshot = await _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Subscribe to insights
  Stream<List<AIInsight>> subscribeToInsights(String babyId) {
    return _firestore
        .collection('aiInsights')
        .where('babyId', isEqualTo: babyId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AIInsight.fromFirestore(doc))
            .where((insight) => !insight.isExpired)
            .toList());
  }

  // ==================== Daily Summaries ====================

  /// Get daily summary for date
  Future<AIDailySummary?> getDailySummary(String babyId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('aiDailySummaries')
        .where('babyId', isEqualTo: babyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AIDailySummary.fromFirestore(snapshot.docs.first);
  }

  /// Get recent daily summaries
  Future<List<AIDailySummary>> getRecentDailySummaries(
    String babyId, {
    int days = 7,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days));

    final snapshot = await _firestore
        .collection('aiDailySummaries')
        .where('babyId', isEqualTo: babyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AIDailySummary.fromFirestore(doc))
        .toList();
  }

  /// Subscribe to daily summaries
  Stream<List<AIDailySummary>> subscribeToDailySummaries(
    String babyId, {
    int days = 7,
  }) {
    final startDate = DateTime.now().subtract(Duration(days: days));

    return _firestore
        .collection('aiDailySummaries')
        .where('babyId', isEqualTo: babyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AIDailySummary.fromFirestore(doc))
            .toList());
  }
}
