import 'package:flutter/material.dart';

/// Canonical tokens from the approved ZAMER master UI kit.
/// Reference: warm dark concept, screens 1-18.
abstract final class ZamerColors {
  // Exact palette printed in the approved component sheet.
  static const background = Color(0xFF0F1419);
  static const surface = Color(0xFF1A222B);
  static const card = Color(0xFF202A35);
  static const accent = Color(0xFFE9C48F);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // Production semantic aliases.
  static const surfaceLow = background;
  static const surfaceInput = surface;
  static const surfaceHigh = card;
  static const surfaceHighest = Color(0xFF26323E);
  static const outline = Color(0xFF31404C);
  static const outlineSoft = Color(0xFF283640);
  static const divider = Color(0xFF26343D);
  static const focus = accent;

  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFF7F8FA);
  static const textSecondary = Color(0xFFD3D9DE);
  static const textMuted = Color(0xFF9BA7B0);
  static const textFaint = Color(0xFF687680);

  // Backward-compatible aliases used by older widgets.
  static const conceptAccent = accent;
  static const navy = background;
  static const graphite = surface;
  static const darkGray = card;
  static const beige = accent;
  static const cream = accent;
  static const secondary = surfaceHigh;
  static const accentInk = background;
  static const secondaryInk = textPrimary;

  static const gray100 = Color(0xFFF5F7FA);
  static const gray300 = Color(0xFFD1D5DE);
  static const gray500 = Color(0xFF9AA4B2);
  static const gray700 = Color(0xFF6B7280);
  static const outlineLight = gray300;
}

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

abstract final class ZamerRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

/// Base dimensions used by the approved phone comps.
abstract final class ZamerSize {
  static const referenceWidth = 375.0;
  static const referenceHeight = 812.0;
  static const contentWidth = 343.0;

  static const topBar = 56.0;
  static const minTouch = 48.0;
  static const button = 56.0;
  static const input = 48.0;
  static const bottomNavigation = 72.0;
  static const cardSmall = 80.0;
  static const cardMedium = 120.0;

  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 28.0;
}

/// Typography printed in the approved component sheet:
/// H1 28/Bold, H2 20/Semibold, H3 16/Semibold, Body 14/Regular, Caption 12/Regular.
abstract final class ZamerTypography {
  static const h1 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
  );

  static const h2 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
  );

  static const h3 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  static const h4 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w600,
  );

  static const h5 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static const bodySmall = TextStyle(
    color: ZamerColors.textSecondary,
    fontSize: 13,
    height: 18 / 13,
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
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const technical = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  static const measurement = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const pageTitle = h1;
  static const sectionTitle = h2;
  static const sheetTitle = h2;
}
