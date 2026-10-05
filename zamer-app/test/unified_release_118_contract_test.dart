import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects enter recovered workspace without floors gateway', () {
    final source = File('lib/screens/floors_screen.dart').readAsStringSync();
    expect(source, contains('RecoveredProjectWorkspaceScreen'));
    expect(source, isNot(contains("const Text('Этажи проекта'")));
  });

  test('recovered project keeps Measure 3D Equipment and Elevations', () {
    final source = File('lib/screens/recovered_project_workspace_screen.dart')
        .readAsStringSync();
    for (final symbol in <String>[
      'RecoveredMeasureWorkspaceScreen',
      'Floor3DScreen',
      'MasterEquipmentScreen',
      'MasterObjectPlacementWorkspace',
      'LayeredElevationsScreen',
    ]) {
      expect(source, contains(symbol), reason: '$symbol must stay reachable');
    }
  });

  test('main measure editor keeps furniture and floor layout drag', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('PlanDirectInteraction.moveObjectByMm'));
    expect(source, contains('PlanDirectInteraction.shiftFloorLayout'));
    expect(source, contains('_objectDragRegions()'));
    expect(source, contains('_layoutDragRegion()'));
  });

  test('release contains source pack v3 material integration', () {
    final source = File('lib/services/material_catalog.dart').readAsStringSync();
    expect(source, contains('SourcePackV3MaterialIds.all'));
    for (final name in <String>[
      'Светлый дуб · v3',
      'Тёплый орех · v3',
      'Дымчатый дуб · v3',
      'Бетон светлый · v3',
      'Мрамор светлый · v3',
      'Терраццо светлый · v3',
      'Красный кирпич · v3',
      'Гипсовая штукатурка · v3',
      'Матовая краска · v3',
    ]) {
      expect(source, contains(name));
    }
  });
}
