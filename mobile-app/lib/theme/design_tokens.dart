import 'package:flutter/material.dart';

/// Design Tokens - Single Source of Truth
/// Medical-Grade + Child Psychology Approved
///
/// Usage: Import this file anywhere you need design constants
/// DO NOT hardcode colors, spacing, or typography elsewhere
class DesignTokens {
  DesignTokens._(); // Private constructor - use as static class

  // ============================================================================
  // BRAND COLORS (Child Psychology Approved)
  // ============================================================================

  /// Primary teal - Trust, calm, healing, safety
  static const Color primaryTeal = Color(0xFF33CCB2);

  /// Primary light - Softer teal for backgrounds
  static const Color primaryLight = Color(0xFF9FE0D6);

  /// Primary dark - Deeper teal for hover states
  static const Color primaryDark = Color(0xFF2AB39C);

  // ============================================================================
  // BACKGROUNDS (Medical-Grade, Warm)
  // ============================================================================

  /// Main background - Warm off-white (used on ALL screens)
  static const Color backgroundWarm = Color(0xFFFDFBF7);

  /// Surface white - Cards, modals
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  /// Surface gray - Secondary surfaces
  static const Color surfaceGray = Color(0xFFF8FAFC);

  /// Border color - Subtle dividers
  static const Color borderLight = Color(0xFFE2E8F0);

  // ============================================================================
  // TEXT COLORS
  // ============================================================================

  /// Primary text - Headings, important text
  static const Color textPrimary = Color(0xFF333D46);

  /// Secondary text - Body text, descriptions
  static const Color textSecondary = Color(0xFF64748B);

  /// Muted text - Labels, captions
  static const Color textMuted = Color(0xFF94A3B8);

  /// Text on primary - White text on teal buttons
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ============================================================================
  // STATUS COLORS (Child Psychology - Non-Alarming)
  // ============================================================================

  /// Sleeping status - Soft indigo (peace, calm)
  static const Color statusSleeping = Color(0xFF4338CA);

  /// Awake status - Warm amber (alert, positive)
  static const Color statusAwake = Color(0xFFF59E0B);

  /// Healthy vitals - Gentle green (reassurance)
  static const Color statusHealthy = Color(0xFF22C55E);

  /// Warning - Yellow (attention needed, not panic)
  static const Color statusWarning = Color(0xFFEAB308);

  /// Critical - Soft red (urgent, not alarming)
  static const Color statusCritical = Color(0xFFE03E3E);

  /// Info - Soft blue
  static const Color statusInfo = Color(0xFF3B82F6);

  // ============================================================================
  // ACCENT COLORS
  // ============================================================================

  /// Accent blue - Links, secondary actions
  static const Color accentBlue = Color(0xFF3B82F6);

  /// Accent purple - Premium features
  static const Color accentPurple = Color(0xFF8B5CF6);

  /// Accent green - Success, achievements
  static const Color accentGreen = Color(0xFF22C55E);

  /// Accent pink - Highlights, special items
  static const Color accentPink = Color(0xFFEC4899);

  /// Accent yellow - Warnings, stars, milestones
  static const Color accentYellow = Color(0xFFF59E0B);

  // ============================================================================
  // NEUTRAL GRAY SCALE
  // ============================================================================

  static const Color neutralGray50 = Color(0xFFF9FAFB);
  static const Color neutralGray100 = Color(0xFFF3F4F6);
  static const Color neutralGray200 = Color(0xFFE5E7EB);
  static const Color neutralGray300 = Color(0xFFD1D5DB);
  static const Color neutralGray400 = Color(0xFF9CA3AF);
  static const Color neutralGray500 = Color(0xFF6B7280);
  static const Color neutralGray600 = Color(0xFF4B5563);
  static const Color neutralGray700 = Color(0xFF374151);
  static const Color neutralGray800 = Color(0xFF1F2937);
  static const Color neutralGray900 = Color(0xFF111827);

  /// Tertiary text - Lighter labels, timestamps
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ============================================================================
  // STATUS BACKGROUNDS (Light tints for badges/cards)
  // ============================================================================

