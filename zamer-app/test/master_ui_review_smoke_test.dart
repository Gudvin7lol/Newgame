import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/design_system/zamer_master_theme.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/master_control_screen.dart';
import 'package:zamer_app/screens/master_documentation_screen.dart';
import 'package:zamer_app/screens/master_elevations_screen.dart';
import 'package:zamer_app/screens/master_equipment_screen.dart';
import 'package:zamer_app/screens/master_photo_screen.dart';
import 'package:zamer_app/screens/master_profile_screen.dart';
import 'package:zamer_app/screens/master_ui_preview_screen.dart';

Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ZamerMasterTheme.dark,
      home: child,
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('master UI review launcher fits reference phone', (tester) async {
    await _pumpPhone(tester, const MasterUiPreviewScreen());
    expect(find.text('MASTER UI REVIEW'), findsOneWidget);
  });

  testWidgets('equipment master fits reference phone', (tester) async {
    await _pumpPhone(
      tester,
      const MasterEquipmentScreen(
        projectTitle: 'Квартира, Калининград',
        renderModelPreviews: false,
      ),
    );
    expect(find.text('Оснащение'), findsOneWidget);
  });

  testWidgets('elevations master fits reference phone', (tester) async {
    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    await _pumpPhone(
      tester,
      MasterElevationsScreen(
        floor: floor,
        projectTitle: 'Квартира, Калининград',
      ),
    );
    expect(find.text('Развёртки'), findsWidgets);
  });

  testWidgets('photo master fits reference phone', (tester) async {
    await _pumpPhone(
      tester,
      const MasterPhotoScreen(projectTitle: 'Квартира на Московском'),
    );
    expect(find.text('Фото и заметки'), findsOneWidget);
  });

  testWidgets('documentation master fits reference phone', (tester) async {
    await _pumpPhone(
      tester,
      const MasterDocumentationScreen(projectTitle: 'Квартира на Московском'),
    );
    expect(find.text('Документация'), findsOneWidget);
  });

  testWidgets('control master fits reference phone', (tester) async {
    await _pumpPhone(
      tester,
      const MasterControlScreen(projectTitle: 'Квартира на Московском'),
    );
    expect(find.text('Контроль'), findsWidgets);
  });

  testWidgets('profile master fits reference phone', (tester) async {
    await _pumpPhone(tester, const MasterProfileScreen());
    expect(find.text('Профиль'), findsWidgets);
  });
}
