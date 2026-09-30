import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page uses production editor and master navigation', () {
    final workspace = File(
      'lib/screens/floor_workspace_screen.dart',
    ).readAsStringSync();
    final measure = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(workspace.contains('onOpen3D: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('onOpenPhoto: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('_showFloorPicker'), isTrue);
    expect(workspace.contains('_switchFloor'), isTrue);
    expect(workspace.contains('Добавить этаж'), isTrue);
    expect(workspace.contains('Navigator.pushReplacement'), isTrue);

    // The approved shell must drive the real editor, not the concept duplicate.
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(measure.contains('PlanEditorConceptScreen('), isFalse);

    // Shared production chrome is the single source of truth.
    expect(measure.contains('ZWorkspaceHeader('), isTrue);
    expect(measure.contains("modeLabel: 'ЗАМЕР 2D'"), isTrue);
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isTrue);

    // The view selector contract is 2D / 3D / Photo. AR is not a fake tab.
    expect(measure.contains('_MeasureConceptView'), isFalse);
    expect(measure.contains("'AR'"), isFalse);

    // Every visible master section has a real navigation path.
    expect(measure.contains('widget.onOpen3D();'), isTrue);
    expect(measure.contains('widget.onOpenObjects();'), isTrue);
    expect(measure.contains('ElevationsScreen('), isTrue);
  });
}
