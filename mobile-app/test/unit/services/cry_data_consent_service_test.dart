import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:baby_track_flutter/services/cry_data_consent_service.dart';
import 'package:baby_track_flutter/models/cry_event_model.dart';

void main() {
  late CryDataConsentService service;
  late FakeFirebaseFirestore fakeFirestore;

  const userId = 'test-user-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = CryDataConsentService(firestore: fakeFirestore);
  });

  group('CryDataConsentService', () {
    group('getConsent', () {
      test('returns featuresOnly when user doc does not exist', () async {
        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.featuresOnly));
      });

      test('returns featuresOnly when preferences field is missing', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'name': 'Test User',
        });

        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.featuresOnly));
      });

      test('returns featuresOnly when cryDataConsent key is missing', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'preferences': {'theme': 'dark'},
        });

        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.featuresOnly));
      });

      test('returns stored consent level - fullAudio', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'preferences': {'cryDataConsent': 'fullAudio'},
        });

        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.fullAudio));
      });

      test('returns stored consent level - none', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'preferences': {'cryDataConsent': 'none'},
        });

        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.none));
      });

      test('returns featuresOnly for invalid consent string', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'preferences': {'cryDataConsent': 'invalid_value'},
        });

        final consent = await service.getConsent(userId);
        expect(consent, equals(CryDataConsent.featuresOnly));
      });
    });

    group('updateConsent', () {
      test('sets consent to fullAudio', () async {
        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.fullAudio,
        );

        final doc =
            await fakeFirestore.collection('users').doc(userId).get();
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        expect(prefs['cryDataConsent'], equals('fullAudio'));
      });

      test('sets consent to none', () async {
        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.none,
        );

        final doc =
            await fakeFirestore.collection('users').doc(userId).get();
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        expect(prefs['cryDataConsent'], equals('none'));
      });

      test('merges with existing user data', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'name': 'Test User',
          'email': 'test@example.com',
        });

        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.featuresOnly,
        );

        final doc =
            await fakeFirestore.collection('users').doc(userId).get();
        expect(doc.data()!['name'], equals('Test User'));
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        expect(prefs['cryDataConsent'], equals('featuresOnly'));
      });

      test('updates consent timestamp', () async {
        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.fullAudio,
        );

        final doc =
            await fakeFirestore.collection('users').doc(userId).get();
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        expect(prefs['cryDataConsentUpdatedAt'], isNotNull);
      });
    });

    group('revokeAndRequestDeletion', () {
      test('sets consent to none', () async {
        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.fullAudio,
        );

        await service.revokeAndRequestDeletion(userId);

        final doc =
            await fakeFirestore.collection('users').doc(userId).get();
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        expect(prefs['cryDataConsent'], equals('none'));
      });

      test('creates a deletion request document', () async {
        await service.revokeAndRequestDeletion(userId);

        final requests =
            await fakeFirestore.collection('dataDeleteRequests').get();
        expect(requests.docs, hasLength(1));

        final data = requests.docs.first.data();
        expect(data['userId'], equals(userId));
        expect(data['type'], equals('cry_training_data'));
        expect(data['status'], equals('pending'));
        expect(data['requestedAt'], isNotNull);
      });
    });

    group('hasCompletedConsentOnboarding', () {
      test('returns false when user doc does not exist', () async {
        final result = await service.hasCompletedConsentOnboarding(userId);
        expect(result, isFalse);
      });

      test('returns false when preferences not set', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'name': 'Test User',
        });

        final result = await service.hasCompletedConsentOnboarding(userId);
        expect(result, isFalse);
      });

      test('returns false when consent timestamp not set', () async {
        await fakeFirestore.collection('users').doc(userId).set({
          'preferences': {'theme': 'dark'},
        });

        final result = await service.hasCompletedConsentOnboarding(userId);
        expect(result, isFalse);
      });

      test('returns true after consent has been updated', () async {
        await service.updateConsent(
          userId: userId,
          consent: CryDataConsent.featuresOnly,
        );

        final result = await service.hasCompletedConsentOnboarding(userId);
        expect(result, isTrue);
      });
    });
  });
}
