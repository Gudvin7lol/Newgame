import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

abstract final class ZamerTheme {
  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: ZamerColors.accent,
      onPrimary: ZamerColors.accentInk,
      secondary: ZamerColors.accent,
      onSecondary: ZamerColors.accentInk,
      surface: ZamerColors.surface,
      onSurface: ZamerColors.textPrimary,
      error: ZamerColors.danger,
      onError: ZamerColors.white,
      outline: ZamerColors.outline,
    ).copyWith(
      surfaceContainer: ZamerColors.surfaceHigh,
      surfaceContainerHigh: ZamerColors.surfaceHighest,
      outlineVariant: ZamerColors.outlineSoft,
    );

    final radius8 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
    );
    final radius12 = RoundedRectangleBorder(
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
      focusColor: ZamerColors.accent.withValues(alpha: .14),
      hoverColor: ZamerColors.accent.withValues(alpha: .06),
      fontFamilyFallback: const ['Inter', 'Roboto', 'Arial', 'sans-serif'],
      iconTheme: const IconThemeData(
        color: ZamerColors.textSecondary,
        size: ZamerSize.iconMd,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(ZamerSize.minTouch),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ZamerColors.textFaint
                : ZamerColors.textSecondary,
          ),
          overlayColor: WidgetStatePropertyAll(
            ZamerColors.accent.withValues(alpha: .08),
          ),
          shape: WidgetStatePropertyAll(radius8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZamerColors.background,
        foregroundColor: ZamerColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: ZamerSize.topBar,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: ZamerTypography.h3,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: ZamerColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          side: const BorderSide(color: ZamerColors.outline, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: ZamerSize.input,
        iconColor: ZamerColors.textSecondary,
        textColor: ZamerColors.textPrimary,
        titleTextStyle: ZamerTypography.body,
        subtitleTextStyle: ZamerTypography.caption,
        contentPadding: EdgeInsets.symmetric(horizontal: ZamerSpace.md),
      ),
      dividerTheme: const DividerThemeData(
        color: ZamerColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZamerColors.surfaceInput,
        constraints: const BoxConstraints(minHeight: ZamerSize.input),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZamerSpace.md,
          vertical: 12,
        ),
        hintStyle: ZamerTypography.body.copyWith(
          color: ZamerColors.textMuted,
        ),
        labelStyle: ZamerTypography.body,
        floatingLabelStyle: ZamerTypography.body.copyWith(
          color: ZamerColors.accent,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: ZamerColors.textSecondary,
        suffixIconColor: ZamerColors.textSecondary,
        prefixIconConstraints: const BoxConstraints(
          minWidth: ZamerSize.minTouch,
          minHeight: ZamerSize.minTouch,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: ZamerSize.minTouch,
          minHeight: ZamerSize.minTouch,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          borderSide: const BorderSide(color: ZamerColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          borderSide: const BorderSide(color: ZamerColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          borderSide: const BorderSide(color: ZamerColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          borderSide: const BorderSide(color: ZamerColors.danger, width: 1.5),
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: ZamerColors.accentInk,
          backgroundColor: ZamerColors.accent,
          disabledForegroundColor: ZamerColors.textFaint,
          disabledBackgroundColor: ZamerColors.surfaceHigh,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          padding: const EdgeInsets.symmetric(
            horizontal: ZamerSpace.md,
            vertical: 12,
          ),
          textStyle: ZamerTypography.button,
          shape: radius8,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZamerColors.textPrimary,
          side: const BorderSide(color: ZamerColors.outline),
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          padding: const EdgeInsets.symmetric(
            horizontal: ZamerSpace.md,
            vertical: 12,
          ),
          shape: radius8,
          textStyle: ZamerTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZamerColors.accent,
          minimumSize: const Size(ZamerSize.minTouch, ZamerSize.minTouch),
          shape: radius8,
          textStyle: ZamerTypography.button,
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
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: ZamerColors.outline),
        shape: radius8,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(ZamerSize.minTouch, ZamerSize.minTouch),
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
          overlayColor: WidgetStatePropertyAll(
            ZamerColors.accent.withValues(alpha: .08),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? ZamerColors.accent
                  : ZamerColors.outline,
            ),
          ),
          shape: WidgetStatePropertyAll(radius8),
          textStyle: const WidgetStatePropertyAll(ZamerTypography.button),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.background
              : ZamerColors.gray300,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.accent
              : ZamerColors.surfaceHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(ZamerColors.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.accent
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(ZamerColors.accentInk),
        side: const BorderSide(color: ZamerColors.outline, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.xs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZamerColors.accent
              : ZamerColors.gray300,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ZamerColors.accent,
        inactiveTrackColor: ZamerColors.surfaceHighest,
        thumbColor: ZamerColors.accent,
        overlayColor: ZamerColors.accent.withValues(alpha: .12),
        valueIndicatorColor: ZamerColors.surfaceHighest,
        valueIndicatorTextStyle: ZamerTypography.caption.copyWith(
          color: ZamerColors.textPrimary,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ZamerColors.background,
        indicatorColor: ZamerColors.surfaceHigh,
        height: ZamerSize.bottomNavigation,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: ZamerSize.iconMd),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ZamerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          side: const BorderSide(color: ZamerColors.outline),
        ),
        titleTextStyle: ZamerTypography.h2,
        contentTextStyle: ZamerTypography.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZamerColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: ZamerColors.textMuted,
        modalBackgroundColor: ZamerColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZamerRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZamerColors.card,
        contentTextStyle: ZamerTypography.body.copyWith(
          color: ZamerColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          side: const BorderSide(color: ZamerColors.outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ZamerColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          side: const BorderSide(color: ZamerColors.outline),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ZamerColors.card,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outline),
        ),
        textStyle: ZamerTypography.caption.copyWith(
          color: ZamerColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 450),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZamerColors.accent,
        linearTrackColor: ZamerColors.surfaceHighest,
        circularTrackColor: ZamerColors.surfaceHighest,
      ),
    );
  }
}
