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

  test('equipment catalog and manipulation stay inside Measure', () {
    final source = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    expect(source, contains('MasterEquipmentScreen'));
    expect(source, contains('EquipmentPlacementService.addCatalogItem'));
    expect(source, contains("label: const Text('Каталог')"));
    expect(source, contains('embedded: true'));
    expect(source, contains('Перемещай и вращай его прямо на плане.'));
  });

  test('project shell has only Measure, 3D and Elevations modes', () {
    final source = File('lib/screens/recovered_project_workspace_screen.dart')
        .readAsStringSync();
    expect(source, contains('0 = Measure, 1 = 3D, 2 = Elevations'));
    expect(source, contains('RecoveredMeasureWorkspaceScreen'));
    expect(source, contains('Floor3DScreen'));
    expect(source, contains('LayeredElevationsScreen'));
    expect(source, isNot(contains("label: 'ОСНАЩЕНИЕ'")));
    expect(source, isNot(contains('MasterEquipmentScreen')));
  });

  test('primary navigation does not duplicate Equipment', () {
    final source = File('lib/widgets/recovered_workspace_navigation.dart')
        .readAsStringSync();
    expect(source, contains("'Главная'"));
    expect(source, contains("'Замер'"));
    expect(source, contains("'3D'"));
    expect(source, contains("'Развёртки'"));
    expect(source, contains("'Профиль'"));
    expect(source, isNot(contains("'Оснащение'")));
  });
}
