import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../helpers/device_simulator.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DeviceSimulator simulator;
  late String testBabyId;
  late String testDeviceId;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    testBabyId = 'test-baby-123';

    // Create test baby document
    await fakeFirestore.collection('babies').doc(testBabyId).set({
      'name': 'Test Baby',
      'familyId': 'test-family-123',
      'latestVitals': null,
    });

    // Create test device document
    final deviceRef = await fakeFirestore.collection('devices').add({
      'name': 'Test Device',
      'status': 'offline',
      'familyId': 'test-family-123',
      'assignedBabyId': testBabyId,
      'ownerId': 'test-owner-123',
      'authorizedUsers': ['test-owner-123'],
    });
    testDeviceId = deviceRef.id;

    simulator = DeviceSimulator(
      deviceId: testDeviceId,
      babyId: testBabyId,
      firestore: fakeFirestore,
    );
  });

  tearDown(() {
    simulator.dispose();
  });

  group('Device Start/Stop', () {
    test('Device starts and goes online', () async {
      await simulator.start();

      // Wait for first heartbeat to be sent (it runs every 10 seconds, so wait 11 seconds)
      await Future.delayed(const Duration(seconds: 11));

      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      expect(deviceDoc.data()?['status'], 'online');
      expect(deviceDoc.data()?['lastSeenAt'], isNotNull);
      expect(deviceDoc.data()?['wifiInfo']?['isConnected'], true);
    });

    test('Device stops and goes offline', () async {
      await simulator.start();
      await Future.delayed(const Duration(milliseconds: 500));

      await simulator.stop();

      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      expect(deviceDoc.data()?['status'], 'offline');
    });

    test('Device handles disconnect and reconnect', () async {
      await simulator.start();
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate a 1-second disconnect (shortened for test speed)
      await simulator.simulateDisconnect(duration: const Duration(seconds: 1));

      // Should be online again after reconnect
      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      expect(deviceDoc.data()?['status'], 'online');
    });
  });

  group('Vital Signs Simulation', () {
    test('Generates realistic vital signs', () async {
      await simulator.start();

      // Wait for vital signs to be generated
      await Future.delayed(const Duration(seconds: 16));

      final babyDoc = await fakeFirestore.collection('babies').doc(testBabyId).get();
      final latestVitals = babyDoc.data()?['latestVitals'] as Map<String, dynamic>?;

      expect(latestVitals, isNotNull);
      expect(latestVitals?['heartRate'], inInclusiveRange(100, 140));
      expect(latestVitals?['temperature'], inInclusiveRange(36.5, 37.5));
      expect(latestVitals?['oxygenLevel'], inInclusiveRange(95, 100));
      expect(latestVitals?['humidity'], inInclusiveRange(40, 60));
    });

    test('Stores vital signs in vitalLogs subcollection', () async {
      await simulator.start();

      // Wait for vital signs to be generated
      await Future.delayed(const Duration(seconds: 16));

      final vitalLogs = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('vitalLogs')
          .get();

      expect(vitalLogs.docs.isNotEmpty, true);

      final firstLog = vitalLogs.docs.first.data();
      expect(firstLog['heartRate'], isNotNull);
      expect(firstLog['temperature'], isNotNull);
      expect(firstLog['deviceId'], testDeviceId);
      expect(firstLog['babyId'], testBabyId);
    });
  });

  group('Signal Strength Simulation', () {
    test('Weak signal degrades signal strength', () async {
      await simulator.start();
      simulator.simulateWeakSignal();

      // Wait for next heartbeat
      await Future.delayed(const Duration(seconds: 11));

      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      final signalStrength = deviceDoc.data()?['wifiInfo']?['signalStrength'] as int?;

      // Should be around -85 dBm (weak signal) with some variation
      expect(signalStrength, lessThan(-75));
    });

    test('Good signal improves signal strength', () async {
      await simulator.start();
      simulator.simulateGoodSignal();

      // Wait for next heartbeat
      await Future.delayed(const Duration(seconds: 11));

      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      final signalStrength = deviceDoc.data()?['wifiInfo']?['signalStrength'] as int?;

      // Should be around -45 dBm (excellent signal) with some variation
      expect(signalStrength, greaterThan(-55));
    });
  });

  group('Abnormal Readings and Alerts', () {
    test('Generates high heart rate alert', () async {
      await simulator.start();
      await simulator.simulateAbnormalHeartRate(tooHigh: true);

      final babyDoc = await fakeFirestore.collection('babies').doc(testBabyId).get();
      final latestVitals = babyDoc.data()?['latestVitals'] as Map<String, dynamic>?;

      expect(latestVitals?['heartRate'], 180);
      expect(latestVitals?['alert'], true);
      expect(latestVitals?['alertType'], 'heartRateTooHigh');

      // Check alert was created
      final alerts = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('alerts')
          .get();

      expect(alerts.docs.isNotEmpty, true);
      expect(alerts.docs.first.data()['type'], 'heartRateTooHigh');
      expect(alerts.docs.first.data()['priority'], 'critical');
    });

    test('Generates low heart rate alert', () async {
      await simulator.start();
      await simulator.simulateAbnormalHeartRate(tooHigh: false);

      final babyDoc = await fakeFirestore.collection('babies').doc(testBabyId).get();
      final latestVitals = babyDoc.data()?['latestVitals'] as Map<String, dynamic>?;

      expect(latestVitals?['heartRate'], 70);
      expect(latestVitals?['alertType'], 'heartRateTooLow');
    });
  });

  group('Event Simulation', () {
    test('Simulates cry detection', () async {
      await simulator.start();
      await simulator.simulateCryDetection(durationSeconds: 45);

      final cryEvents = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('cryEvents')
          .get();

      expect(cryEvents.docs.isNotEmpty, true);

      final cryEvent = cryEvents.docs.first.data();
      expect(cryEvent['durationSeconds'], 45);
      expect(cryEvent['intensity'], inInclusiveRange(1, 5));
      expect(cryEvent['deviceId'], testDeviceId);
    });

    test('Simulates wetness detection', () async {
      await simulator.start();
      await simulator.simulateWetnessDetection();

      final wetnessEvents = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('wetnessEvents')
          .get();

      expect(wetnessEvents.docs.isNotEmpty, true);

      final wetnessEvent = wetnessEvents.docs.first.data();
      expect(wetnessEvent['wetLevel'], inInclusiveRange(1, 3));
      expect(wetnessEvent['deviceId'], testDeviceId);
    });
  });

  group('Sleep Session Management', () {
    test('Starts and ends sleep session', () async {
      await simulator.start();

      final sessionId = await simulator.startSleepSession();
      expect(sessionId, isNotNull);

      // Verify session was created
      final sessionDoc = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('sleepSessions')
          .doc(sessionId)
          .get();

      expect(sessionDoc.exists, true);
      expect(sessionDoc.data()?['startTime'], isNotNull);
      expect(sessionDoc.data()?['endTime'], isNull);

      // End the session
      await simulator.endSleepSession(sessionId);

      final endedSession = await fakeFirestore
          .collection('babies')
          .doc(testBabyId)
          .collection('sleepSessions')
          .doc(sessionId)
          .get();

      expect(endedSession.data()?['endTime'], isNotNull);
    });

    test('Throws error when starting sleep session while offline', () async {
      // Don't start simulator (device is offline)
      expect(
        () => simulator.startSleepSession(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Command Handling', () {
    test('Listens for and handles playAudio command', () async {
      await simulator.start();

      // Create command
      final commandRef = await fakeFirestore.collection('deviceCommands').add({
        'deviceId': testDeviceId,
        'commandType': 'playAudio',
        'status': 'pending',
        'payload': {'trackId': 'lullaby-1'},
      });

      // Start listening for commands
      final subscription = simulator.listenForCommands();

      // Wait for command to be processed
      await Future.delayed(const Duration(seconds: 2));

      // Check command was marked as completed
      final commandDoc = await fakeFirestore.collection('deviceCommands').doc(commandRef.id).get();
      expect(commandDoc.data()?['status'], 'completed');
      expect(commandDoc.data()?['executedAt'], isNotNull);

      await subscription.cancel();
    });

    test('Handles reboot command with disconnect', () async {
      await simulator.start();

      final subscription = simulator.listenForCommands();

      // Wait a moment for listener to be set up
      await Future.delayed(const Duration(milliseconds: 500));

      // Create reboot command
      final commandRef = await fakeFirestore.collection('deviceCommands').add({
        'deviceId': testDeviceId,
        'commandType': 'reboot',
        'status': 'pending',
      });

      // Wait for command to be received and processed (1s execution delay + 1s buffer)
      await Future.delayed(const Duration(milliseconds: 2000));

      // Verify command was received (device should have stopped/started disconnect)
      final deviceDoc = await fakeFirestore.collection('devices').doc(testDeviceId).get();
      expect(deviceDoc.data()?['status'], 'offline'); // Device went offline for reboot

      // Note: Command status will be 'completed' after full 30s disconnect finishes
      // For testing purposes, we verify the reboot was initiated by checking device status

      await subscription.cancel();
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('DeviceSimulatorFactory', () {
    test('Creates test device with correct configuration', () async {
      final factory = DeviceSimulatorFactory(firestore: fakeFirestore);

      final newSimulator = await factory.createTestDevice(
        babyId: testBabyId,
        familyId: 'test-family-456',
        ownerId: 'test-owner-456',
        deviceName: 'Factory Device',
      );

      expect(newSimulator, isNotNull);

      // Verify device was created in Firestore
      final devices = await fakeFirestore
          .collection('devices')
          .where('name', isEqualTo: 'Factory Device')
          .get();

      expect(devices.docs.isNotEmpty, true);

      final deviceData = devices.docs.first.data();
      expect(deviceData['familyId'], 'test-family-456');
      expect(deviceData['ownerId'], 'test-owner-456');
      expect(deviceData['authorizedUsers'], contains('test-owner-456'));
      expect(deviceData['capabilities']?['hasCamera'], true);
      expect(deviceData['firmwareVersion'], '1.0.0-simulator');

      newSimulator.dispose();
    });

    test('Creates multiple test devices', () async {
      final factory = DeviceSimulatorFactory(firestore: fakeFirestore);

      final simulators = await factory.createMultipleDevices(
        babyId: testBabyId,
        familyId: 'test-family-789',
        ownerId: 'test-owner-789',
        count: 3,
      );

      expect(simulators.length, 3);

      // Verify all devices were created
      final devices = await fakeFirestore
          .collection('devices')
          .where('familyId', isEqualTo: 'test-family-789')
          .get();

      expect(devices.docs.length, greaterThanOrEqualTo(3));

      for (final sim in simulators) {
        sim.dispose();
      }
    });
  });
}
