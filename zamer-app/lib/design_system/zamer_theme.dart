import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

abstract final class ZamerTheme {
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: ZamerColors.accent,
      brightness: Brightness.dark,
      surface: ZamerColors.surface,
    );
    final scheme = base.copyWith(
      primary: ZamerColors.accent,
      onPrimary: ZamerColors.accentInk,
      secondary: ZamerColors.secondary,
      onSecondary: ZamerColors.secondaryInk,
      surface: ZamerColors.surface,
      surfaceContainer: ZamerColors.surfaceHigh,
      surfaceContainerHigh: ZamerColors.surfaceHighest,
      outline: ZamerColors.outline,
      outlineVariant: ZamerColors.outlineSoft,
      error: ZamerColors.danger,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: ZamerColors.background,
      dividerColor: ZamerColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: ZamerColors.background,
        foregroundColor: ZamerColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ZamerColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: .1,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: ZamerColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          side: const BorderSide(color: ZamerColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZamerColors.surfaceInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZamerSpace.md,
          vertical: ZamerSpace.md,
        ),
        hintStyle: const TextStyle(color: ZamerColors.textFaint),
        labelStyle: const TextStyle(color: ZamerColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          borderSide: const BorderSide(
            color: ZamerColors.accent,
            width: 1.4,
          ),
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: ZamerColors.accentInk,
          backgroundColor: ZamerColors.accent,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.button),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZamerColors.textPrimary,
          side: const BorderSide(color: ZamerColors.outline),
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZamerColors.accent,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(ZamerSize.minTouch, 42),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ZamerColors.accentInk
                : ZamerColors.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ZamerColors.accent
                : ZamerColors.surface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: ZamerColors.outline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ZamerColors.surfaceLow,
        indicatorColor: Color(0xFF3B3028),
        height: ZamerSize.bottomNavigation,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZamerColors.surfaceLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: ZamerColors.textFaint,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ZamerColors.surfaceHighest,
        contentTextStyle: TextStyle(color: ZamerColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
