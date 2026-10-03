import 'package:flutter/material.dart';

import 'design_system/zamer_master_theme.dart';
import 'screens/master_ui_preview_screen.dart';

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
      theme: ZamerMasterTheme.dark,
      home: const MasterUiPreviewScreen(),
    );
  }
}
