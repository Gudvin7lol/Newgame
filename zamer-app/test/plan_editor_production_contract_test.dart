import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measure workspace uses the production master plan editor v2', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final route =
        File('lib/screens/plan_editor_production_screen.dart').readAsStringSync();
    final editor =
        File('lib/screens/plan_editor_master_v2_screen.dart').readAsStringSync();

    expect(workspace.contains('PlanEditorProductionScreen('), isTrue);
    expect(workspace.contains("title: 'Расширенный редактор'"), isTrue);
    expect(route.contains('PlanEditorMasterV2Screen('), isTrue);
    expect(route.contains('PlanEditorMasterScreen('), isFalse);
    expect(editor.contains('_MasterToolRail('), isTrue);
    expect(editor.contains('_MasterActionRail('), isTrue);
    expect(editor.contains('GeometryService.addWallFromNode('), isTrue);
    expect(editor.contains('ControlMeasure('), isTrue);
    expect(editor.contains("Text('Слои'"), isTrue);
  });

  test('master production editor v2 keeps real opening and layer operations', () {
    final editor =
        File('lib/screens/plan_editor_master_v2_screen.dart').readAsStringSync();

    expect(editor.contains('WallOpening('), isTrue);
    expect(editor.contains('DimensionRecord('), isTrue);
    expect(editor.contains('ProjectLayer.demolition'), isTrue);
    expect(editor.contains('ProjectLayer.proposed'), isTrue);
    expect(editor.contains('GeometryService.parallelReferenceLength'), isTrue);
    expect(editor.contains('source: _dimensionSource'), isTrue);
    expect(editor.contains('WallMaterial.values'), isTrue);
    expect(editor.contains('_WallInspectorV2('), isTrue);
  });
}
