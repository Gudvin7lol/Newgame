import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified Measure workspace uses the production master plan editor v4', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();
    final route = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    final editor = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();

    expect(workspace.contains('MeasureUnifiedWorkspaceScreen('), isTrue);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(workspace.contains("title: 'Расширенный редактор'"), isTrue);
    expect(route.contains('PlanEditorMasterV4Screen('), isTrue);
    expect(route.contains('PlanEditorMasterV3Screen('), isFalse);
    expect(editor.contains('_ToolRail('), isTrue);
    expect(editor.contains('_ViewRail('), isTrue);
    expect(editor.contains('GeometryService.addWallFromNode('), isTrue);
    expect(editor.contains('ControlMeasure('), isTrue);
    expect(editor.contains('_layersSheet'), isTrue);
  });

  test('master production editor v4 keeps real opening and layer operations', () {
    final editor = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();

    expect(editor.contains('WallOpening('), isTrue);
    expect(editor.contains('DimensionRecord('), isTrue);
    expect(editor.contains('ProjectLayer.values'), isTrue);
    expect(editor.contains('_visibleLayers'), isTrue);
    expect(editor.contains('source: DimensionSource.calculated'), isTrue);
    expect(editor.contains('_WallInspector('), isTrue);
    expect(editor.contains('_MaterialPanel('), isTrue);
    expect(editor.contains('_deleteWall'), isTrue);
  });
}
