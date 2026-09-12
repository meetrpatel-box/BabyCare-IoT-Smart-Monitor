import 'package:flutter/animation.dart';

/// Animation constants following Child Psychology UX Guidelines
/// Section 6: Friendly Animations - "Gentle, smooth, purposeful"
///
/// Core principles:
/// - Slow & Smooth (300-500ms, not 150ms)
/// - Fast = rushed, anxiety
/// - Slow = calm, controlled
///
/// Reference: DESIGN_GUIDELINES.md Section 6
class AppAnimations {
  AppAnimations._();

  // ============================================================================
  // DURATIONS - Child Psychology guideline: 300-500ms
  // ============================================================================

  /// Standard duration for most UI changes (400ms)
  /// Use for: Status changes, card updates, modal transitions
  /// Psychology: Calm, controlled, not rushed
  static const Duration standardDuration = Duration(milliseconds: 400);

  /// Navigation transitions (300ms)
  /// Use for: Screen-to-screen navigation
  /// Psychology: Responsive but smooth
  static const Duration navigationDuration = Duration(milliseconds: 300);

  /// Success animations (500ms)
  /// Use for: Positive feedback, checkmarks, confirmations
  /// Psychology: Celebratory but gentle
  static const Duration successDuration = Duration(milliseconds: 500);

  /// Error shake animation (200ms)
  /// Use for: Input errors, gentle warnings
  /// Psychology: Quick attention without panic
  static const Duration errorDuration = Duration(milliseconds: 200);

  /// Live indicator pulse (1500ms)
  /// Use for: "Live" badge breathing animation
  /// Psychology: Calm breathing rhythm
  static const Duration pulseDuration = Duration(milliseconds: 1500);

  /// Micro-interaction (100ms)
  /// Use for: Button press feedback, touch scale
  /// Psychology: Instant tactile response
  static const Duration microDuration = Duration(milliseconds: 100);

  // ============================================================================
  // EASING CURVES - Smooth, purposeful
  // ============================================================================

  /// Default easing for most animations
  /// Starts fast, ends gently - feels natural and calm
  static const Curve easeOutCubic = Curves.easeOutCubic;

  /// Navigation and modal transitions
  /// Balanced ease in/out - smooth both ways
  static const Curve easeInOutQuad = Curves.easeInOut;

  /// Success scale-up animation
  /// Gentle ease out for positive reinforcement
  static const Curve easeOutBack = Curves.easeOut;

  /// Error shake - quick attention
  /// Linear for predictable shake
  static const Curve errorCurve = Curves.linear;

  // ============================================================================
  // ANIMATION PATTERNS - Child Psychology approved
  // ============================================================================

  /// Status change animation (fade + scale)
  /// Example: Sleeping badge changes to Awake badge
  /// Duration: 400ms, easeOut
  static const AnimationPattern statusChange = AnimationPattern(
    duration: standardDuration,
    curve: easeOutCubic,
    description: 'Fade + Scale for status changes',
  );

  /// Navigation slide animation
  /// Example: Screen transitions
  /// Duration: 300ms, easeInOut
  static const AnimationPattern navigation = AnimationPattern(
    duration: navigationDuration,
    curve: easeInOutQuad,
    description: 'Slide for navigation',
  );

  /// Success scale animation (1.0 → 1.1 → 1.0)
  /// Example: Checkmark appears, scales up, settles
  /// Duration: 500ms, easeOut
  static const AnimationPattern success = AnimationPattern(
    duration: successDuration,
    curve: easeOutBack,
    description: 'Scale for success feedback',
  );

  /// Error shake animation (gentle 2px amplitude)
  /// Example: Invalid input
  /// Duration: 200ms, linear
  static const AnimationPattern error = AnimationPattern(
    duration: errorDuration,
    curve: errorCurve,
    description: 'Gentle shake for errors',
  );

  /// Live indicator pulse (opacity 1.0 → 0.5 → 1.0)
  /// Example: Red dot on "LIVE" badge
  /// Duration: 1500ms, infinite
  static const AnimationPattern livePulse = AnimationPattern(
    duration: pulseDuration,
    curve: easeInOutQuad,
    description: 'Pulse for live indicator',
  );

  /// Touch feedback (scale 1.0 → 0.98)
  /// Example: Button press
  /// Duration: 100ms, easeOut
  static const AnimationPattern touchFeedback = AnimationPattern(
    duration: microDuration,
    curve: easeOutCubic,
    description: 'Subtle scale on touch',
  );

  // ============================================================================
  // ANTI-PATTERNS (Never use these)
  // ============================================================================

  // ❌ static const Curve bounce = Curves.bounceOut; // Too playful/inappropriate
  // ❌ static const Duration fast = Duration(milliseconds: 150); // Too rushed/anxious
  // ❌ static const Curve linear = Curves.linear; // Robotic (except for shake)
}

/// Animation pattern definition
/// Combines duration, curve, and description for reusability
class AnimationPattern {
  final Duration duration;
  final Curve curve;
  final String description;

  const AnimationPattern({
    required this.duration,
    required this.curve,
    required this.description,
  });
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

// Example 1: Status change fade animation
// AnimatedOpacity(
//   opacity: isVisible ? 1.0 : 0.0,
//   duration: AppAnimations.standardDuration,
//   curve: AppAnimations.easeOutCubic,
//   child: StatusBadge(),
// )

// Example 2: Success checkmark scale
// AnimatedScale(
//   scale: showSuccess ? 1.1 : 1.0,
//   duration: AppAnimations.successDuration,
//   curve: AppAnimations.easeOutBack,
//   child: Icon(Icons.check_circle),
// )

// Example 3: Live indicator pulse
// AnimatedOpacity(
//   opacity: _pulseController.value,
//   duration: AppAnimations.pulseDuration,
//   curve: AppAnimations.easeInOutQuad,
//   child: LiveBadge(),
// )

// Example 4: Button touch feedback
// GestureDetector(
//   onTap: () {
//     setState(() => _pressed = true);
//     Future.delayed(AppAnimations.microDuration, () {
//       setState(() => _pressed = false);
//     });
//   },
//   child: AnimatedScale(
//     scale: _pressed ? 0.98 : 1.0,
//     duration: AppAnimations.microDuration,
//     curve: AppAnimations.easeOutCubic,
//     child: Button(),
//   ),
// )
