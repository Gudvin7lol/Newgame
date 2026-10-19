import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/plan_editor_screen.dart';

void main() {
  test('the Measure workspace exposes all geometry tools inline', () {
    final unified =
        File('lib/screens/measure_unified_workspace_screen.dart')
            .readAsStringSync();
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();

    for (final tool in <String>[
      'MeasurePlanTool.overview',
      'MeasurePlanTool.select',
      'MeasurePlanTool.nodes',
      'MeasurePlanTool.exterior',
      'MeasurePlanTool.partition',
      'MeasurePlanTool.arc',
      'MeasurePlanTool.precision',
      'MeasurePlanTool.openings',
      'MeasurePlanTool.demolition',
      'MeasurePlanTool.dimensions',
    ]) {
      expect(unified, contains(tool), reason: '$tool must be on the main plan');
    }

    // Shared plan toolbar controls the production plan, legacy CAD features
    // and precise radius tool without opening a separate editor route.
    expect(unified, contains('PlanEditorProductionScreen('));
    expect(unified, contains('PlanEditorScreen('));
    expect(unified, contains('PlanGeometryToolsScreen('));
    expect(unified, contains('embedded: true'));
    expect(unified, contains('_planToolbar()'));
    expect(unified, contains('_planActions()'));
    expect(workspace, isNot(contains('Расширенный редактор')));
    expect(workspace, isNot(contains('_openAdvancedEditor')));
    expect(workspace, contains('_openPlanTool(MeasurePlanTool.nodes)'));
  });

  test('primary Measure controls expose frequently needed project actions', () {
    final source =
        File('lib/screens/measure_unified_workspace_screen.dart')
            .readAsStringSync();
    for (final label in <String>[
      "'Импорт'",
      "'Помещения'",
      "'Этажи'",
      "'Каталог'",
      "'Проверка'",
      "'PDF'",
    ]) {
      expect(source, contains(label));
    }
  });

  testWidgets('embedded editor responds to new tool selection', (tester) async {
    tester.view.physicalSize = const Size(460, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'floor-1', name: 'Первый этаж');
    Widget editor(PlanMode mode) => MaterialApp(
      home: Scaffold(
        body: PlanEditorScreen(
          floor: floor,
          onChanged: () async {},
          embedded: true,
          mode: mode,
        ),
      ),
    );

    await tester.pumpWidget(editor(PlanMode.nodes));
    expect(find.byType(PlanEditorScreen), findsOneWidget);
    expect(tester.widget<PlanEditorScreen>(
      find.byType(PlanEditorScreen),
    ).mode, PlanMode.nodes);
    expect(find.text('Точки'), findsNothing,
        reason: 'the main Measure toolbar is the only tool picker');

    await tester.pumpWidget(editor(PlanMode.demolition));
    await tester.pump();
    expect(tester.widget<PlanEditorScreen>(
      find.byType(PlanEditorScreen),
    ).mode, PlanMode.demolition);
    expect(find.textContaining('Красная штриховка'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
