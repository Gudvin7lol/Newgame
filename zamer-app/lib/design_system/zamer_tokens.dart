import 'package:flutter/material.dart';

/// Master visual tokens for Zamer.
///
/// These values are taken from the approved dark concept and are intentionally
/// conservative: warm beige is the primary interaction accent, while blue,
/// green, amber and red are reserved for information/status semantics.
/// Screens should consume these tokens instead of introducing local colors,
/// radii, spacing or typography values.
abstract final class ZamerColors {
  // Brand / interaction.
  static const accent = Color(0xFFE9C48F);
  static const accentInk = Color(0xFF21170F);
  static const secondary = Color(0xFF8FAFC4);
  static const secondaryInk = Color(0xFF08131B);

  // Approved dark surfaces.
  static const background = Color(0xFF0F1419);
  static const surfaceLow = Color(0xFF131A20);
  static const surface = Color(0xFF1A222B);
  static const surfaceInput = Color(0xFF171F27);
  static const surfaceHigh = Color(0xFF202A35);
  static const surfaceHighest = Color(0xFF26323D);

  static const outline = Color(0xFF33414C);
  static const outlineSoft = Color(0xFF293640);
  static const divider = Color(0xFF28343D);

  static const textPrimary = Color(0xFFF5F3EF);
  static const textSecondary = Color(0xFFC6CDD1);
  static const textMuted = Color(0xFF98A3A9);
  static const textFaint = Color(0xFF758188);

  // Semantic colors from the approved component sheet.
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

abstract final class ZamerSpace {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class ZamerRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

abstract final class ZamerSize {
  static const minTouch = 44.0;
  static const button = 46.0;
  static const bottomNavigation = 68.0;
  static const iconSm = 18.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
}

abstract final class ZamerTypography {
  static const pageTitle = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 24,
    height: 1.08,
    fontWeight: FontWeight.w900,
    letterSpacing: .15,
  );

  static const sectionTitle = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 15.5,
    height: 1.15,
    fontWeight: FontWeight.w900,
    letterSpacing: .05,
  );

  static const sheetTitle = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 19,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 1.35,
  );

  static const bodySmall = TextStyle(
    color: ZamerColors.textSecondary,
    fontSize: 12.5,
    height: 1.3,
  );

  static const caption = TextStyle(
    color: ZamerColors.textMuted,
    fontSize: 11.5,
    height: 1.3,
  );

  static const measurement = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: .1,
  );
}
