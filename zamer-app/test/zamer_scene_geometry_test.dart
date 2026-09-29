import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';

void main() {
  test('straight wall is cut around a door and opening is exported to 3D', () {
    final floor = FloorPlan(id: 'f', name: 'Test', defaultHeightMm: 2700)
      ..nodes.addAll(<PlanNode>[
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4000, yMm: 0),
        PlanNode(id: 'c', xMm: 4000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ])
      ..walls.addAll(<PlanWall>[
        PlanWall(
          id: 'w1',
          startNodeId: 'a',
          endNodeId: 'b',
          openings: <WallOpening>[
            WallOpening(
              id: 'door',
              type: OpeningType.door,
              widthMm: 900,
              heightMm: 2100,
              offsetFromStartMm: 1200,
            ),
          ],
        ),
        PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
      ]);

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final door = scene.openings.singleWhere((o) => o.id == 'door');
    final pieces = scene.walls.where((w) => w.wallId == 'w1').toList();

    expect(scene.floors, isNotEmpty);
    expect(door.type, OpeningType.door);
    expect(door.xMm, closeTo(1650, 0.001));
    expect(door.yMm, closeTo(0, 0.001));
    expect(pieces, hasLength(3));
    expect(
      pieces.fold<double>(0, (sum, p) => sum + p.lengthMm * p.heightMm),
      closeTo(4000 * 2700 - 900 * 2100, 1),
    );
  });

  test('electrical wall device keeps wall direction and mounting height', () {
    final floor = FloorPlan(id: 'f', name: 'Electrical')
      ..nodes.addAll(<PlanNode>[
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
      ])
      ..walls.add(
        PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 120),
      )
      ..electricalPoints.add(
        ElectricalPoint(
          id: 's',
          type: ElectricalPointType.socket,
          xMm: 900,
          yMm: 0,
          heightMm: 300,
          wallId: 'w',
          wallSide: 1,
        ),
      );

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final point = scene.electrical.single;
    expect(point.heightMm, 300);
    expect(point.wallThicknessMm, 120);
    expect(point.rotationRad, closeTo(0, 0.0001));
  });

  test('room finish settings propagate into 3D floor and wall geometry', () {
    final floor = FloorPlan(id: 'finish', name: 'Finish test')
      ..nodes.addAll(<PlanNode>[
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4000, yMm: 0),
        PlanNode(id: 'c', xMm: 4000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ])
      ..walls.addAll(<PlanWall>[
        PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
      ]);

    // The geometry factory synchronises room metadata. Call once, customise
    // the generated room, then rebuild to verify the renderer sees it.
    final initial = ZamerSceneGeometry.fromFloor(floor);
    expect(initial.floors, hasLength(1));
    final meta = floor.roomMetas.single;
    meta.materials
      ..floorMode = 'tile'
      ..floorMaterialId = 'tile-concrete'
      ..floorDirectionDeg = 90
      ..tileWidthMm = 1200
      ..tileHeightMm = 600
      ..wallMaterialId = 'paint-sage'
      ..wallTile = true
      ..wallTileMaterialId = 'tile-marble';

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final surface = scene.floors.single;
    expect(surface.materialMode, 'tile');
    expect(surface.materialId, 'tile-concrete');
    expect(surface.directionDeg, 90);
    expect(surface.tileWidthMm, 1200);
    expect(surface.tileHeightMm, 600);
    expect(scene.walls, isNotEmpty);
    expect(scene.walls.every((wall) => wall.tileEnabled), isTrue);
    expect(scene.walls.every((wall) => wall.tileMaterialId == 'tile-marble'), isTrue);
  });

  test('plan object keeps its authored orientation at the 3D geometry boundary', () {
    final floor = FloorPlan(id: 'orientation', name: 'Orientation')
      ..planObjects.addAll(<PlanObject>[
        PlanObject(
          id: 'bed-90',
          type: PlanObjectType.furniture,
          catalogId: 'bed-160',
          xMm: 1200,
          yMm: 900,
          widthMm: 1700,
          depthMm: 2100,
          heightMm: 950,
          rotationDeg: 90,
        ),
        PlanObject(
          id: 'bed-270',
          type: PlanObjectType.furniture,
          catalogId: 'bed-160',
          xMm: 3200,
          yMm: 900,
          widthMm: 1700,
          depthMm: 2100,
          heightMm: 950,
          rotationDeg: 270,
        ),
      ]);

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final bed90 = scene.objects.singleWhere((o) => o.id == 'bed-90');
    final bed270 = scene.objects.singleWhere((o) => o.id == 'bed-270');

    expect(bed90.rotationRad, closeTo(math.pi / 2, 0.0001));
    expect(bed270.rotationRad, closeTo(3 * math.pi / 2, 0.0001));
  });

  test('fixture electrical marker is not duplicated beside the 3D light object', () {
    final floor = FloorPlan(id: 'lights', name: 'Lights')
      ..planObjects.add(
        PlanObject(
          id: 'lamp',
          type: PlanObjectType.lighting,
          xMm: 1500,
          yMm: 1200,
          widthMm: 500,
          depthMm: 180,
          heightMm: 220,
          elevationMm: 1800,
          catalogId: 'wall-sconce-round',
        ),
      )
      ..electricalPoints.add(
        ElectricalPoint(
          id: 'legacy-light-point',
          type: ElectricalPointType.wallLight,
          xMm: 1510,
          yMm: 1205,
          heightMm: 1900,
        ),
      );

    final scene = ZamerSceneGeometry.fromFloor(floor);
    expect(scene.objects.where((o) => o.type == PlanObjectType.lighting), hasLength(1));
    expect(scene.electrical.where((e) => e.type == ElectricalPointType.wallLight), isEmpty);
  });
}
