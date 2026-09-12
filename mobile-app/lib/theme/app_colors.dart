import 'package:flutter/material.dart';

/// Studio Theme: Modern Minimalist with Serif/Editorial feel
/// Ported from React Native colors.ts
class AppColors {
  AppColors._();

  // Primary brand (Studio Teal)
  static const Color primary = Color(0xFF33CCB2);
  static const Color primaryLight = Color(0xFF9FE0D6);
  static const Color primaryDark = Color(0xFF269985);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Secondary brand (Light Slate)
  static const Color secondary = Color(0xFF9FE0D6);
  static const Color secondaryLight = Color(0xFFEBF9F7);
  static const Color secondaryDark = Color(0xFF5C6B80);
  static const Color secondaryForeground = Color(0xFF333D46);

  // Backgrounds (Clean, very pale blue-grey)
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundWarm = Color(0xFFFAF9F7); // Warm variant
  static const Color backgroundSecondary = Color(0xFFF1F5F9);
  static const Color backgroundTertiary = Color(0xFFE2E8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);

  // Foreground/text (Dark Slate)
  static const Color foreground = Color(0xFF333D46);
  static const Color foregroundPrimary = Color(0xFF333D46);
  static const Color foregroundSecondary = Color(0xFF5C6B80);
  static const Color foregroundTertiary = Color(0xFF94A3B8);
  static const Color textPrimary = Color(0xFF333D46);
  static const Color textSecondary = Color(0xFF5C6B80);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Muted
  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);

  // Card (Pure white with border)
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF333D46);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Border
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFFCBD5E1);
  static const Color input = Color(0xFFE2E8F0);

  // Ring / Focus
  static const Color ring = Color(0xFF33CCB2);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEAB308);
  static const Color warningLight = Color(0xFFFEF9C3);
  static const Color error = Color(0xFFE03E3E);
  static const Color errorLight = Color(0xFFFADBD8);
  static const Color destructive = Color(0xFFE03E3E);
  static const Color info = Color(0xFF3498DB);
  static const Color infoLight = Color(0xFFEBF5FB);

  // Vital Status Colors
  static const Color vitalNormal = Color(0xFF22C55E);
  static const Color vitalWarning = Color(0xFFEAB308);

  // Vital-specific colors for charts
  static const Color heartRate = Color(0xFFE74C3C); // Red
  static const Color temperature = Color(0xFFF39C12); // Orange
  static const Color respiratory = Color(0xFF3498DB); // Blue
  static const Color vitalCritical = Color(0xFFE03E3E);
  static const Color vitalUnknown = Color(0xFF94A3B8);

  // Placeholder & Overlay
  static const Color placeholder = Color(0xFF95A5A6);
  static const Color overlay = Color(0xB32C3E50);

  // Chart colors (Cohesive with primary palette)
  static const Color chart1 = Color(0xFF3498DB);
  static const Color chart2 = Color(0xFF27AE60);
  static const Color chart3 = Color(0xFFF39C12);
  static const Color chart4 = Color(0xFFE74C3C);
  static const Color chart5 = Color(0xFF9B59B6);

  // Sleep Stage Colors
  static const Color sleepDeep = Color(0xFF1E3A5F);
  static const Color sleepLight = Color(0xFF4A90C2);
  static const Color sleepREM = Color(0xFF7B68EE);
  static const Color sleepAwake = Color(0xFFFFB347);

  // Google button
  static const Color googleBlue = Color(0xFF4285F4);

  // Dark Mode Colors
  static const darkColors = _DarkColors();
}

class _DarkColors {
  const _DarkColors();

  Color get background => const Color(0xFF1A252F);
  Color get backgroundSecondary => const Color(0xFF2C3E50);
  Color get backgroundTertiary => const Color(0xFF34495E);
  Color get surface => const Color(0xFF2C3E50);
  Color get surfaceVariant => const Color(0xFF34495E);
  Color get foreground => const Color(0xFFFFFFFF);
  Color get foregroundSecondary => const Color(0xFF95A5A6);
  Color get foregroundTertiary => const Color(0xFF7F8C8D);
  Color get textPrimary => const Color(0xFFFFFFFF);
  Color get textSecondary => const Color(0xFF95A5A6);
  Color get textMuted => const Color(0xFF7F8C8D);
  Color get card => const Color(0xFF2C3E50);
  Color get cardBorder => const Color(0xFF34495E);
  Color get border => const Color(0xFF34495E);
  Color get muted => const Color(0xFF34495E);
  Color get mutedForeground => const Color(0xFF95A5A6);
}
