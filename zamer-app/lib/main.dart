import 'package:flutter/material.dart';

import 'design_system/zamer_theme.dart';
import 'screens/home_ui_kit_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZamerApp());
}

class ZamerApp extends StatelessWidget {
  const ZamerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Замер',
      theme: ZamerTheme.dark,
      home: const HomeUiKitScreen(),
    );
  }
}
