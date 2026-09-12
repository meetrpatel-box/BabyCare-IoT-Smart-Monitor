import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/device_activation_model.dart';

void main() {
  group('DeviceActivation', () {
    late DeviceActivation device;

    setUp(() {
      device = DeviceActivation(
        deviceId: 'ANVAYA-PRO-12345',
        deviceType: 'anavaya_pro',
        serialNumber: 'SN-2024-001',
        activationCode: '123456',
        qrCodeData: 'ANVAYA-PRO-12345:secret123',
        isActivated: false,
        manufacturedAt: DateTime(2024, 1, 15),
        firmwareVersion: '2.1.0',
      );
    });

    group('toFirestore', () {
      test('serializes all required fields', () {
        final data = device.toFirestore();

        expect(data['deviceType'], equals('anavaya_pro'));
        expect(data['serialNumber'], equals('SN-2024-001'));
        expect(data['activationCode'], equals('123456'));
        expect(data['qrCodeData'], equals('ANVAYA-PRO-12345:secret123'));
        expect(data['isActivated'], isFalse);
        expect(data['firmwareVersion'], equals('2.1.0'));
        expect(data['manufacturedAt'], isNotNull);
      });

      test('serializes null optional fields', () {
        final data = device.toFirestore();

        expect(data['userId'], isNull);
        expect(data['activatedAt'], isNull);
        expect(data['activatedBy'], isNull);
        expect(data['salesPersonId'], isNull);
        expect(data['soldAt'], isNull);
        expect(data['customerEmail'], isNull);
        expect(data['customerPhone'], isNull);
      });

      test('serializes activated device with all fields', () {
        final activatedDevice = DeviceActivation(
          deviceId: 'ANVAYA-12345',
          deviceType: 'anavaya_device',
          serialNumber: 'SN-2024-002',
          activationCode: '654321',
          qrCodeData: 'ANVAYA-12345:secret456',
          isActivated: true,
          userId: 'user-abc',
          activatedAt: DateTime(2024, 2, 1, 10, 30),
          activatedBy: 'user@example.com',
          salesPersonId: 'sales-001',
          soldAt: DateTime(2024, 1, 28),
          customerEmail: 'customer@example.com',
          customerPhone: '+1234567890',
          manufacturedAt: DateTime(2024, 1, 1),
          firmwareVersion: '1.5.0',
          metadata: {'color': 'white', 'batch': 'B2024-01'},
        );

        final data = activatedDevice.toFirestore();

        expect(data['isActivated'], isTrue);
        expect(data['userId'], equals('user-abc'));
        expect(data['activatedBy'], equals('user@example.com'));
        expect(data['salesPersonId'], equals('sales-001'));
        expect(data['customerEmail'], equals('customer@example.com'));
        expect(data['customerPhone'], equals('+1234567890'));
        expect(data['metadata'], containsPair('color', 'white'));
        expect(data['metadata'], containsPair('batch', 'B2024-01'));
      });
    });

    group('generateActivationCode', () {
      test('returns a 6-digit string', () {
        final code = DeviceActivation.generateActivationCode();

        expect(code.length, equals(6));
        expect(int.tryParse(code), isNotNull);
      });

      test('returns a code >= 100000', () {
        final code = int.parse(DeviceActivation.generateActivationCode());

        expect(code, greaterThanOrEqualTo(100000));
        expect(code, lessThan(1000000));
      });
    });

    group('generateQRCodeData', () {
      test('returns deviceId:secret format', () {
        final qr = DeviceActivation.generateQRCodeData(
          'ANVAYA-PRO-99999',
          'mysecret',
        );

        expect(qr, equals('ANVAYA-PRO-99999:mysecret'));
      });

      test('contains both parts separated by colon', () {
        final qr = DeviceActivation.generateQRCodeData('device-1', 'secret-1');
        final parts = qr.split(':');

        expect(parts.length, equals(2));
        expect(parts[0], equals('device-1'));
        expect(parts[1], equals('secret-1'));
      });
    });

    group('metadata', () {
      test('defaults to empty map when not provided', () {
        expect(device.metadata, isEmpty);
      });

      test('preserves provided metadata', () {
        final withMeta = DeviceActivation(
          deviceId: 'test',
          deviceType: 'anavaya_device',
          serialNumber: 'SN-001',
          activationCode: '000000',
          qrCodeData: 'test:secret',
          isActivated: false,
          manufacturedAt: DateTime.now(),
          firmwareVersion: '1.0.0',
          metadata: {'region': 'US', 'sku': 'PRO-2024'},
        );

        expect(withMeta.metadata['region'], equals('US'));
        expect(withMeta.metadata['sku'], equals('PRO-2024'));
      });
    });
  });

  group('ActivationResult', () {
    test('success factory creates successful result', () {
      final result = ActivationResult.success('ANVAYA-123', 'anavaya_pro');

      expect(result.success, isTrue);
      expect(result.deviceId, equals('ANVAYA-123'));
      expect(result.deviceType, equals('anavaya_pro'));
      expect(result.message, isNotNull);
      expect(result.error, isNull);
    });

    test('error factory creates failed result', () {
      final result = ActivationResult.error('Device not found');

      expect(result.success, isFalse);
      expect(result.error, equals('Device not found'));
      expect(result.deviceId, isNull);
      expect(result.deviceType, isNull);
    });

    test('success result has descriptive message', () {
      final result = ActivationResult.success('DEV-001', 'anavaya_device');

      expect(result.message, contains('success'));
    });
  });
}
