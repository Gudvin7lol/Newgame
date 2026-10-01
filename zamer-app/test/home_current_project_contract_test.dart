import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home remembers the last opened project', () {
    final source = File('lib/screens/home_concept_screen.dart').readAsStringSync();

    expect(source.contains("zamer.last_opened_project_id"), isTrue);
    expect(source.contains('SharedPreferences.getInstance()'), isTrue);
    expect(source.contains('await _rememberOpened(project)'), isTrue);
    expect(source.contains('_lastOpenedProjectId'), isTrue);
  });

  test('Home sheets force readable dark contrast', () {
    final source = File('lib/screens/home_concept_screen.dart').readAsStringSync();

    expect(source.contains('backgroundColor: _homeSurface'), isTrue);
    expect(source.contains('color: ZamerColors.white'), isTrue);
    expect(source.contains('barrierColor: Colors.black'), isTrue);
  });

  test('Measure page uses production 2D 3D AR Photo concept shell', () {
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

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(measure.contains('_ConceptHeader('), isTrue);
    expect(measure.contains('_ConceptBottomNav('), isTrue);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV3Screen('), isTrue);
    expect(measure.contains('PlanEditorConceptScreen('), isFalse);
    expect(chrome.contains('ZMeasureViewMode.ar'), isTrue);
    expect(measure.contains("'Сохранить'"), isTrue);
  });
}
