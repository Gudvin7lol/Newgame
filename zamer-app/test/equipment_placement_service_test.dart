import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/equipment_placement_service.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('catalog equipment is added with exact metadata and survives JSON reload', () {
    final floor = FloorPlan(
      id: 'floor-1',
      name: 'Этаж 1',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4000, yMm: 0),
        PlanNode(id: 'c', xMm: 4000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ],
    );
    final item = ObjectCatalog.byId('sofa-3');

    final placed = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: item,
      objectId: 'obj-test',
    );

    expect(floor.planObjects, hasLength(1));
    expect(placed.catalogId, item.id);
    expect(placed.label, item.name);
    expect(placed.widthMm, item.widthMm);
    expect(placed.depthMm, item.depthMm);
    expect(placed.heightMm, item.heightMm);
    expect(placed.xMm, 2000);
    expect(placed.yMm, 1500);

    final restored = FloorPlan.fromJson(floor.toJson());
    expect(restored.planObjects, hasLength(1));
    final restoredObject = restored.planObjects.single;
    expect(restoredObject.id, 'obj-test');
    expect(restoredObject.catalogId, 'sofa-3');
    expect(restoredObject.label, 'Диван 3-местный');
    expect(restoredObject.xMm, 2000);
    expect(restoredObject.yMm, 1500);
  });

  test('placed equipment can move rotate duplicate and delete persistently', () {
    final floor = FloorPlan(id: 'floor-1', name: 'Этаж 1');
    final source = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: ObjectCatalog.byId('armchair'),
      objectId: 'source',
    );

    EquipmentPlacementService.moveBy(source, dxMm: 250, dyMm: -100);
    EquipmentPlacementService.rotateBy(source, 450);
    expect(source.xMm, 250);
    expect(source.yMm, -100);
    expect(source.rotationDeg, 90);

    final copy = EquipmentPlacementService.duplicateObject(
      floor: floor,
      source: source,
      objectId: 'copy',
    );
    expect(floor.planObjects, hasLength(2));
    expect(copy.catalogId, source.catalogId);
    expect(copy.rotationDeg, source.rotationDeg);
    expect(copy.xMm, source.xMm + 160);
    expect(copy.yMm, source.yMm + 160);

    floor.electricalPoints.add(
      ElectricalPoint(
        id: 'fixture:${copy.id}',
        type: ElectricalPointType.ceilingLight,
        xMm: copy.xMm,
        yMm: copy.yMm,
      ),
    );
    expect(
      EquipmentPlacementService.removeObject(floor: floor, object: copy),
      isTrue,
    );
    expect(floor.planObjects.map((object) => object.id), ['source']);
    expect(floor.electricalPoints, isEmpty);

    final restored = FloorPlan.fromJson(floor.toJson());
    expect(restored.planObjects.single.rotationDeg, 90);
    expect(restored.planObjects.single.xMm, 250);
    expect(restored.planObjects.single.yMm, -100);

    final scene = ZamerSceneGeometry.fromFloor(restored);
    expect(scene.objects, hasLength(1));
    final sceneObject = scene.objects.single;
    expect(sceneObject.id, 'source');
    expect(sceneObject.catalogId, 'armchair');
    expect(sceneObject.xMm, 250);
    expect(sceneObject.yMm, -100);
    expect(sceneObject.rotationRad, closeTo(math.pi / 2, 0.0001));
  });
}
