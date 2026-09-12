import 'package:cloud_firestore/cloud_firestore.dart';

/// Device activation record
/// Created when device is manufactured, activated when sold to user
class DeviceActivation {
  final String deviceId; // e.g., "ANVAYA-PRO-12345"
  final String deviceType; // "anavaya_device" or "anavaya_pro"
  final String serialNumber; // Unique serial number
  final String activationCode; // 6-digit code for manual entry
  final String qrCodeData; // QR code payload (deviceId + secret)
  
  // Activation status
  final bool isActivated;
  final String? userId; // Linked user after activation
  final DateTime? activatedAt;
  final String? activatedBy; // Email/phone used for activation
  
  // Sales information
  final String? salesPersonId; // Who sold the device
  final DateTime? soldAt;
  final String? customerEmail; // Pre-registered email (optional)
  final String? customerPhone; // Pre-registered phone (optional)
  
  // Device metadata
  final DateTime manufacturedAt;
  final String firmwareVersion;
  final Map<String, dynamic> metadata;

  DeviceActivation({
    required this.deviceId,
    required this.deviceType,
    required this.serialNumber,
    required this.activationCode,
    required this.qrCodeData,
    required this.isActivated,
    this.userId,
    this.activatedAt,
    this.activatedBy,
    this.salesPersonId,
    this.soldAt,
    this.customerEmail,
    this.customerPhone,
    required this.manufacturedAt,
    required this.firmwareVersion,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  factory DeviceActivation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceActivation(
      deviceId: doc.id,
      deviceType: data['deviceType'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      activationCode: data['activationCode'] ?? '',
      qrCodeData: data['qrCodeData'] ?? '',
      isActivated: data['isActivated'] ?? false,
      userId: data['userId'],
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      activatedBy: data['activatedBy'],
      salesPersonId: data['salesPersonId'],
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
      customerEmail: data['customerEmail'],
      customerPhone: data['customerPhone'],
      manufacturedAt: (data['manufacturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firmwareVersion: data['firmwareVersion'] ?? '1.0.0',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceType': deviceType,
      'serialNumber': serialNumber,
      'activationCode': activationCode,
      'qrCodeData': qrCodeData,
      'isActivated': isActivated,
      'userId': userId,
      'activatedAt': activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      'activatedBy': activatedBy,
      'salesPersonId': salesPersonId,
      'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'manufacturedAt': Timestamp.fromDate(manufacturedAt),
      'firmwareVersion': firmwareVersion,
      'metadata': metadata,
    };
  }

  /// Generate activation code (6-digit)
  static String generateActivationCode() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  /// Generate QR code data (deviceId + secret hash)
  static String generateQRCodeData(String deviceId, String secret) {
    return '$deviceId:$secret'; // In production, use proper encryption
  }
}

/// Activation result
class ActivationResult {
  final bool success;
  final String? message;
  final String? deviceId;
  final String? deviceType;
  final String? error;

  ActivationResult({
    required this.success,
    this.message,
    this.deviceId,
    this.deviceType,
    this.error,
  });

  factory ActivationResult.success(String deviceId, String deviceType) {
    return ActivationResult(
      success: true,
      message: 'Device activated successfully!',
      deviceId: deviceId,
      deviceType: deviceType,
    );
  }

  factory ActivationResult.error(String error) {
    return ActivationResult(
      success: false,
      error: error,
    );
  }
}
