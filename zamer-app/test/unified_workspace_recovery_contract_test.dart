import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project enters the workspace directly instead of a floors index', () {
    final source = File('lib/screens/floors_screen.dart').readAsStringSync();
    expect(source, contains('FloorWorkspaceScreen'));
    expect(source, contains('floors.first'));
    expect(source, isNot(contains("const Text('Этажи проекта'")));
  });

  test('unified Measure keeps all direct editing layers wired', () {
    final source = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();
    for (final symbol in <String>[
      'MeasureFloorPlanLayerScreen',
      'PlanningObjectsScreen',
      'ElectricalScreen',
      'EngineeringScreen',
      'MaterialsScreen',
    ]) {
      expect(source, contains(symbol), reason: '$symbol must stay in Measure');
    }
  });

  test('workspace keeps equipment, placement and layered elevations routes', () {
    final source = File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    for (final symbol in <String>[
      'MeasureUnifiedWorkspaceScreen',
      'MasterEquipmentScreen',
      'MasterObjectPlacementWorkspace',
      'LayeredElevationsScreen',
    ]) {
      expect(source, contains(symbol), reason: '$symbol must remain reachable');
    }
  });
}
