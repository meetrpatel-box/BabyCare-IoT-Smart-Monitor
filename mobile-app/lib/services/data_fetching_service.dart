import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_model.dart';

/// Service for hybrid data fetching strategy
/// Separates real-time critical data from on-demand historical data
/// to optimize Firestore read costs
class DataFetchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============== REAL-TIME STREAMS ==============
  // These should be always-on for critical data

  /// Subscribe to latest vitals embedded in baby document
  /// This is cheaper than listening to entire vital_signs collection
  /// Updates: Every 10-30 seconds when device sends new data
  Stream<Map<String, dynamic>?> subscribeToLatestVitals(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          return data?['latestVitals'] as Map<String, dynamic>?;
        });
  }

  /// Subscribe to device status for connectivity monitoring
  /// Returns stream of status changes (online/offline/error)
  Stream<String> subscribeToDeviceStatus(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 'offline';
          return doc.data()?['status'] as String? ?? 'offline';
        });
  }

  /// Subscribe to active sleep session (if one is in progress)
  /// Returns null if no active session
  Stream<Map<String, dynamic>?> subscribeToActiveSleepSession(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('sleepSessions')
        .where('endTime', isNull: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return {...doc.data(), 'id': doc.id};
        });
  }

  /// Subscribe to critical alerts (high-priority only)
  /// Use for real-time alert notifications
  Stream<List<Map<String, dynamic>>> subscribeToCriticalAlerts(String babyId) {
    return _firestore
        .collection('babies')
        .doc(babyId)
        .collection('alerts')
        .where('priority', isEqualTo: 'critical')
        .where('acknowledged', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // ============== ON-DEMAND QUERIES ==============
  // These should only be fetched when user navigates to specific screens

  /// Get historical vital logs for a date range
  /// Call when user opens Trends screen or Analytics
  Future<List<Map<String, dynamic>>> getHistoricalVitals({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('vitalLogs')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching historical vitals: $e');
      return [];
    }
  }

  /// Get sleep sessions for last N days
  /// Call when user opens Sleep Analysis screen
  Future<List<Map<String, dynamic>>> getSleepSessions({
    required String babyId,
    int daysBack = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('sleepSessions')
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching sleep sessions: $e');
      return [];
    }
  }

  /// Get cry events for analysis
  /// Call when user opens Cry Pattern Analysis screen
  Future<List<Map<String, dynamic>>> getCryEvents({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('cryEvents')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching cry events: $e');
      return [];
    }
  }

  /// Get wetness/diaper change events
  /// Call when user opens Diaper Log screen
  Future<List<Map<String, dynamic>>> getWetnessEvents({
    required String babyId,
    int daysBack = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('wetnessEvents')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching wetness events: $e');
      return [];
    }
  }

  /// Get pre-aggregated daily stats from Cloud Functions
  /// Cheaper than calculating on-client from raw vitals
  /// Call when user opens Dashboard summary or Trends overview
  Future<List<Map<String, dynamic>>> getDailyStats({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('dailyStats')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching daily stats: $e');
      return [];
    }
  }

  /// Get photo timeline (paginated)
  /// Call when user opens Photos screen
  Future<List<Map<String, dynamic>>> getPhotos({
    required String babyId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('babies')
          .doc(babyId)
          .collection('photos')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching photos: $e');
      return [];
    }
  }

  /// Get milestones (not real-time)
  /// Call when user opens Milestones screen
  Future<List<Map<String, dynamic>>> getMilestones({
    required String babyId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .doc(babyId)
          .collection('milestones')
          .orderBy('achievedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching milestones: $e');
      return [];
    }
  }

  /// Get video call session history
  /// Call when user opens Video Call History screen
  Future<List<Map<String, dynamic>>> getVideoCallHistory({
    required String deviceId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('videoCallSessions')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching video call history: $e');
      return [];
    }
  }

  // ============== UTILITY METHODS ==============

  /// Check if baby document exists
  Future<bool> babyExists(String babyId) async {
    try {
      final doc = await _firestore.collection('babies').doc(babyId).get();
      return doc.exists;
    } catch (e) {
      print('[DataFetchingService] Error checking baby existence: $e');
      return false;
    }
  }

  /// Get single baby document (on-demand)
  Future<Map<String, dynamic>?> getBaby(String babyId) async {
    try {
      final doc = await _firestore.collection('babies').doc(babyId).get();
      if (!doc.exists) return null;
      return {...doc.data()!, 'id': doc.id};
    } catch (e) {
      print('[DataFetchingService] Error fetching baby: $e');
      return null;
    }
  }

  /// Get babies for a family (on-demand, typically called once on app load)
  Future<List<Map<String, dynamic>>> getBabiesForFamily(String familyId) async {
    try {
      final snapshot = await _firestore
          .collection('babies')
          .where('familyId', isEqualTo: familyId)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('[DataFetchingService] Error fetching babies for family: $e');
      return [];
    }
  }
}
