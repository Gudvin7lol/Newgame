import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
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
}
