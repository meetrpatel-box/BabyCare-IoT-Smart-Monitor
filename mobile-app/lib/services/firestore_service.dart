import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Firestore service for data operations
/// Ported from React Native firestoreService.ts
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Expose Firestore instance for direct queries (temporary until all services are implemented)
  FirebaseFirestore get firestore => _firestore;

  // ==================== User Operations ====================

  /// Get user by ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Set/update user data
  Future<void> setUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Update user preferences
  Future<void> updateUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      'preferences': preferences.toMap(),
    });
  }

  // ==================== Baby Operations ====================

  /// Add a new baby
  Future<String> addBaby(BabyModel baby) async {
    final docRef =
        await _firestore.collection('babies').add(baby.toFirestore());
    return docRef.id;
  }

  /// Link baby to family (add to family's babyIds array)
  Future<void> linkBabyToFamily(String familyId, String babyId) async {
    await _firestore.collection('families').doc(familyId).update({
      'babyIds': FieldValue.arrayUnion([babyId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get baby by ID
  Future<BabyModel?> getBaby(String babyId) async {
    final doc = await _firestore.collection('babies').doc(babyId).get();
    if (!doc.exists) return null;
    return BabyModel.fromFirestore(doc);
  }

  /// Get babies for parent
  Future<List<BabyModel>> getBabiesForParent(String parentId) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .where('parentId', isEqualTo: parentId)
          .orderBy('createdAt', descending: true)
          .get();

      // Filter out invalid babies and log errors
      final babies = <BabyModel>[];
      for (final doc in snapshot.docs) {
        try {
          final baby = BabyModel.fromFirestore(doc);

          // Validate baby data
          if (baby.name.trim().isEmpty) {
            debugPrint('⚠️  Invalid baby: empty name (ID: ${doc.id})');
            continue;
          }

          if (baby.dateOfBirth.isAfter(DateTime.now())) {
            debugPrint('⚠️  Invalid baby: future birth date (ID: ${doc.id})');
            continue;
          }

          babies.add(baby);
        } catch (e) {
          debugPrint('❌ Error parsing baby document ${doc.id}: $e');
          // Skip invalid documents
        }
      }

      debugPrint('✅ Loaded ${babies.length} valid babies for parent $parentId');
      return babies;
    } catch (e) {
      debugPrint('❌ Error loading babies: $e');
      rethrow;
    }
  }

  /// Get babies for family
  Future<List<BabyModel>> getBabiesForFamily(String familyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .where('familyId', isEqualTo: familyId)
        .get()
        .timeout(const Duration(seconds: 8));

    return snapshot.docs.map((doc) => BabyModel.fromFirestore(doc)).toList();
  }

  /// Update baby
  Future<void> updateBaby(String babyId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('babies').doc(babyId).update(data);
  }

  /// Delete baby
  Future<void> deleteBaby(String babyId) async {
    await _firestore.collection('babies').doc(babyId).delete();
  }

  /// Update latest vitals
  Future<void> updateLatestVitals(String babyId, LatestVitals vitals) async {
    await _firestore.collection('babies').doc(babyId).update({
      'latestVitals': vitals.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Subscribe to baby updates
  Stream<BabyModel?> subscribeToBaby(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .snapshots()
        .map((doc) => doc.exists ? BabyModel.fromFirestore(doc) : null);
  }

  // ==================== Sleep Operations ====================

  /// Add sleep session
  Future<String> addSleepSession(SleepSession session) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(session.babyId)
        .collection('sleepSessions')
        .add(session.toFirestore());
    return docRef.id;
  }

  /// Get sleep sessions for date range
  Future<List<SleepSession>> getSleepSessions(
    String babyId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    Query query = _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .orderBy('startTime', descending: true)
        .limit(limit);

    if (startDate != null) {
      query = query.where(
        'startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'startTime',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SleepSession.fromFirestore(doc)).toList();
  }

  /// Update sleep session
  Future<void> updateSleepSession(
    String babyId,
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .doc(sessionId)
        .update(data);
  }

  // ==================== Vital Logs ====================

  /// Add vital log entry
  Future<String> addVitalLog(VitalLog log) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(log.babyId)
        .collection('vitalLogs')
        .add(log.toFirestore());
    return docRef.id;
  }

  /// Get vital logs for date range
  Future<List<VitalLog>> getVitalLogs(
    String babyId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    Query query = _firestore
        .collection('babies')
        .doc(babyId)
        .collection('vitalLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => VitalLog.fromFirestore(doc)).toList();
  }

  // ==================== Cry Events ====================

  /// Add cry event
  Future<String> addCryEvent(CryEvent event) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(event.babyId)
        .collection('cryEvents')
        .add(event.toFirestore());
    return docRef.id;
  }

  /// Get cry events for period
  Future<List<CryEvent>> getCryEventsForPeriod(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => CryEvent.fromFirestore(doc)).toList();
  }

  // ==================== Wetness Events ====================

  /// Add wetness event
  Future<String> addWetnessEvent(WetnessEvent event) async {
    final docRef = await _firestore
        .collection('babies')
        .doc(event.babyId)
        .collection('wetnessEvents')
        .add(event.toFirestore());
    return docRef.id;
  }

  /// Get wetness events for period
  Future<List<WetnessEvent>> getWetnessEventsForPeriod(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('wetnessEvents')
        .where('detectedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('detectedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('detectedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => WetnessEvent.fromFirestore(doc)).toList();
  }

  /// Acknowledge wetness event
  Future<void> acknowledgeWetnessEvent(String babyId, String eventId) async {
    await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('wetnessEvents')
        .doc(eventId)
        .update({
      'acknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }
}
