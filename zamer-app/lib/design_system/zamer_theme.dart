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
      onError: Colors.white,
    );

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZamerRadius.md),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: ZamerColors.background,
      canvasColor: ZamerColors.background,
      dividerColor: ZamerColors.divider,
      splashColor: ZamerColors.accent.withValues(alpha: .08),
      highlightColor: ZamerColors.accent.withValues(alpha: .04),
      focusColor: ZamerColors.accent.withValues(alpha: .12),
      hoverColor: ZamerColors.accent.withValues(alpha: .06),
      iconTheme: const IconThemeData(
        color: ZamerColors.textSecondary,
        size: ZamerSize.iconMd,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZamerColors.background,
        foregroundColor: ZamerColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        surfaceTintColor: Colors.transparent,
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
        hintStyle: const TextStyle(
          color: ZamerColors.textFaint,
          fontSize: 12.5,
        ),
        labelStyle: const TextStyle(color: ZamerColors.textSecondary),
        prefixIconColor: ZamerColors.textSecondary,
        suffixIconColor: ZamerColors.textSecondary,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          borderSide: const BorderSide(color: ZamerColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          borderSide: const BorderSide(color: ZamerColors.danger, width: 1.4),
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: ZamerColors.accentInk,
          backgroundColor: ZamerColors.accent,
          disabledForegroundColor: ZamerColors.textFaint,
          disabledBackgroundColor: ZamerColors.surfaceHighest,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.button),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          shape: roundedMd,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZamerColors.textPrimary,
          side: const BorderSide(color: ZamerColors.outline),
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          shape: roundedMd,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZamerColors.accent,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          shape: roundedMd,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ZamerColors.surface,
        selectedColor: ZamerColors.accent,
        disabledColor: ZamerColors.surfaceLow,
        labelStyle: const TextStyle(
          color: ZamerColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: ZamerColors.accentInk,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: ZamerColors.outline),
        shape: roundedMd,
        showCheckmark: false,
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
          shape: WidgetStatePropertyAll(roundedMd),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ZamerColors.surfaceLow,
        indicatorColor: Color(0xFF3B3028),
        height: ZamerSize.bottomNavigation,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ZamerColors.surfaceLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          side: const BorderSide(color: ZamerColors.outline),
        ),
        titleTextStyle: const TextStyle(
          color: ZamerColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: ZamerTypography.bodySmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZamerColors.surfaceLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: ZamerColors.textFaint,
        modalBackgroundColor: ZamerColors.surfaceLow,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZamerColors.surfaceHighest,
        contentTextStyle: const TextStyle(color: ZamerColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          side: const BorderSide(color: ZamerColors.outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ZamerColors.surfaceHighest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          side: const BorderSide(color: ZamerColors.outline),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZamerColors.accent,
        linearTrackColor: ZamerColors.surfaceHighest,
        circularTrackColor: ZamerColors.surfaceHighest,
      ),
    );
  }
}
