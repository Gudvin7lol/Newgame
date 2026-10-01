import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page uses the exact approved UI Kit 02 composition', () {
    final workspace = File(
      'lib/screens/floor_workspace_screen.dart',
    ).readAsStringSync();
    final measure = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();
    final chrome = File(
      'lib/design_system/zamer_measure_chrome.dart',
    ).readAsStringSync();
    final production = File(
      'lib/screens/plan_editor_production_screen.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/screens/plan_editor_master_v3_screen.dart',
    ).readAsStringSync();

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(workspace.contains('_showFloorPicker'), isTrue);
    expect(workspace.contains('_switchFloor'), isTrue);
    expect(workspace.contains('Добавить этаж'), isTrue);

    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV3Screen('), isTrue);
    expect(production.contains('PlanEditorMasterV2Screen('), isFalse);

    // Header from the supplied concept: large ZAMER title, project subtitle,
    // undo / redo / more and a real text Save button.
    expect(measure.contains('_ConceptHeader('), isTrue);
    expect(measure.contains("'ЗАМЕР'"), isTrue);
    expect(measure.contains("'Сохранить'"), isTrue);
    expect(measure.contains('Icons.undo_rounded'), isTrue);
    expect(measure.contains('Icons.redo_rounded'), isTrue);

    // UI KIT 02 shows four equal view modes, including AR.
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(chrome.contains("_tab('AR', ZMeasureViewMode.ar)"), isTrue);

    // Exact CAD composition from the supplied reference boards.
    expect(editor.contains('class _ExactToolRail'), isTrue);
    expect(editor.contains('class _ExactViewRail'), isTrue);
    expect(editor.contains('class _ExactWallInspector'), isTrue);
    expect(editor.contains('class _ExactActionBar'), isTrue);
    expect(editor.contains('class _ExactMaterialPanel'), isTrue);
    expect(editor.contains("'Сетка'"), isTrue);
    expect(editor.contains("'3D вид'"), isTrue);
    expect(editor.contains("'Этажи'"), isTrue);
    expect(editor.contains("'Привязка'"), isTrue);
    expect(editor.contains("'Настройки'"), isTrue);

    // Bottom navigation now follows the approved Measure concept rather than
    // the unrelated five-mode workspace navigation.
    expect(measure.contains('_ConceptBottomNav('), isTrue);
    expect(measure.contains("'Проекты'"), isTrue);
    expect(measure.contains("'Каталог'"), isTrue);
    expect(measure.contains("'Обучение'"), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isFalse);
  });
}
