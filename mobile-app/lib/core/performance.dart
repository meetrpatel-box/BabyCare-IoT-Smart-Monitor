import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Performance utilities for maintaining 60fps and fast response times
/// See DESIGN_GUIDELINES.md Section 7: Fastest in the World

class Performance {
  Performance._();

  static final Stopwatch _stopwatch = Stopwatch();
  static final Map<String, List<int>> _metrics = {};

  /// Measure execution time of a function
  static T measure<T>(String label, T Function() fn) {
    if (kReleaseMode) return fn();

    _stopwatch.reset();
    _stopwatch.start();
    final result = fn();
    _stopwatch.stop();

    _recordMetric(label, _stopwatch.elapsedMilliseconds);
    return result;
  }

  /// Measure async execution time
  static Future<T> measureAsync<T>(
      String label, Future<T> Function() fn) async {
    if (kReleaseMode) return fn();

    _stopwatch.reset();
    _stopwatch.start();
    final result = await fn();
    _stopwatch.stop();

    _recordMetric(label, _stopwatch.elapsedMilliseconds);
    return result;
  }

  static void _recordMetric(String label, int ms) {
    _metrics.putIfAbsent(label, () => []);
    _metrics[label]!.add(ms);

    // Warn if over budget
    if (ms > 16) {
      debugPrint('⚠️ PERF: $label took ${ms}ms (>16ms frame budget)');
    }
  }

  /// Get average time for a metric
  static double getAverageMs(String label) {
    final times = _metrics[label];
    if (times == null || times.isEmpty) return 0;
    return times.reduce((a, b) => a + b) / times.length;
  }

  /// Print performance report
  static void printReport() {
    if (kReleaseMode) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 PERFORMANCE REPORT');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    _metrics.forEach((label, times) {
      final avg = times.reduce((a, b) => a + b) / times.length;
      final max = times.reduce((a, b) => a > b ? a : b);
      final min = times.reduce((a, b) => a < b ? a : b);
      debugPrint('$label: avg=${avg.toStringAsFixed(1)}ms, '
          'min=${min}ms, max=${max}ms, count=${times.length}');
    });

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Clear metrics
  static void clearMetrics() {
    _metrics.clear();
  }
}

/// Debouncer for search and input fields
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler for scroll and resize events
class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(milliseconds: 100)});

  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
    }
  }
}

/// Frame callback scheduler for smooth animations
class FrameScheduler {
  static void schedulePostFrame(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) => callback());
  }

  static void scheduleNextFrame(VoidCallback callback) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => callback());
  }
}

/// Memory-efficient image cache configuration
class ImageCacheConfig {
  static void configure() {
    // Limit image cache to prevent OOM
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
  }
}

/// Lazy loading helper for expensive computations
class Lazy<T> {
  T? _value;
  final T Function() _factory;

  Lazy(this._factory);

  T get value => _value ??= _factory();

  bool get isInitialized => _value != null;

  void reset() => _value = null;
}

/// Compute heavy work off the main thread
Future<T> computeAsync<T>(T Function() computation) {
  return compute((_) => computation(), null);
}
