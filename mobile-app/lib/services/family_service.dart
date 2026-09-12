import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_model.dart';

/// Family service for multi-user family management
/// Ported from React Native familyService.ts
class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new family
  Future<String> createFamily({
    required String name,
    required String ownerId,
    required String ownerEmail,
    String? ownerDisplayName,
  }) async {
    final family = FamilyModel(
      id: '',
      name: name,
      ownerId: ownerId,
      members: [
        FamilyMember(
          userId: ownerId,
          email: ownerEmail,
          displayName: ownerDisplayName,
          role: FamilyRole.owner,
          joinedAt: DateTime.now(),
          status: MemberStatus.active,
        ),
      ],
      babyIds: [],
      deviceIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef =
        await _firestore.collection('families').add(family.toFirestore());

    // Update user's familyIds
    await _firestore.collection('users').doc(ownerId).update({
      'familyIds': FieldValue.arrayUnion([docRef.id]),
    });

    return docRef.id;
  }

  /// Get family by ID
  Future<FamilyModel?> getFamily(String familyId) async {
    final doc = await _firestore.collection('families').doc(familyId).get();
    if (!doc.exists) return null;
    return FamilyModel.fromFirestore(doc);
  }

  /// Get families for user
  Future<List<FamilyModel>> getUserFamilies(String userId) async {
    final snapshot = await _firestore
        .collection('families')
        .where('members', arrayContainsAny: [
      {'userId': userId}
    ]).get();

    // Fallback: query by ownerId if array query doesn't work
    if (snapshot.docs.isEmpty) {
      final ownerSnapshot = await _firestore
          .collection('families')
          .where('ownerId', isEqualTo: userId)
          .get();
      return ownerSnapshot.docs
          .map((doc) => FamilyModel.fromFirestore(doc))
          .toList();
    }

    return snapshot.docs.map((doc) => FamilyModel.fromFirestore(doc)).toList();
  }

  /// Update family name
  Future<void> updateFamilyName(String familyId, String name) async {
    await _firestore.collection('families').doc(familyId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add baby to family
  Future<void> addBabyToFamily(String familyId, String babyId) async {
    await _firestore.collection('families').doc(familyId).update({
      'babyIds': FieldValue.arrayUnion([babyId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove baby from family
  Future<void> removeBabyFromFamily(String familyId, String babyId) async {
    await _firestore.collection('families').doc(familyId).update({
      'babyIds': FieldValue.arrayRemove([babyId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add device to family
  Future<void> addDeviceToFamily(String familyId, String deviceId) async {
    await _firestore.collection('families').doc(familyId).update({
      'deviceIds': FieldValue.arrayUnion([deviceId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove device from family
  Future<void> removeDeviceFromFamily(String familyId, String deviceId) async {
    await _firestore.collection('families').doc(familyId).update({
      'deviceIds': FieldValue.arrayRemove([deviceId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== Member Management ====================

  /// Invite member to family
  Future<String> inviteMember({
    required String familyId,
    required String email,
    required FamilyRole role,
    required String invitedBy,
  }) async {
    final invite = FamilyInvite(
      id: '',
      familyId: familyId,
      email: email,
      role: role,
      invitedBy: invitedBy,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      status: InviteStatus.pending,
    );

    final docRef =
        await _firestore.collection('familyInvites').add(invite.toFirestore());
    return docRef.id;
  }

  /// Get pending invites for email
  Future<List<FamilyInvite>> getPendingInvitesForEmail(String email) async {
    final snapshot = await _firestore
        .collection('familyInvites')
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs
        .map((doc) => FamilyInvite.fromFirestore(doc))
        .where((invite) => !invite.isExpired)
        .toList();
  }

  /// Accept family invite
  Future<void> acceptInvite({
    required String inviteId,
    required String userId,
    required String email,
    String? displayName,
  }) async {
    // Get invite
    final inviteDoc =
        await _firestore.collection('familyInvites').doc(inviteId).get();
    if (!inviteDoc.exists) throw Exception('Invite not found');

    final invite = FamilyInvite.fromFirestore(inviteDoc);
    if (invite.isExpired) throw Exception('Invite has expired');

    // Add member to family
    final member = FamilyMember(
      userId: userId,
      email: email,
      displayName: displayName,
      role: invite.role,
      joinedAt: DateTime.now(),
      status: MemberStatus.active,
    );

    await _firestore.collection('families').doc(invite.familyId).update({
      'members': FieldValue.arrayUnion([member.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update invite status
    await _firestore.collection('familyInvites').doc(inviteId).update({
      'status': 'accepted',
    });

    // Update user's familyIds
    await _firestore.collection('users').doc(userId).update({
      'familyIds': FieldValue.arrayUnion([invite.familyId]),
    });
  }

  /// Decline family invite
  Future<void> declineInvite(String inviteId) async {
    await _firestore.collection('familyInvites').doc(inviteId).update({
      'status': 'declined',
    });
  }

  /// Remove member from family
  Future<void> removeMember(String familyId, String userId) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    final updatedMembers =
        family.members.where((m) => m.userId != userId).toList();

    await _firestore.collection('families').doc(familyId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove familyId from user
    await _firestore.collection('users').doc(userId).update({
      'familyIds': FieldValue.arrayRemove([familyId]),
    });
  }

  /// Update member role
  Future<void> updateMemberRole(
    String familyId,
    String userId,
    FamilyRole newRole,
  ) async {
    final family = await getFamily(familyId);
    if (family == null) throw Exception('Family not found');

    final updatedMembers = family.members.map((m) {
      if (m.userId == userId) {
        return FamilyMember(
          userId: m.userId,
          email: m.email,
          displayName: m.displayName,
          role: newRole,
          joinedAt: m.joinedAt,
          status: m.status,
        );
      }
      return m;
    }).toList();

    await _firestore.collection('families').doc(familyId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Subscribe to family updates
  Stream<FamilyModel?> subscribeToFamily(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .snapshots()
        .map((doc) => doc.exists ? FamilyModel.fromFirestore(doc) : null);
  }
}
