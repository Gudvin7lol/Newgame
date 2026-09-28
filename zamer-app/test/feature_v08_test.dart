import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  test('v0.8 project layers and planning objects survive JSON round trip', () {
    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
    ]);
    floor.walls.add(PlanWall(
      id: 'w',
      startNodeId: 'a',
      endNodeId: 'b',
      projectLayer: ProjectLayer.demolition,
      demolition: true,
    ));
    floor.planObjects.add(PlanObject(
      id: 'obj',
      type: PlanObjectType.radiator,
      xMm: 1200,
      yMm: 300,
      widthMm: 900,
      depthMm: 120,
      heightMm: 600,
      elevationMm: 150,
      layer: ProjectLayer.proposed,
      slopePct: 1.5,
    ));

    final restored = FloorPlan.fromJson(floor.toJson());
    expect(restored.walls.single.projectLayer, ProjectLayer.demolition);
    expect(restored.walls.single.demolition, isTrue);
    expect(restored.planObjects.single.type, PlanObjectType.radiator);
    expect(restored.planObjects.single.layer, ProjectLayer.proposed);
    expect(restored.planObjects.single.slopePct, 1.5);
  });

  test('v0.8 visual material ids and wall-run tile offsets survive JSON round trip', () {
    final settings = RoomMaterialSettings(
      floorMaterialId: 'oak-smoked',
      wallMaterialId: 'paint-sage',
      wallTileMaterialId: 'tile-marble',
      wallTileRunOffsetX: {'curve-1': 145},
      wallTileRunOffsetY: {'curve-1': 280},
    );

    final restored = RoomMaterialSettings.fromJson(settings.toJson());
    expect(restored.floorMaterialId, 'oak-smoked');
    expect(restored.wallMaterialId, 'paint-sage');
    expect(restored.wallTileMaterialId, 'tile-marble');
    expect(restored.wallTileXFor('curve-1'), 145);
    expect(restored.wallTileYFor('curve-1'), 280);
    expect(MaterialCatalog.byId(restored.floorMaterialId).id, 'oak-smoked');
  });

  test('wall devices include panel and appliance and can store multi-module frame', () {
    final point = ElectricalPoint(
      id: 'e',
      type: ElectricalPointType.frame,
      xMm: 100,
      yMm: 100,
      wallId: 'w',
      wallOffsetMm: 500,
      heightMm: 300,
      modules: [
        ElectricalModuleType.socket220,
        ElectricalModuleType.socket220,
        ElectricalModuleType.tv,
        ElectricalModuleType.data,
      ],
    );
    expect(point.isWallDevice, isTrue);
    final restored = ElectricalPoint.fromJson(point.toJson());
    expect(restored.modules.length, 4);
    expect(restored.modules.last, ElectricalModuleType.data);
  });
}