  static const Color bgSleeping = Color(0xFFE0E7FF); // Soft indigo bg
  static const Color bgAwake = Color(0xFFFEF3C7); // Soft amber bg
  static const Color bgHealthy = Color(0xFFF0FDF4); // Soft green bg
  static const Color bgWarning = Color(0xFFFEF3C7); // Soft yellow bg
  static const Color bgCritical = Color(0xFFFEE2E2); // Soft red bg
  static const Color bgInfo = Color(0xFFEFF6FF); // Soft blue bg

  // ============================================================================
  // SPACING SCALE (8px base grid)
  // ============================================================================

  static const double spaceXs = 4.0; // Tiny gaps
  static const double spaceSm = 8.0; // Small gaps
  static const double spaceMd = 12.0; // Medium gaps
  static const double spaceLg = 16.0; // Large gaps
  static const double spaceXl = 24.0; // Extra large gaps
  static const double spaceXxl = 32.0; // Extra extra large
  static const double space3xl = 40.0; // Massive gaps

  // ============================================================================
  // BORDER RADIUS (Soft, Medical-Grade)
  // ============================================================================

  static const double radiusSm = 8.0; // Small elements (inputs, chips)
  static const double radiusMd = 12.0; // Cards, buttons
  static const double radiusLg = 16.0; // Large cards
  static const double radiusXl = 20.0; // Extra large (bottom sheets)
  static const double radiusFull = 9999.0; // Pills, avatars

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================

  /// Font family - Primary
  static const String fontFamilyPrimary = 'Inter';

  /// Font family - Secondary (for headings)
  static const String fontFamilySecondary = 'SF Pro Display';

  // Font Sizes
  static const double fontSizeXs = 10.0; // Tiny labels
  static const double fontSizeSm = 12.0; // Small labels, captions
  static const double fontSizeMd = 14.0; // Body text
  static const double fontSizeLg = 16.0; // Large body
  static const double fontSizeXl = 18.0; // Small headings
  static const double fontSize2xl = 24.0; // Headings
  static const double fontSize3xl = 32.0; // Large headings

  // Font Weights
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Line Heights
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.8;

  // ============================================================================
  // SHADOWS (Medical-Grade Soft)
  // ============================================================================

  /// Small shadow - Subtle elevation
  static BoxShadow get shadowSm => BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      );

  /// Medium shadow - Card elevation
  static BoxShadow get shadowMd => BoxShadow(
        color: Colors.black.withOpacity(0.07),
        blurRadius: 8,
        offset: const Offset(0, 4),
      );

  /// Large shadow - Modal elevation
  static BoxShadow get shadowLg => BoxShadow(
        color: Colors.black.withOpacity(0.10),
        blurRadius: 16,
        offset: const Offset(0, 8),
      );

  // ============================================================================
  // ELEVATION LEVELS
  // ============================================================================

  static const double elevationNone = 0;
  static const double elevationSm = 2;
  static const double elevationMd = 4;
  static const double elevationLg = 8;

  // ============================================================================
  // ICON SIZES
  // ============================================================================

  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;
  static const double iconSizeXl = 32.0;

  // ============================================================================
  // TOUCH TARGETS (Accessibility - Minimum 44x44)
  // ============================================================================

  static const double touchTargetMin = 44.0;
  static const double touchTargetComfortable = 48.0;

  // ============================================================================
  // DARK MODE COLORS
  // ============================================================================

  static const Color darkBackground = Color(0xFF1A1D1F);
  static const Color darkSurface = Color(0xFF2C2F31);
  static const Color darkBorder = Color(0xFF3F4447);
  static const Color darkTextPrimary = Color(0xFFE4E7EB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextMuted = Color(0xFF6B7280);

  // ============================================================================
  // CHART COLORS (Analytics)
  // ============================================================================

  static const List<Color> chartColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Green
    Color(0xFF06B6D4), // Cyan
  ];

  // ============================================================================
  // GRADIENTS
  // ============================================================================

  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [primaryTeal, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientDark = LinearGradient(
    colors: [Color(0xFF1A1D1F), Color(0xFF2C2F31)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
