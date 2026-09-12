import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_activation_model.dart';
import '../models/subscription_model.dart';
import 'subscription_service.dart';

/// Device Activation Service
/// Handles device activation via QR code, activation code, or pre-registration
class DeviceActivationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Activate device via QR code scan
  Future<ActivationResult> activateViaQRCode(
    String qrCodeData,
    String userId,
    String userEmail,
  ) async {
    try {
      // Parse QR code data (format: "deviceId:secret")
      final parts = qrCodeData.split(':');
      if (parts.length != 2) {
        return ActivationResult.error('Invalid QR code format');
      }

      final deviceId = parts[0];
      final secret = parts[1];

      // Fetch device from Firestore
      final deviceDoc = await _firestore
          .collection('device_activations')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists) {
        return ActivationResult.error('Device not found. Please contact support.');
      }

      final device = DeviceActivation.fromFirestore(deviceDoc);

      // Verify QR code secret matches
      if (device.qrCodeData != qrCodeData) {
        return ActivationResult.error('Invalid QR code. Security check failed.');
      }

      // Check if already activated
      if (device.isActivated) {
        return ActivationResult.error(
          'Device already activated. Contact support if you believe this is an error.',
        );
      }

      // Activate the device
      return await _activateDevice(device, userId, userEmail);
    } catch (e) {
      return ActivationResult.error('Activation failed: ${e.toString()}');
    }
  }

  /// Activate device via activation code (6-digit)
  Future<ActivationResult> activateViaCode(
    String activationCode,
    String userId,
    String userEmail,
  ) async {
    try {
      // Find device by activation code
      final querySnapshot = await _firestore
          .collection('device_activations')
          .where('activationCode', isEqualTo: activationCode)
          .where('isActivated', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return ActivationResult.error(
          'Invalid activation code or device already activated',
        );
      }

      final device = DeviceActivation.fromFirestore(querySnapshot.docs.first);

      // Activate the device
      return await _activateDevice(device, userId, userEmail);
    } catch (e) {
      return ActivationResult.error('Activation failed: ${e.toString()}');
    }
  }

  /// Claim pre-registered device (when salesperson registered customer email)
  Future<ActivationResult> claimPreregisteredDevice(
    String userId,
    String userEmail,
  ) async {
    try {
      // Find device pre-registered to this email
      final querySnapshot = await _firestore
          .collection('device_activations')
          .where('customerEmail', isEqualTo: userEmail.toLowerCase())
          .where('isActivated', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return ActivationResult.error(
          'No device found for this email. Please use QR code or activation code.',
        );
      }

      final device = DeviceActivation.fromFirestore(querySnapshot.docs.first);

      // Activate the device
      return await _activateDevice(device, userId, userEmail);
    } catch (e) {
      return ActivationResult.error('Activation failed: ${e.toString()}');
    }
  }

  /// Internal: Activate device and create subscription
  Future<ActivationResult> _activateDevice(
    DeviceActivation device,
    String userId,
    String userEmail,
  ) async {
    try {
      // 1. Update device activation record
      await _firestore.collection('device_activations').doc(device.deviceId).update({
        'isActivated': true,
        'userId': userId,
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': userEmail,
      });

      // 2. Determine subscription tier based on device type
      final tier = device.deviceType == 'anavaya_pro'
          ? SubscriptionTier.premiumPro
          : SubscriptionTier.premiumDevice;

      // 3. Create/update user subscription
      await _subscriptionService.updateSubscription(
        userId: userId,
        tier: tier,
        deviceId: device.deviceId,
        deviceType: device.deviceType,
      );

      // 4. Log activation event (for analytics)
      await _firestore.collection('activation_events').add({
        'deviceId': device.deviceId,
        'userId': userId,
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': userEmail,
        'salesPersonId': device.salesPersonId,
        'deviceType': device.deviceType,
      });

      return ActivationResult.success(device.deviceId, device.deviceType);
    } catch (e) {
      return ActivationResult.error('Failed to complete activation: ${e.toString()}');
    }
  }

  /// Check if user has any pending pre-registered devices
  Future<bool> hasPendingDevice(String userEmail) async {
    final querySnapshot = await _firestore
        .collection('device_activations')
        .where('customerEmail', isEqualTo: userEmail.toLowerCase())
        .where('isActivated', isEqualTo: false)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  /// Get device information by activation code (for preview before activation)
  Future<DeviceActivation?> getDeviceByCode(String activationCode) async {
    final querySnapshot = await _firestore
        .collection('device_activations')
        .where('activationCode', isEqualTo: activationCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return DeviceActivation.fromFirestore(querySnapshot.docs.first);
  }

  /// Pre-register device for customer (used by salesperson)
  Future<void> preregisterDevice(
    String deviceId,
    String customerEmail,
    String salesPersonId, {
    String? customerPhone,
  }) async {
    await _firestore.collection('device_activations').doc(deviceId).update({
      'customerEmail': customerEmail.toLowerCase(),
      'customerPhone': customerPhone,
      'salesPersonId': salesPersonId,
      'soldAt': FieldValue.serverTimestamp(),
    });

    // Send activation email to customer
    await _sendActivationEmail(deviceId, customerEmail);
  }

  /// Send activation email/SMS to customer
  Future<void> _sendActivationEmail(String deviceId, String customerEmail) async {
    // TODO: Integrate with email service (SendGrid, Firebase Email Extension, etc.)
    // For now, just log
    await _firestore.collection('mail').add({
      'to': customerEmail,
      'template': {
        'name': 'device_activation',
        'data': {
          'deviceId': deviceId,
          'activationLink': 'https://anavaya.app/activate?device=$deviceId',
        },
      },
    });
  }
}
