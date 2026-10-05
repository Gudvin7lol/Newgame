import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project enters recovered workspace instead of a floors index', () {
    final source = File('lib/screens/floors_screen.dart').readAsStringSync();
    expect(source, contains('RecoveredProjectWorkspaceScreen'));
    expect(source, contains('widget.project.floors.first'));
    expect(source, isNot(contains("const Text('Этажи проекта'")));
  });

  test('recovered Measure keeps all direct editing layers wired', () {
    final source = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    for (final symbol in <String>[
      'PlanEditorProductionScreen',
      'MeasureFloorPlanLayerScreen',
      'PlanningObjectsScreen',
      'ElectricalScreen',
      'EngineeringScreen',
      'MaterialsScreen',
    ]) {
      expect(source, contains(symbol), reason: '$symbol must stay in Measure');
    }
    expect(source, contains('Перемещение и вращение объектов на плане'));
    expect(source, contains('Направление и смещение раскладки прямо на плане'));
  });

  test('project workspace keeps four primary modes and equipment placement', () {
    final source = File('lib/screens/recovered_project_workspace_screen.dart')
        .readAsStringSync();
    for (final symbol in <String>[
      'RecoveredMeasureWorkspaceScreen',
      'Floor3DScreen',
      'MasterEquipmentScreen',
      'MasterObjectPlacementWorkspace',
      'LayeredElevationsScreen',
    ]) {
      expect(source, contains(symbol), reason: '$symbol must remain reachable');
    }
    expect(source, contains('0 = Measure, 1 = 3D, 2 = Equipment, 3 = Elevations'));
    expect(source, contains("label: 'ОСНАЩЕНИЕ'"));
  });

  test('recovered navigation exposes Equipment as a primary destination', () {
    final source = File('lib/widgets/recovered_workspace_navigation.dart')
        .readAsStringSync();
    expect(source, contains("'Оснащение'"));
    expect(source, contains('() => onSelected(2)'));
    expect(source, contains('() => onSelected(3)'));
  });
}
