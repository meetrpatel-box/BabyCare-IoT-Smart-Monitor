/// Design system constants - STRICT ADHERENCE REQUIRED
/// See DESIGN_GUIDELINES.md for rationale
///
/// Rule: Only use values defined here. No magic numbers.

// =============================================================================
// PERFORMANCE BUDGETS (Non-negotiable)
// =============================================================================

class PerformanceBudget {
  PerformanceBudget._();

  /// App must be interactive within this time
  static const Duration coldStartMax = Duration(milliseconds: 1500);

  /// Screen transitions must complete within this time
  static const Duration transitionMax = Duration(milliseconds: 200);

  /// Touch must show visual feedback within this time
  static const Duration touchResponseMax = Duration(milliseconds: 50);

  /// User should perceive API as complete within this time
  static const Duration apiResponseMax = Duration(milliseconds: 300);

  /// Standard animation duration
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 200);
  static const Duration animationSlow = Duration(milliseconds: 300);

  /// Never exceed these
  static const int targetFrameRate = 60;
  static const int maxRamMB = 150;
  static const int maxAppSizeMB = 30;
}

// =============================================================================
// SPACING SCALE (Only these values allowed)
// =============================================================================

class Spacing {
  Spacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;

  /// Screen edge padding
  static const double screenH = 16.0;
  static const double screenV = 24.0;
}

// =============================================================================
// BORDER RADIUS (Only these values allowed)
// =============================================================================

class Radii {
  Radii._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 9999.0;
}

// =============================================================================
// TYPOGRAPHY SCALE (Only these sizes allowed)
// =============================================================================

class FontSizes {
  FontSizes._();

  static const double label = 12.0;
  static const double caption = 14.0;
  static const double body = 16.0;
  static const double title = 18.0;
  static const double headline = 24.0;
  static const double display = 32.0;
}

// =============================================================================
// TOUCH TARGETS (Accessibility requirement)
// =============================================================================

class TouchTarget {
  TouchTarget._();

  /// Minimum touch target size (Apple HIG)
  static const double min = 44.0;

  /// Comfortable touch target
  static const double comfortable = 48.0;

  /// Large touch target (for tired parents)
  static const double large = 56.0;
}

// =============================================================================
// Z-INDEX / ELEVATION
// =============================================================================

class Elevation {
  Elevation._();

  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;
}

// =============================================================================
// ICON SIZES
// =============================================================================

class IconSizes {
  IconSizes._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;
  static const double xxl = 64.0;
}

// =============================================================================
// TIMING (for consistent feel)
// =============================================================================

class Durations {
  Durations._();

  /// Micro-interactions (button press feedback)
  static const Duration micro = Duration(milliseconds: 50);

  /// Fast animations (fade, color change)
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal animations (most transitions)
  static const Duration normal = Duration(milliseconds: 200);

  /// Slow animations (complex transitions)
  static const Duration slow = Duration(milliseconds: 300);

  /// Page transitions
  static const Duration page = Duration(milliseconds: 250);

  /// Debounce for search/input
  static const Duration debounce = Duration(milliseconds: 300);

  /// Timeout for showing loading state
  static const Duration loadingDelay = Duration(milliseconds: 200);
}

// =============================================================================
// BREAKPOINTS
// =============================================================================

class Breakpoints {
  Breakpoints._();

  static const double mobile = 480.0;
  static const double tablet = 768.0;
  static const double desktop = 1024.0;
}

// =============================================================================
// API / NETWORK
// =============================================================================

class NetworkConstants {
  NetworkConstants._();

  /// Connection timeout
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Read timeout
  static const Duration readTimeout = Duration(seconds: 30);

  /// Retry attempts
  static const int maxRetries = 3;

  /// Cache duration
  static const Duration cacheDuration = Duration(hours: 1);
}

// =============================================================================
// LIST PERFORMANCE
// =============================================================================

class ListConstants {
  ListConstants._();

  /// Page size for pagination
  static const int pageSize = 20;

  /// Cache extent for ListView
  static const double cacheExtent = 500.0;

  /// Threshold to trigger load more
  static const double loadMoreThreshold = 200.0;
}
