import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page uses the approved UI Kit 02 composition', () {
    final workspace = File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_concept_workspace_screen.dart').readAsStringSync();
    final chrome = File('lib/design_system/zamer_measure_chrome.dart').readAsStringSync();
    final production = File('lib/screens/plan_editor_production_screen.dart').readAsStringSync();
    final editor = File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    final painter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV4Screen('), isTrue);
    expect(production.contains('PlanEditorMasterV3Screen('), isFalse);

    expect(measure.contains('_ConceptHeader('), isTrue);
    expect(measure.contains("'ЗАМЕР'"), isTrue);
    expect(measure.contains("'Сохранить'"), isTrue);
    expect(measure.contains('Icons.undo_rounded'), isTrue);
    expect(measure.contains('Icons.redo_rounded'), isTrue);

    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(chrome.contains("_tab('AR', ZMeasureViewMode.ar)"), isTrue);

    for (final required in const [
      'class _ToolRail',
      'class _ViewRail',
      'class _WallInspector',
      'class _ActionBar',
      'class _MaterialPanel',
      "'Сетка'",
      "'3D вид'",
      "'Этажи'",
      "'Привязка'",
      "'Настройки'",
    ]) {
      expect(editor.contains(required), isTrue, reason: 'Missing UI Kit element: $required');
    }

    expect(painter.contains('class CadPlanPainter'), isTrue);
    expect(painter.contains('_objects(canvas)'), isTrue);
    expect(painter.contains('_finishPattern'), isTrue);
    expect(painter.contains('DoorSwing'), isTrue);

    expect(measure.contains('_ConceptBottomNav('), isTrue);
    expect(measure.contains("'Проекты'"), isTrue);
    expect(measure.contains("'Каталог'"), isTrue);
    expect(measure.contains("'Обучение'"), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isFalse);
  });
}
