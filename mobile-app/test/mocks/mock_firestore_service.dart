import 'package:baby_track_flutter/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

/// Mock FirestoreService for testing
class MockFirestoreService extends Mock implements FirestoreService {
  @override
  FirebaseFirestore get firestore => throw UnimplementedError(
        'firestore getter should not be called in unit tests. '
        'Mock the specific methods instead.',
      );
}
