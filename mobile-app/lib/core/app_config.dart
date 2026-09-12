import 'package:flutter/foundation.dart';

/// When true, vitals screens use generated mock data instead of Firestore.
/// Automatically false in release builds because kDebugMode is false.
const bool kMockVitals = kDebugMode;
