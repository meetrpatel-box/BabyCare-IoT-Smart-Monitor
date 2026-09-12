import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cry_event_model.dart';

/// Handles parent feedback on cry classifications.
///
/// This service manages:
/// - Explicit corrections (parent taps "Wrong" and picks correct type)
/// - Confirmations (parent taps "Correct")
/// - Resolution logging (what action stopped the cry)
/// - Passive labeling (infer cry type from subsequent app actions)
class CryFeedbackService {
  final FirebaseFirestore _firestore;

  CryFeedbackService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _eventRef(
          String babyId, String eventId) =>
      _firestore
          .collection('babies')
          .doc(babyId)
          .collection('cryEvents')
          .doc(eventId);

  /// Parent confirms the classification was correct
  Future<void> confirmClassification({
    required String babyId,
    required String eventId,
  }) async {
    await _eventRef(babyId, eventId).update({
      'parentConfirmed': true,
      'correctedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Parent corrects to a different classification
  Future<void> correctClassification({
    required String babyId,
    required String eventId,
    required CryClassification correctedType,
  }) async {
    await _eventRef(babyId, eventId).update({
      'parentCorrectedType': correctedType.name,
      'parentConfirmed': false,
      'correctedAt': FieldValue.serverTimestamp(),
      // Update the active classification to the corrected type
      'classification': correctedType.name,
      'classificationSource': ClassificationSource.parentCorrected.name,
    });
  }

  /// Log what action resolved the cry
  Future<void> logResolution({
    required String babyId,
    required String eventId,
    required CryResolution resolution,
  }) async {
    await _eventRef(babyId, eventId).update({
      'resolution': resolution.name,
    });
  }

  /// Submit full feedback in one call (correction + resolution)
  Future<void> submitFeedback({
    required String babyId,
    required String eventId,
    required bool isCorrect,
    CryClassification? correctedType,
    CryResolution? resolution,
  }) async {
    final updates = <String, dynamic>{
      'correctedAt': FieldValue.serverTimestamp(),
    };

    if (isCorrect) {
      updates['parentConfirmed'] = true;
    } else if (correctedType != null) {
      updates['parentCorrectedType'] = correctedType.name;
      updates['parentConfirmed'] = false;
      updates['classification'] = correctedType.name;
      updates['classificationSource'] =
          ClassificationSource.parentCorrected.name;
    }

    if (resolution != null) {
      updates['resolution'] = resolution.name;
    }

    await _eventRef(babyId, eventId).update(updates);
  }

  /// Attempt passive labeling based on subsequent app actions.
  ///
  /// Call this when a parent logs a feeding, diaper change, or sleep
  /// within [windowMinutes] of an unlabeled cry event.
  ///
  /// Returns the event ID if a passive label was applied, null otherwise.
  Future<String?> attemptPassiveLabel({
    required String babyId,
    required String actionType, // 'feeding', 'diaper', 'sleep'
    required DateTime actionTime,
    int windowMinutes = 15,
  }) async {
    final windowStart =
        actionTime.subtract(Duration(minutes: windowMinutes));

    // Find recent cry events without parent feedback
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
        .where('startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(actionTime))
        .where('parentConfirmed', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();

    // Don't overwrite existing parent corrections
    if (data['parentCorrectedType'] != null) return null;

    // Map action to inferred cry type
    final CryClassification? inferredType;
    final CryResolution? inferredResolution;

    switch (actionType) {
      case 'feeding':
        inferredType = CryClassification.hungry;
        inferredResolution = CryResolution.fed;
        break;
      case 'diaper':
        inferredType = CryClassification.discomfort;
        inferredResolution = CryResolution.diaperChange;
        break;
      case 'sleep':
        inferredType = CryClassification.tired;
        inferredResolution = CryResolution.sleep;
        break;
      default:
        return null;
    }

    // Apply passive label — mark as confirmed since action matches
    await _eventRef(babyId, doc.id).update({
      'parentCorrectedType': inferredType.name,
      'resolution': inferredResolution.name,
      'classificationSource': ClassificationSource.parentCorrected.name,
      'classification': inferredType.name,
      'correctedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Get feedback statistics for a baby (useful for admin panel)
  Future<CryFeedbackStats> getFeedbackStats(String babyId) async {
    final snapshot = await _firestore
        .collection('babies')
        .doc(babyId)
        .collection('cryEvents')
        .get();

    int totalEvents = snapshot.docs.length;
    int confirmed = 0;
    int corrected = 0;
    int unlabeled = 0;
    int withResolution = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['parentConfirmed'] == true) {
        confirmed++;
      } else if (data['parentCorrectedType'] != null) {
        corrected++;
      } else {
        unlabeled++;
      }
      if (data['resolution'] != null) {
        withResolution++;
      }
    }

    return CryFeedbackStats(
      totalEvents: totalEvents,
      confirmed: confirmed,
      corrected: corrected,
      unlabeled: unlabeled,
      withResolution: withResolution,
      feedbackRate:
          totalEvents > 0 ? (confirmed + corrected) / totalEvents : 0.0,
    );
  }
}

/// Statistics about parent feedback on cry events
class CryFeedbackStats {
  final int totalEvents;
  final int confirmed;
  final int corrected;
  final int unlabeled;
  final int withResolution;
  final double feedbackRate;

  const CryFeedbackStats({
    required this.totalEvents,
    required this.confirmed,
    required this.corrected,
    required this.unlabeled,
    required this.withResolution,
    required this.feedbackRate,
  });
}
