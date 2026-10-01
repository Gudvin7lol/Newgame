import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measure workspace uses the production master plan editor v3', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final route =
        File('lib/screens/plan_editor_production_screen.dart').readAsStringSync();
    final editor =
        File('lib/screens/plan_editor_master_v3_screen.dart').readAsStringSync();

    expect(workspace.contains('PlanEditorProductionScreen('), isTrue);
    expect(workspace.contains("title: 'Расширенный редактор'"), isTrue);
    expect(route.contains('PlanEditorMasterV3Screen('), isTrue);
    expect(route.contains('PlanEditorMasterV2Screen('), isFalse);
    expect(editor.contains('_ExactToolRail('), isTrue);
    expect(editor.contains('_ExactViewRail('), isTrue);
    expect(editor.contains('GeometryService.addWallFromNode('), isTrue);
    expect(editor.contains('ControlMeasure('), isTrue);
    expect(editor.contains("Text('Слои'"), isTrue);
  });

  test('master production editor v3 keeps real opening and layer operations', () {
    final editor =
        File('lib/screens/plan_editor_master_v3_screen.dart').readAsStringSync();

    expect(editor.contains('WallOpening('), isTrue);
    expect(editor.contains('DimensionRecord('), isTrue);
    expect(editor.contains('ProjectLayer.demolition'), isTrue);
    expect(editor.contains('ProjectLayer.proposed'), isTrue);
    expect(editor.contains('GeometryService.parallelReferenceLength'), isTrue);
    expect(editor.contains('source: _dimensionSource'), isTrue);
    expect(editor.contains('WallMaterial.values'), isTrue);
    expect(editor.contains('_ExactWallInspector('), isTrue);
    expect(editor.contains('_ExactMaterialPanel('), isTrue);
  });
}
