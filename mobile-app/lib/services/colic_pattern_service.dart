import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/colic_pattern_model.dart';

/// Service for colic pattern detection and analysis.
///
/// Fetches stored colic analysis results and triggers on-demand analysis
/// via the Cloud Function `detectColicPatterns`.
class ColicPatternService {
  final FirebaseFirestore _firestore;
  FirebaseFunctions? _functionsOverride;

  ColicPatternService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functionsOverride = functions;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> _patternsCollection(
          String babyId) =>
      _firestore
          .collection('babies')
          .doc(babyId)
          .collection('colicPatterns');

  /// Get the latest colic analysis for a baby.
  Future<ColicPatternResult?> getLatestAnalysis(String babyId) async {
    final snapshot = await _patternsCollection(babyId)
        .orderBy('analyzedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ColicPatternResult.fromFirestore(snapshot.docs.first);
  }

  /// Get colic analysis history (last N results).
  Future<List<ColicPatternResult>> getAnalysisHistory(
    String babyId, {
    int limit = 14,
  }) async {
    final snapshot = await _patternsCollection(babyId)
        .orderBy('analyzedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ColicPatternResult.fromFirestore(doc))
        .toList();
  }

  /// Stream the latest colic pattern result.
  Stream<ColicPatternResult?> streamLatestAnalysis(String babyId) {
    return _patternsCollection(babyId)
        .orderBy('analyzedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return ColicPatternResult.fromFirestore(snapshot.docs.first);
    });
  }

  /// Run on-demand colic analysis via Cloud Function.
  ///
  /// Returns the full analysis result.
  Future<ColicPatternResult> runAnalysis(
    String babyId, {
    int lookbackDays = 21,
  }) async {
    final callable = _functions.httpsCallable('detectColicPatterns');

    final result = await callable.call<Map<String, dynamic>>({
      'babyId': babyId,
      'lookbackDays': lookbackDays,
    });

    return ColicPatternResult.fromMap(result.data);
  }

  /// Get colic risk level from baby's latest vitals (quick check).
  ///
  /// This reads the denormalized risk from the baby document rather
  /// than running a full analysis.
  Future<ColicRiskLevel> getQuickRiskLevel(String babyId) async {
    final doc = await _firestore.collection('babies').doc(babyId).get();
    if (!doc.exists) return ColicRiskLevel.none;

    final data = doc.data()!;
    final vitals = data['latestVitals'] as Map<String, dynamic>?;
    if (vitals == null) return ColicRiskLevel.none;

    return ColicRiskLevel.fromString(
        vitals['colicRiskLevel'] as String?);
  }
}
