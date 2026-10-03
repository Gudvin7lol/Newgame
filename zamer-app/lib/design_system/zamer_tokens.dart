import 'package:flutter/material.dart';

/// ZAMER MASTER CONCEPT production tokens.
///
/// Source of truth: the approved dark graphite + warm sand UI boards supplied
/// by the product owner (3D, Equipment, Elevations, Documentation, Photos,
/// Control, Profile). Do not re-introduce the older cyan prototype palette.
abstract final class ZamerColors {
  // Brand / master palette sampled from the approved boards.
  static const navy = Color(0xFF0B0F12);
  static const graphite = Color(0xFF11171B);
  static const darkGray = Color(0xFF171D21);
  static const beige = Color(0xFFFDD2A3);
  static const cream = Color(0xFFFFE0B8);
  static const white = Color(0xFFF7F7F5);

  // Primary interaction accent used throughout the approved master concept.
  static const conceptAccent = Color(0xFFFDD2A3);

  // Semantic palette.
  static const success = Color(0xFF69D79B);
  static const warning = Color(0xFFFFA629);
  static const danger = Color(0xFFFF5C5C);
  static const info = Color(0xFF6EA8FF);

  // Neutral palette.
  static const gray100 = Color(0xFFF4F4F2);
  static const gray300 = Color(0xFFD3D5D6);
  static const gray500 = Color(0xFFA6ADB1);
  static const gray700 = Color(0xFF667077);

  // Semantic aliases.
  static const accent = conceptAccent;
  static const accentInk = Color(0xFF18130F);
  static const secondary = cream;
  static const secondaryInk = Color(0xFF18130F);

  static const background = Color(0xFF0A1215);
  static const surfaceLow = Color(0xFF0B1316);
  static const surface = Color(0xFF11171B);
  static const surfaceInput = Color(0xFF151C20);
  static const surfaceHigh = Color(0xFF171E22);
  static const surfaceHighest = Color(0xFF1D252A);

  static const outline = Color(0xFF30383D);
  static const outlineSoft = Color(0xFF262E33);
  static const outlineLight = Color(0xFF5E676C);
  static const divider = Color(0xFF2A3237);
  static const focus = conceptAccent;

  static const textPrimary = white;
  static const textSecondary = Color(0xFFD6D8D9);
  static const textMuted = Color(0xFFA5ABAF);
  static const textFaint = Color(0xFF6B7479);
}

/// Master spacing scale. The phone boards use a dense 4/8/12/16 rhythm.
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

/// Master radius scale. Panels are restrained; controls are softer than the
/// old prototype but never excessively pill-shaped.
abstract final class ZamerRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const pill = 999.0;
}

/// Base component dimensions derived from the approved phone frames.
abstract final class ZamerSize {
  static const referenceWidth = 390.0;
  static const referenceHeight = 844.0;
  static const contentWidth = 358.0;

  static const topBar = 56.0;
  static const minTouch = 44.0;
  static const button = 52.0;
  static const input = 48.0;
  static const bottomNavigation = 72.0;
  static const cardSmall = 80.0;
  static const cardMedium = 120.0;

  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 28.0;
}

/// Typography tuned to the master concept's compact phone layouts.
abstract final class ZamerTypography {
  static const h1 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
  );

  static const h2 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  static const h3 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
  );

  static const h4 = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 16,
    height: 22 / 16,
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
    fontSize: 15,
    height: 21 / 15,
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
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w400,
  );

  static const button = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  static const technical = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  static const measurement = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const pageTitle = h1;
  static const sectionTitle = h3;
  static const sheetTitle = h3;
}
