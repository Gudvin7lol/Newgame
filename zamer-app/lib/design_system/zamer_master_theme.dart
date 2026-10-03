import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

/// Theme used by the dedicated MASTER UI review build.
/// It intentionally does not inherit the production bottom-sheet/dialog chrome
/// because the approved boards use dark graphite surfaces everywhere.
abstract final class ZamerMasterTheme {
  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: ZamerColors.accent,
      onPrimary: ZamerColors.accentInk,
      secondary: ZamerColors.cream,
      onSecondary: ZamerColors.accentInk,
      surface: ZamerColors.surface,
      onSurface: ZamerColors.textPrimary,
      error: ZamerColors.danger,
      onError: ZamerColors.white,
      outline: ZamerColors.outline,
      outlineVariant: ZamerColors.outlineSoft,
    );

    final rounded8 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final rounded10 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ZamerColors.background,
      canvasColor: ZamerColors.background,
      dividerColor: ZamerColors.divider,
      splashColor: ZamerColors.accent.withValues(alpha: .07),
      highlightColor: ZamerColors.accent.withValues(alpha: .035),
      focusColor: ZamerColors.accent.withValues(alpha: .10),
      fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
      iconTheme: const IconThemeData(
        color: ZamerColors.textPrimary,
        size: 22,
      ),
      textTheme: const TextTheme(
        bodyLarge: ZamerTypography.body,
        bodyMedium: ZamerTypography.bodySmall,
        bodySmall: ZamerTypography.caption,
        titleLarge: ZamerTypography.h2,
        titleMedium: ZamerTypography.h4,
        titleSmall: ZamerTypography.h5,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZamerColors.background,
        foregroundColor: ZamerColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZamerColors.surfaceInput,
        isDense: true,
        hintStyle: ZamerTypography.bodySmall.copyWith(
          color: ZamerColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ZamerColors.accent, width: 1.4),
        ),
        prefixIconColor: ZamerColors.textSecondary,
        suffixIconColor: ZamerColors.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZamerColors.accent,
          foregroundColor: ZamerColors.accentInk,
          disabledBackgroundColor: ZamerColors.surfaceHigh,
          disabledForegroundColor: ZamerColors.textFaint,
          textStyle: ZamerTypography.button,
          shape: rounded8,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZamerColors.textPrimary,
          side: const BorderSide(color: ZamerColors.outline),
          textStyle: ZamerTypography.button,
          shape: rounded8,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZamerColors.accent,
          textStyle: ZamerTypography.button,
          shape: rounded8,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ZamerColors.surface,
        selectedColor: ZamerColors.accent,
        disabledColor: ZamerColors.surfaceLow,
        labelStyle: ZamerTypography.caption.copyWith(
          color: ZamerColors.textSecondary,
        ),
        secondaryLabelStyle: ZamerTypography.caption.copyWith(
          color: ZamerColors.accentInk,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: ZamerColors.outline),
        shape: rounded8,
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.white
              : ZamerColors.gray300,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.accent
              : ZamerColors.surfaceHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(ZamerColors.outline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ZamerColors.accent,
        inactiveTrackColor: ZamerColors.surfaceHighest,
        thumbColor: ZamerColors.white,
        overlayColor: ZamerColors.accent.withValues(alpha: .10),
        trackHeight: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ZamerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded10,
        titleTextStyle: ZamerTypography.h4,
        contentTextStyle: ZamerTypography.bodySmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZamerColors.background,
        modalBackgroundColor: ZamerColors.background,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: ZamerColors.textFaint,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: ZamerColors.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZamerColors.surfaceHighest,
        contentTextStyle: ZamerTypography.bodySmall.copyWith(
          color: ZamerColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: rounded10,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ZamerColors.accent,
        foregroundColor: ZamerColors.accentInk,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZamerColors.accent,
        linearTrackColor: ZamerColors.surfaceHighest,
        circularTrackColor: ZamerColors.surfaceHighest,
      ),
    );
  }
}
