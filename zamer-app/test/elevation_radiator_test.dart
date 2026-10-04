import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/equipment_placement_service.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('catalog radiator is wall-bound and exact-placement editable', () {
    final floor = FloorPlan(
      id: 'f1',
      name: 'Этаж 1',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4000, yMm: 0),
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
    final radiator = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: ObjectCatalog.byId('radiator'),
      objectId: 'rad-1',
    );

    final initial = EquipmentPlacementService.wallMountForObject(
      floor: floor,
      object: radiator,
    );
    expect(initial, isNotNull);

    expect(
      EquipmentPlacementService.placeWallObjectAt(
        floor: floor,
        object: radiator,
        wallId: 'w1',
        wallOffsetMm: 1700,
        wallSide: 1,
        elevationMm: 120,
      ),
      isTrue,
    );
    final moved = EquipmentPlacementService.wallMountForObject(
      floor: floor,
      object: radiator,
    );
    expect(moved, isNotNull);
    expect(moved!.wallId, 'w1');
    expect(moved.wallOffsetMm, closeTo(1700, .001));
    expect(radiator.elevationMm, 120);
  });

  test('release gate: radiator overlay uses same object placement model', () {
    final source =
        File('lib/widgets/elevation_radiator_overlay.dart').readAsStringSync();
    for (final required in const [
      'PlanObjectType.radiator',
      'EquipmentPlacementService.wallMountForObject(',
      'GeometryService.wallFaceStartShiftMm(',
      "object.label.isEmpty ? 'Радиатор' : object.label",
    ]) {
      expect(source.contains(required), isTrue, reason: 'Missing: $required');
    }
  });
}
