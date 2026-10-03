import 'package:flutter/material.dart';

/// Canonical tokens from the approved ZAMER master UI kit.
///
/// Keep all production screens on these values. The previous warm/cream
/// prototype palette is intentionally not used by the five master pages.
abstract final class ZamerColors {
  // Master UI kit palette.
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF1A1F26);
  static const surfaceInput = Color(0xFF242B36);
  static const surfaceHigh = Color(0xFF242B36);
  static const surfaceHighest = Color(0xFF2F3A46);
  static const outline = Color(0xFF3B4858);

  static const accent = Color(0xFF00C2FF);
  static const accent2 = Color(0xFF0091EA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Compatibility aliases used by older widgets. They intentionally resolve
  // to the master kit rather than resurrecting the old warm prototype.
  static const conceptAccent = accent;
  static const navy = background;
  static const graphite = surface;
  static const darkGray = surfaceHigh;
  static const beige = accent2;
  static const cream = accent;
  static const white = Color(0xFFFFFFFF);
  static const secondary = accent2;
  static const accentInk = Color(0xFF061018);
  static const secondaryInk = white;

  static const surfaceLow = background;
  static const outlineSoft = Color(0xFF303C4A);
  static const outlineLight = Color(0xFFD1D5DE);
  static const divider = Color(0xFF26313D);
  static const focus = accent;

  static const gray100 = Color(0xFFF5F7FA);
  static const gray300 = Color(0xFFD1D5DE);
  static const gray500 = Color(0xFF9AA4B2);
  static const gray700 = Color(0xFF6B7280);

  static const textPrimary = Color(0xFFF7F9FB);
  static const textSecondary = Color(0xFFC8D0D9);
  static const textMuted = Color(0xFF94A0AD);
  static const textFaint = Color(0xFF687583);
}

/// Approved spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48.
abstract final class ZamerSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const jumbo = 48.0;
}

/// Approved radius scale: 4 / 8 / 12 / 16 / 20 / 24.
abstract final class ZamerRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

/// Base dimensions of the 375 × 812 master phones.
abstract final class ZamerSize {
  static const referenceWidth = 375.0;
  static const referenceHeight = 812.0;
  static const contentWidth = 343.0;

  static const topBar = 56.0;
  static const minTouch = 48.0;
  static const button = 56.0;
  static const input = 56.0;
  static const bottomNavigation = 72.0;
  static const cardSmall = 80.0;
  static const cardMedium = 120.0;

  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 28.0;
}

/// Typography printed in the approved master UI kit.
/// Flutter `height` is line-height / font-size.
abstract final class ZamerTypography {
  static const h1 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );

  static const h2 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
  );

  static const h3 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  static const h4 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  static const h5 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const bodySmall = TextStyle(
    color: ZamerColors.textSecondary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    color: ZamerColors.textMuted,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  static const button = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  static const technical = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  static const measurement = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
  );

  static const pageTitle = h1;
  static const sectionTitle = h3;
  static const sheetTitle = h3;
}
