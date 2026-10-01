import 'package:flutter/material.dart';

/// ZAMER UI KIT 01 / 02 production tokens.
///
/// The working CAD surfaces follow the approved master concept: near-black
/// graphite/teal surfaces with a warm cream accent. Keep the named brand
/// colors available, but use the semantic aliases below for production UI.
abstract final class ZamerColors {
  // Brand palette.
  static const navy = Color(0xFF0B1F3B);
  static const graphite = Color(0xFF1A2A3A);
  static const darkGray = Color(0xFF2C3B4A);
  static const beige = Color(0xFFDBC3A5);
  static const cream = Color(0xFFF3E9D7);
  static const white = Color(0xFFFFFFFF);

  // UI KIT 02 concept accent sampled from the approved CAD board.
  static const conceptAccent = Color(0xFFFED8AB);

  // Semantic palette.
  static const success = Color(0xFF2EA043);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF4D57);
  static const info = Color(0xFF38A7FF);

  // Neutral palette.
  static const gray100 = Color(0xFFF5F7FA);
  static const gray300 = Color(0xFFD1D5DE);
  static const gray500 = Color(0xFF9AA4B2);
  static const gray700 = Color(0xFF6B7280);

  // Semantic aliases used by the app. These values intentionally follow the
  // approved concept rather than the older blue prototype shown in +76.
  static const accent = conceptAccent;
  static const accentInk = Color(0xFF10233A);
  static const secondary = cream;
  static const secondaryInk = navy;

  static const background = Color(0xFF040F13);
  static const surfaceLow = Color(0xFF071820);
  static const surface = Color(0xFF0B1E26);
  static const surfaceInput = Color(0xFF13242C);
  static const surfaceHigh = Color(0xFF152832);
  static const surfaceHighest = Color(0xFF1B303A);

  static const outline = Color(0xFF253944);
  static const outlineSoft = Color(0xFF2D434E);
  static const outlineLight = gray300;
  static const divider = Color(0xFF20343E);
  static const focus = info;

  static const textPrimary = white;
  static const textSecondary = Color(0xFFD9E0E4);
  static const textMuted = Color(0xFF9CAAB3);
  static const textFaint = Color(0xFF687782);
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

/// Base component dimensions from UI KIT 01.
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

/// Typography from UI KIT 01.
/// Flutter `height` is line-height / font-size.
abstract final class ZamerTypography {
  static const h1 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
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
    height: 26 / 18,
    fontWeight: FontWeight.w500,
  );

  static const h5 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
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
    fontSize: 14,
    height: 18 / 14,
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

  // Backward-compatible semantic aliases.
  static const pageTitle = h1;
  static const sectionTitle = h3;
  static const sheetTitle = h3;
}
