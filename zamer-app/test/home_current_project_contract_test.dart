import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Home remembers the last opened project', () {
    final source =
        File('lib/screens/production_home_screen.dart').readAsStringSync();

    expect(source.contains("zamer.last_opened_project_id"), isTrue);
    expect(source.contains('SharedPreferences.getInstance()'), isTrue);
    expect(source.contains('await _rememberOpened(project)'), isTrue);
    expect(source.contains('_lastOpenedProjectId'), isTrue);
  });

  test('production Home opens a project directly into Measure', () {
    final source =
        File('lib/screens/production_home_screen.dart').readAsStringSync();

    expect(source.contains('FloorWorkspaceScreen('), isTrue);
    expect(source.contains('initialMode: mode.clamp(0, 2)'), isTrue);
    expect(source.contains('FloorsScreen('), isFalse);
  });

  test('Measure uses unified 2D 3D Photo shell with functional layers', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();
    final production = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();

    expect(workspace.contains('MeasureUnifiedWorkspaceScreen('), isTrue);
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isTrue);
    expect(measure.contains('ZWorkspaceSubnav('), isTrue);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV4Screen('), isTrue);
    expect(measure.contains('PlanEditorConceptScreen('), isFalse);
    expect(measure.contains('ZMeasureViewMode.ar'), isFalse);
    for (final layer in const [
      "('План'",
      "('Пол'",
      "('Объекты'",
      "('Электрика'",
      "('Инженерия'",
      "('Материалы'",
    ]) {
      expect(measure.contains(layer), isTrue, reason: 'Missing layer: $layer');
    }
  });
}
