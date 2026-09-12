import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_claim_token.dart';

/// Service for managing device claim tokens
/// Handles secure device-to-family linking during provisioning
class DeviceClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new claim token for device provisioning
  /// Token expires in 10 minutes
  Future<DeviceClaimToken> createClaimToken({
    required String familyId,
    required String userId,
  }) async {
    final token = DeviceClaimToken.generateToken();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));

    final claimToken = DeviceClaimToken(
      token: token,
      familyId: familyId,
      createdBy: userId,
      createdAt: now,
      expiresAt: expiresAt,
      claimed: false,
    );

    await _firestore
        .collection('deviceClaims')
        .doc(token)
        .set(claimToken.toFirestore());

    return claimToken;
  }

  /// Validate a claim token (used by Cloud Functions during device registration)
  Future<DeviceClaimToken?> getClaimToken(String token) async {
    try {
      final doc = await _firestore.collection('deviceClaims').doc(token).get();
      if (!doc.exists) return null;
      return DeviceClaimToken.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Mark claim token as used (called after successful device registration)
  Future<void> markTokenClaimed({
    required String token,
    required String deviceId,
  }) async {
    await _firestore.collection('deviceClaims').doc(token).update({
      'claimed': true,
      'deviceId': deviceId,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clean up expired tokens (call periodically)
  Future<void> cleanupExpiredTokens() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _firestore
        .collection('deviceClaims')
        .where('expiresAt', isLessThan: now)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Get active claim token for a user (if any)
  Future<DeviceClaimToken?> getActiveClaimToken(String userId) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _firestore
        .collection('deviceClaims')
        .where('createdBy', isEqualTo: userId)
        .where('claimed', isEqualTo: false)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return DeviceClaimToken.fromFirestore(snapshot.docs.first);
  }

  /// Cancel/delete a claim token
  Future<void> cancelClaimToken(String token) async {
    await _firestore.collection('deviceClaims').doc(token).delete();
  }
}
