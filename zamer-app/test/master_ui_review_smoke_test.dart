import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zamer_app/design_system/zamer_master_theme.dart';
import 'package:zamer_app/screens/master_control_screen.dart';
import 'package:zamer_app/screens/master_documentation_screen.dart';
import 'package:zamer_app/screens/master_elevations_production_screen.dart';
import 'package:zamer_app/screens/master_equipment_screen.dart';
import 'package:zamer_app/screens/master_photo_screen.dart';
import 'package:zamer_app/screens/master_profile_screen.dart';
import 'package:zamer_app/screens/master_ui_preview_screen.dart';
import 'package:zamer_app/services/demo_project_factory.dart';

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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('master production hub fits reference phone', (tester) async {
    await _pumpPhone(tester, const MasterUiPreviewScreen());
    await tester.pumpAndSettle();
    expect(find.text('РАБОЧИЙ ПРОЕКТ'), findsOneWidget);
    expect(find.text('ЗАМЕР'), findsOneWidget);
    expect(find.text('3D ВИД'), findsOneWidget);
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

  testWidgets('elevations master uses real project geometry', (tester) async {
    final project = DemoProjectFactory.create();
    final floor = project.floors.first;
    await _pumpPhone(
      tester,
      MasterElevationsProductionScreen(
        project: project,
        floor: floor,
        onChanged: () async {},
      ),
    );
    expect(find.text('Развёртки'), findsWidgets);
  });

  testWidgets('photo master fits reference phone', (tester) async {
    final project = DemoProjectFactory.create();
    await _pumpPhone(
      tester,
      MasterPhotoScreen(
        projectTitle: project.name,
        floor: project.floors.first,
        onChanged: () async {},
      ),
    );
    expect(find.text('Фото и заметки'), findsOneWidget);
  });

  testWidgets('documentation master fits reference phone', (tester) async {
    final project = DemoProjectFactory.create();
    await _pumpPhone(
      tester,
      MasterDocumentationScreen(
        project: project,
        floor: project.floors.first,
      ),
    );
    expect(find.text('Документация'), findsOneWidget);
  });

  testWidgets('control master fits reference phone', (tester) async {
    final project = DemoProjectFactory.create();
    await _pumpPhone(
      tester,
      MasterControlScreen(
        projectTitle: project.name,
        floor: project.floors.first,
      ),
    );
    expect(find.text('Контроль'), findsWidgets);
  });

  testWidgets('profile master fits reference phone', (tester) async {
    final project = DemoProjectFactory.create();
    await _pumpPhone(tester, MasterProfileScreen(project: project));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsWidgets);
  });
}
