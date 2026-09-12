import 'package:cloud_firestore/cloud_firestore.dart';

/// Family model for multi-user support
/// Ported from React Native Family type
class FamilyModel {
  final String id;
  final String name;
  final String ownerId;
  final List<FamilyMember> members;
  final List<String> babyIds;
  final List<String> deviceIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.members = const [],
    this.babyIds = const [],
    this.deviceIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => FamilyMember.fromMap(m))
              .toList() ??
          [],
      babyIds: List<String>.from(data['babyIds'] ?? []),
      deviceIds: List<String>.from(data['deviceIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'members': members.map((m) => m.toMap()).toList(),
      'babyIds': babyIds,
      'deviceIds': deviceIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FamilyModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<FamilyMember>? members,
    List<String>? babyIds,
    List<String>? deviceIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      babyIds: babyIds ?? this.babyIds,
      deviceIds: deviceIds ?? this.deviceIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Family member with role
class FamilyMember {
  final String userId;
  final String email;
  final String? displayName;
  final FamilyRole role;
  final DateTime joinedAt;
  final MemberStatus status;

  FamilyMember({
    required this.userId,
    required this.email,
    this.displayName,
    this.role = FamilyRole.viewer,
    required this.joinedAt,
    this.status = MemberStatus.active,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      role: FamilyRole.fromString(map['role']),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MemberStatus.fromString(map['status']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'status': status.value,
    };
  }
}

/// Family member role enum
enum FamilyRole {
  owner('owner'),
  parent('parent'),
  caregiver('caregiver'),
  viewer('viewer'),
  admin('admin'); // System admin role

  final String value;
  const FamilyRole(this.value);

  static FamilyRole fromString(String? value) {
    return FamilyRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FamilyRole.viewer,
    );
  }

  // Basic permissions
  bool get canEdit => this == FamilyRole.owner || this == FamilyRole.parent || this == FamilyRole.admin;
  bool get canManageDevices => this == FamilyRole.owner || this == FamilyRole.parent || this == FamilyRole.admin;
  bool get canInviteMembers => this == FamilyRole.owner || this == FamilyRole.admin;

  // Enhanced permissions for granular control
  bool get canViewSensitiveData => this != FamilyRole.viewer;
  bool get canDeleteData => this == FamilyRole.owner || this == FamilyRole.admin;
  bool get canManageRoles => this == FamilyRole.owner || this == FamilyRole.admin;

  // Admin-specific permissions
  bool get isSystemAdmin => this == FamilyRole.admin;
  bool get canAccessAllFamilies => isSystemAdmin;
  bool get canModifyBilling => isSystemAdmin;
}

/// Family member status enum
enum MemberStatus {
  active('active'),
  pending('pending'),
  inactive('inactive');

  final String value;
  const MemberStatus(this.value);

  static MemberStatus fromString(String? value) {
    return MemberStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MemberStatus.active,
    );
  }
}

/// Family invite model
class FamilyInvite {
  final String id;
  final String familyId;
  final String email;
  final FamilyRole role;
  final String invitedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final InviteStatus status;

  FamilyInvite({
    required this.id,
    required this.familyId,
    required this.email,
    this.role = FamilyRole.viewer,
    required this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    this.status = InviteStatus.pending,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory FamilyInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyInvite(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      email: data['email'] ?? '',
      role: FamilyRole.fromString(data['role']),
      invitedBy: data['invitedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: InviteStatus.fromString(data['status']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'email': email,
      'role': role.value,
      'invitedBy': invitedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.value,
    };
  }
}

/// Invite status enum
enum InviteStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired');

  final String value;
  const InviteStatus(this.value);

  static InviteStatus fromString(String? value) {
    return InviteStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InviteStatus.pending,
    );
  }
}
