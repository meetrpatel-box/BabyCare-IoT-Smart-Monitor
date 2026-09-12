import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cry_event_model.dart';

/// Manages user consent for cry detection data collection.
///
/// Consent levels:
/// - [CryDataConsent.featuresOnly]: Extracted audio features only (default)
/// - [CryDataConsent.fullAudio]: Features + raw audio clips
/// - [CryDataConsent.none]: No data shared, detection still works locally
class CryDataConsentService {
  final FirebaseFirestore _firestore;

  CryDataConsentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the current consent level for a user
  Future<CryDataConsent> getConsent(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return CryDataConsent.featuresOnly;

    final data = doc.data()!;
    final preferences = data['preferences'] as Map<String, dynamic>?;
    if (preferences == null) return CryDataConsent.featuresOnly;

    return CryDataConsent.fromString(
        preferences['cryDataConsent'] as String?);
  }

  /// Update the consent level for a user
  Future<void> updateConsent({
    required String userId,
    required CryDataConsent consent,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'preferences': {
        'cryDataConsent': consent.name,
        'cryDataConsentUpdatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  /// Revoke all consent and request deletion of stored training data
  Future<void> revokeAndRequestDeletion(String userId) async {
    await updateConsent(userId: userId, consent: CryDataConsent.none);

    // Create a deletion request that the training pipeline will process
    await _firestore.collection('dataDeleteRequests').add({
      'userId': userId,
      'type': 'cry_training_data',
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Check if user has completed the consent onboarding
  Future<bool> hasCompletedConsentOnboarding(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final preferences = data['preferences'] as Map<String, dynamic>?;
    return preferences?['cryDataConsentUpdatedAt'] != null;
  }
}
