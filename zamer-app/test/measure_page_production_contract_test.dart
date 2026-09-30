import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page uses visible production Master UI v2', () {
    final workspace = File(
      'lib/screens/floor_workspace_screen.dart',
    ).readAsStringSync();
    final measure = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();
    final production = File(
      'lib/screens/plan_editor_production_screen.dart',
    ).readAsStringSync();
    final editorV2 = File(
      'lib/screens/plan_editor_master_v2_screen.dart',
    ).readAsStringSync();

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(workspace.contains('onOpen3D: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('onOpenPhoto: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('_showFloorPicker'), isTrue);
    expect(workspace.contains('_switchFloor'), isTrue);
    expect(workspace.contains('Добавить этаж'), isTrue);
    expect(workspace.contains('Navigator.pushReplacement'), isTrue);

    // Production must be routed to the new visual editor, never to the legacy
    // master screen that produced the almost unchanged +74 UI.
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV2Screen('), isTrue);
    expect(production.contains("import 'plan_editor_master_screen.dart';"), isFalse);
    expect(measure.contains('PlanEditorConceptScreen('), isFalse);

    // The Measure page owns its compact master header and real save action.
    expect(measure.contains('_MeasureMasterHeader('), isTrue);
    expect(measure.contains("'ЗАМЕР'"), isTrue);
    expect(measure.contains('Icons.save_outlined'), isTrue);
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isTrue);

    // Visible CAD layout contract from UI Kit 01/02.
    expect(editorV2.contains('class _MasterToolRail'), isTrue);
    expect(editorV2.contains('class _MasterActionRail'), isTrue);
    expect(editorV2.contains('class _WallInspectorV2'), isTrue);
    expect(editorV2.contains('class _ToolbeltV2'), isTrue);
    expect(editorV2.contains('width: 44'), isTrue);
    expect(editorV2.contains('height: 160'), isTrue);
    expect(editorV2.contains('DimensionSource.values'), isTrue);
    expect(editorV2.contains('WallMaterial.values'), isTrue);

    // 2D / 3D / Photo only. AR remains a real feature, not a decorative tab.
    expect(measure.contains("'AR'"), isFalse);

    // Every visible master section has a real route.
    expect(measure.contains('widget.onOpen3D();'), isTrue);
    expect(measure.contains('widget.onOpenObjects();'), isTrue);
    expect(measure.contains('ElevationsScreen('), isTrue);
  });
}
