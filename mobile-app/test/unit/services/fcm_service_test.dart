import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:baby_track_flutter/services/fcm_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  const userId = 'test-user-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('CryNotification', () {
    test('parses detection notification correctly', () {
      const notification = CryNotification(
        type: CryNotificationType.detection,
        babyId: 'baby-1',
        eventId: 'event-1',
        tier: 'detection',
        title: 'Baby is crying!',
        body: 'Intensity: 85%',
      );

      expect(notification.type, equals(CryNotificationType.detection));
      expect(notification.babyId, equals('baby-1'));
      expect(notification.eventId, equals('event-1'));
      expect(notification.tapped, isFalse);
      expect(notification.routePath, equals('/cry-alert/baby-1'));
    });

    test('parses classification notification correctly', () {
      const notification = CryNotification(
        type: CryNotificationType.classification,
        babyId: 'baby-2',
        eventId: 'event-2',
        tier: 'confirmed',
        classification: 'hungry',
        confidence: 0.89,
        title: 'Baby: Hungry',
        body: 'Try offering a feed',
      );

      expect(notification.type, equals(CryNotificationType.classification));
      expect(notification.classification, equals('hungry'));
      expect(notification.confidence, equals(0.89));
      expect(notification.routePath, equals('/cry-alert/baby-2'));
    });

    test('copyWith updates tapped state', () {
      const original = CryNotification(
        type: CryNotificationType.detection,
        babyId: 'baby-1',
        eventId: 'event-1',
        tier: 'detection',
        title: 'Baby is crying!',
        body: 'Intensity: 85%',
        tapped: false,
      );

      final tapped = original.copyWith(tapped: true);
      expect(tapped.tapped, isTrue);
      expect(tapped.babyId, equals('baby-1'));
      expect(tapped.eventId, equals('event-1'));
      expect(tapped.title, equals('Baby is crying!'));
    });

    test('copyWith preserves all fields when only tapped changes', () {
      const original = CryNotification(
        type: CryNotificationType.classification,
        babyId: 'baby-1',
        eventId: 'event-1',
        tier: 'confirmed',
        classification: 'tired',
        confidence: 0.75,
        title: 'Baby: Tired',
        body: 'Try putting down for a nap',
        tapped: false,
      );

      final tapped = original.copyWith(tapped: true);
      expect(tapped.type, equals(CryNotificationType.classification));
      expect(tapped.classification, equals('tired'));
      expect(tapped.confidence, equals(0.75));
      expect(tapped.body, equals('Try putting down for a nap'));
    });
  });

  group('FCM Token Storage', () {
    test('saves FCM token to Firestore user document', () async {
      // Simulate what FcmService._saveTokenToFirestore does
      const token = 'test-fcm-token-abc123';

      await fakeFirestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

      final doc = await fakeFirestore.collection('users').doc(userId).get();
      final tokens = doc.data()?['fcmTokens'] as List?;

      expect(tokens, isNotNull);
      expect(tokens, contains(token));
    });

    test('adds multiple tokens without duplicates', () async {
      const token1 = 'token-1';
      const token2 = 'token-2';

      await fakeFirestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token1]),
      }, SetOptions(merge: true));

      await fakeFirestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token2]),
      }, SetOptions(merge: true));

      // Add token1 again — should not duplicate
      await fakeFirestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token1]),
      }, SetOptions(merge: true));

      final doc = await fakeFirestore.collection('users').doc(userId).get();
      final tokens = (doc.data()?['fcmTokens'] as List?)?.cast<String>() ?? [];

      expect(tokens, hasLength(2));
      expect(tokens, containsAll([token1, token2]));
    });

    test('removes token on unregister', () async {
      const token = 'token-to-remove';

      // Add token
      await fakeFirestore.collection('users').doc(userId).set({
        'fcmTokens': [token, 'other-token'],
      });

      // Remove token
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

      final doc = await fakeFirestore.collection('users').doc(userId).get();
      final tokens = (doc.data()?['fcmTokens'] as List?)?.cast<String>() ?? [];

      expect(tokens, hasLength(1));
      expect(tokens, contains('other-token'));
      expect(tokens, isNot(contains(token)));
    });
  });

  group('CryNotificationType', () {
    test('has detection and classification values', () {
      expect(CryNotificationType.values, hasLength(2));
      expect(CryNotificationType.values,
          containsAll([CryNotificationType.detection, CryNotificationType.classification]));
    });
  });

  group('Route Path Generation', () {
    test('generates correct cry alert route', () {
      const notification = CryNotification(
        type: CryNotificationType.detection,
        babyId: 'abc-123',
        eventId: 'evt-456',
        tier: 'detection',
        title: 'Test',
        body: 'Test body',
      );

      expect(notification.routePath, equals('/cry-alert/abc-123'));
    });

    test('generates correct route for classification notification', () {
      const notification = CryNotification(
        type: CryNotificationType.classification,
        babyId: 'xyz-789',
        eventId: 'evt-000',
        tier: 'confirmed',
        classification: 'pain',
        confidence: 0.92,
        title: 'Baby: Pain',
        body: 'Check for discomfort',
      );

      expect(notification.routePath, equals('/cry-alert/xyz-789'));
    });
  });
}
