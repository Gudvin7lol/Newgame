import 'package:flutter/material.dart';

/// Shared visual language for Zamer.
///
/// Screens must consume these tokens instead of introducing local magic
/// colors, radii and spacing values. This keeps the five master pages visually
/// coherent and makes future redesigns a single-point change.
abstract final class ZamerColors {
  static const accent = Color(0xFFF1C79E);
  static const accentInk = Color(0xFF22170F);
  static const secondary = Color(0xFF8FB4D5);
  static const secondaryInk = Color(0xFF08131B);

  static const background = Color(0xFF091014);
  static const surface = Color(0xFF111A1F);
  static const surfaceLow = Color(0xFF0D1519);
  static const surfaceInput = Color(0xFF0E171B);
  static const surfaceHigh = Color(0xFF172228);
  static const surfaceHighest = Color(0xFF1B272D);

  static const outline = Color(0xFF2A3941);
  static const outlineSoft = Color(0xFF202D33);
  static const divider = Color(0xFF223039);

  static const textPrimary = Color(0xFFF4F1EC);
  static const textSecondary = Color(0xFFB5BDC0);
  static const textMuted = Color(0xFF8F9A9F);
  static const textFaint = Color(0xFF78858B);

  static const success = Color(0xFF56D6A3);
  static const warning = Color(0xFFF1C79E);
  static const danger = Color(0xFFFF6B56);
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
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
  );

  static const sectionTitle = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 15.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.1,
  );

  static const sheetTitle = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: ZamerColors.textPrimary,
    fontSize: 14,
    height: 1.35,
  );

  static const caption = TextStyle(
    color: ZamerColors.textMuted,
    fontSize: 11.5,
    height: 1.3,
  );
}
