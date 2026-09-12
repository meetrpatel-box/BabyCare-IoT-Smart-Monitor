/// Test helpers and utilities for BabyTrack Flutter tests
///
/// This file provides common test utilities used across all test files.
library test_helpers;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Wraps a widget with MaterialApp for testing
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Wraps a widget with MaterialApp and a single provider
Widget wrapWithProvider<T extends ChangeNotifier>({
  required Widget child,
  required T provider,
}) {
  return ChangeNotifierProvider<T>.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Wraps a widget with MaterialApp and multiple providers
Widget wrapWithProviders({
  required Widget child,
  required List<ChangeNotifierProvider> providers,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Extension for WidgetTester to simplify common operations
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps and settles with a timeout
  Future<void> pumpAndSettleWithTimeout([
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    await pumpAndSettle(
        const Duration(milliseconds: 100), EnginePhase.build, timeout);
  }

  /// Enters text and pumps
  Future<void> enterTextAndPump(Finder finder, String text) async {
    await enterText(finder, text);
    await pump();
  }

  /// Taps and pumps
  Future<void> tapAndPump(Finder finder) async {
    await tap(finder);
    await pump();
  }

  /// Taps and settles
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }
}

/// Matcher for checking if a widget has specific decoration color
Matcher hasBackgroundColor(Color color) {
  return predicate<Widget>((widget) {
    if (widget is Container) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == color;
      }
    }
    return false;
  }, 'has background color $color');
}

/// Test group naming conventions
class TestNames {
  /// Model tests
  static String modelFromFirestore(String modelName) =>
      '$modelName.fromFirestore creates model from Firestore data';

  static String modelToFirestore(String modelName) =>
      '$modelName.toFirestore converts model to Firestore format';

  static String modelCopyWith(String modelName) =>
      '$modelName.copyWith creates copy with updated fields';

  /// Service tests
  static String serviceReturnsData(String serviceName, String method) =>
      '$serviceName.$method returns expected data';

  static String serviceHandlesError(String serviceName, String method) =>
      '$serviceName.$method handles errors gracefully';
}
