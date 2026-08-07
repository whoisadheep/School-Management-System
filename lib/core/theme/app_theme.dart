import 'package:flutter/material.dart';

/// School Management System Purple Theme Design System
class AppTheme {
  AppTheme._();

  // ── Primary Purple Palette ──
  static const Color primaryPurple = Color(0xFF4C3BCF);
  static const Color primaryDark = Color(0xFF3A2BA0);
  static const Color primaryLight = Color(0xFF7B68EE);
  static const Color primarySoft = Color(0xFFE8E4FF);

  // ── Background & Surface ──
  static const Color bgMain = Color(0xFFF5F3FF);       // Light lavender background
  static const Color bgSurface = Color(0xFFFFFFFF);     // White cards
  static const Color bgSidebar = Color(0xFF4C3BCF);     // Dark purple sidebar
  static const Color bgBanner = Color(0xFF5B4BC4);      // Welcome banner purple

  // Legacy mappings for backward compatibility
  static const Color bgMidnight = bgMain;
  static const Color bgSurfaceDark = bgSurface;
  static const Color primaryAccent = primaryPurple;
  static const Color primaryBlue = primaryPurple;
  static const Color background = bgMain;
  static const Color surface = bgSurface;
  static const Color surfaceVariant = Color(0xFFF0ECFF);
  static const Color divider = Color(0xFFE8E4FF);

  // ── Status Colors ──
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFF1E1E2D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Stats Card Gradients ──
  static const Color statsGradientStart = Color(0xFF6C5CE7);
  static const Color statsGradientEnd = Color(0xFF4C3BCF);

  // ── Container Decoration ──
  static BoxDecoration cardDecoration({
    double borderRadius = 16.0,
    Color color = bgSurface,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Legacy alias
  static BoxDecoration ledgerDecoration({
    double borderRadius = 16.0,
    Color color = bgSurface,
    Color borderColor = const Color(0xFFE8E4FF),
  }) {
    return cardDecoration(borderRadius: borderRadius, color: color);
  }

  // ── Spacing Tokens ──
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static BorderRadius get cardRadius => BorderRadius.circular(16);
  static BorderRadius get buttonRadius => BorderRadius.circular(12);
  static BorderRadius get chipRadius => BorderRadius.circular(20);
}
