import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  test('Measure material panel exposes every applicable finish and can collapse', () {
    final source =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();

    expect(source, contains('MaterialCatalog.floorFinishes'));
    expect(source, contains('MaterialCatalog.wallFinishes'));
    expect(source, contains('ListView.separated('));
    expect(source, contains('scrollDirection: Axis.horizontal'));
    expect(source, contains('expanded ? 132 : 38'));
    expect(source, contains("tooltip: expanded ? 'Скрыть материалы' : 'Показать материалы'"));
    expect(source, contains('filterQuality: FilterQuality.high'));

    final expectedFloor = MaterialCatalog.presets
        .where((item) => item.category == 'Пол' || item.category == 'Плитка')
        .length;
    final expectedWall = MaterialCatalog.presets
        .where((item) => item.category == 'Стены' || item.category == 'Плитка')
        .length;
    expect(MaterialCatalog.floorFinishes.length, expectedFloor);
    expect(MaterialCatalog.wallFinishes.length, expectedWall);
  });

  test('Measure stays lean while Objects own catalog placement and rotation', () {
    final plan =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    final measure =
        File('lib/screens/recovered_measure_workspace_screen.dart').readAsStringSync();
    final objects =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();

    expect(plan, contains('if (item != ZMeasureTool.objects)'));
    expect(plan, isNot(contains("label: 'Геометрия'")));
    expect(plan, isNot(contains("label: 'Проверка'")));

    expect(measure, contains('MasterEquipmentScreen('));
    expect(measure, contains('EquipmentPlacementService.addCatalogItem('));
    expect(measure, contains('_layer = 2'));
    expect(measure, contains('PlanningObjectsScreen('));
    expect(measure, contains('embedded: true'));

    expect(objects, contains('onScaleUpdate: (d) => _objectScaleUpdate(d, size)'));
    expect(objects, contains('_rotateSelected(-15)'));
    expect(objects, contains('_rotateSelected(15)'));
    expect(objects, contains('_rotateSelected(90)'));
  });

  test('elevations render actual wall material under dimensions and openings', () {
    final screen =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final painter =
        File('lib/widgets/elevation_painter.dart').readAsStringSync();

    expect(screen, contains('_ElevationMaterialSurface('));
    expect(screen, contains('Image.asset('));
    expect(screen, contains('filterQuality: FilterQuality.high'));
    expect(screen, contains('drawMaterialFill: false'));
    expect(painter, contains('this.drawMaterialFill = true'));
  });

  test('GPU wall finish uses whole-wall physical UV phase around openings', () {
    final source =
        File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    expect(source, contains('final u0 = wall.textureStartMm / physicalRepeatMm'));
    expect(
      source,
      contains('(wall.textureStartMm + wall.lengthMm) / physicalRepeatMm'),
    );
    expect(source, contains('final v0 = wall.bottomMm / physicalRepeatMm'));
    expect(source, contains('texCoord(vm.Vector2(u0, v0))'));
    expect(source, contains('texCoord(vm.Vector2(u1, v1))'));
  });
}
