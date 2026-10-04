import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/equipment_placement_service.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('exact wall placement keeps mounted light and electrical point synced', () {
    final floor = FloorPlan(
      id: 'f1',
      name: 'Этаж 1',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 5000, yMm: 0),
      ],
      walls: [
        PlanWall(
          id: 'w1',
          startNodeId: 'a',
          endNodeId: 'b',
          thicknessMm: 100,
        ),
      ],
    );
    final item = ObjectCatalog.byId('wall-sconce-updown');
    final object = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: item,
      objectId: 'sconce-1',
    );

    final placed = EquipmentPlacementService.placeWallObjectAt(
      floor: floor,
      object: object,
      wallId: 'w1',
      wallOffsetMm: 2500,
      wallSide: 1,
      elevationMm: 1800,
    );

    expect(placed, isTrue);
    expect(object.xMm, closeTo(2500, 0.001));
    expect(object.yMm, closeTo(131, 0.001));
    expect(object.elevationMm, 1800);
    expect(object.rotationDeg, closeTo(0, 0.001));

    final mount = EquipmentPlacementService.wallMountForObject(
      floor: floor,
      object: object,
    );
    expect(mount, isNotNull);
    expect(mount!.wallId, 'w1');
    expect(mount.wallOffsetMm, closeTo(2500, 0.001));
    expect(mount.wallSide, 1);

    final fixture = floor.electricalPoints.singleWhere(
      (point) => point.id == 'fixture:sconce-1',
    );
    expect(fixture.wallId, 'w1');
    expect(fixture.wallOffsetMm, closeTo(2500, 0.001));
    expect(fixture.wallSide, 1);
    expect(fixture.heightMm, closeTo(1950, 0.001));
  });

  test('release gate: production elevations expose live object/material editors', () {
    final screen =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final objectEditor =
        File('lib/widgets/elevation_object_editor.dart').readAsStringSync();
    final materialEditor =
        File('lib/widgets/elevation_material_editor.dart').readAsStringSync();

    for (final required in const [
      'ElevationElectricalEditor(',
      'ElevationObjectEditor(',
      'ElevationMaterialEditor(',
      'ElevationEngineeringOverlayPainter(',
      "label: 'Электрика'",
      "label: 'Инженерия'",
      "label: 'Объекты'",
      "label: 'Материалы'",
    ]) {
      expect(screen.contains(required), isTrue, reason: 'Missing: $required');
    }

    for (final required in const [
      'EquipmentPlacementService.placeWallObjectAt(',
      "labelText: 'От начала стены'",
      "labelText: 'Низ объекта от чистого пола'",
      'EquipmentPlacementService.removeObject(',
    ]) {
      expect(
        objectEditor.contains(required),
        isTrue,
        reason: 'Missing object elevation edit contract: $required',
      );
    }

    for (final required in const [
      "MaterialCatalog.forCategory('Стены')",
      "MaterialCatalog.forCategory('Плитка')",
      'settings.wallTileRunEnabled[run.id] = true',
      'settings.wallTileRunRotated[run.id]',
      'settings.wallTileRunMirrored[run.id]',
    ]) {
      expect(
        materialEditor.contains(required),
        isTrue,
        reason: 'Missing material elevation edit contract: $required',
      );
    }
  });
}
