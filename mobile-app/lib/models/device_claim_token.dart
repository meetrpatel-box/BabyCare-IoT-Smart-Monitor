import 'package:cloud_firestore/cloud_firestore.dart';

/// Device claim token for secure device provisioning
/// Used to link a new device to a specific family during setup
class DeviceClaimToken {
  final String token;
  final String familyId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool claimed;
  final String? deviceId; // Set when claimed

  DeviceClaimToken({
    required this.token,
    required this.familyId,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.claimed = false,
    this.deviceId,
  });

  /// Check if token is valid (not expired, not claimed)
  bool get isValid {
    return !claimed && DateTime.now().isBefore(expiresAt);
  }

  /// Check if token is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  factory DeviceClaimToken.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceClaimToken(
      token: doc.id,
      familyId: data['familyId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      claimed: data['claimed'] ?? false,
      deviceId: data['deviceId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'claimed': claimed,
      'deviceId': deviceId,
    };
  }

  /// Generate a new random claim token
  static String generateToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = DateTime.now().microsecond.toRadixString(36);
    return 'CLAIM-$timestamp-$random'.toUpperCase();
  }
}
