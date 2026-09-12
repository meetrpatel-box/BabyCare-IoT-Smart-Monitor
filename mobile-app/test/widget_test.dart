// Basic widget test for BabyTrack Monitor app
//
// To run tests: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baby_track_flutter/main.dart';

void main() {
  testWidgets('BabyTrackApp builds without errors',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BabyTrackApp());

    // Verify that the app builds successfully
    // Note: The app shows a loading screen initially while Firebase initializes
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
