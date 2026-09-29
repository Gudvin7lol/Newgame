import 'package:flutter/material.dart';

import 'screens/projects_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZamerApp());
}

class ZamerApp extends StatelessWidget {
  const ZamerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF1C79E);
    const background = Color(0xFF091014);
    const surface = Color(0xFF111A1F);
    const surfaceHigh = Color(0xFF172228);
    const outline = Color(0xFF2A3941);

    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    final scheme = base.copyWith(
      primary: accent,
      onPrimary: const Color(0xFF22170F),
      secondary: const Color(0xFF8FB4D5),
      onSecondary: const Color(0xFF08131B),
      surface: surface,
      surfaceContainer: surfaceHigh,
      surfaceContainerHigh: const Color(0xFF1B272D),
      outline: outline,
      outlineVariant: const Color(0xFF202D33),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Замер',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        dividerColor: const Color(0xFF223039),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xFFF4F1EC),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFF4F1EC),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .1,
          ),
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: outline),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0E171B),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          hintStyle: const TextStyle(color: Color(0xFF78858B)),
          labelStyle: const TextStyle(color: Color(0xFFB5BDC0)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.4),
          ),
          isDense: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFF22170F),
            backgroundColor: accent,
            minimumSize: const Size(44, 46),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE7E1DA),
            side: const BorderSide(color: outline),
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(44, 42)),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF22170F)
                  : const Color(0xFFD3D8DA),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? accent
                  : const Color(0xFF10191E),
            ),
            side: const WidgetStatePropertyAll(BorderSide(color: outline)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0C1418),
          indicatorColor: Color(0xFF3B3028),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF0D1519),
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: Color(0xFF7E898E),
        ),
      ),
      home: const ProjectsScreen(),
    );
  }
}
