import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/layout_service.dart';
import 'package:zamer_app/services/floor_continuity_service.dart';

void main() {
  test(
    'selected rooms retain one world origin and floor format after save',
    () {
      final floor = FloorPlan(id: 'f', name: 'F');
      floor.nodes.addAll([
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 6000, yMm: 0),
        PlanNode(id: 'd', xMm: 6000, yMm: 3000),
        PlanNode(id: 'e', xMm: 3000, yMm: 3000),
        PlanNode(id: 'g', xMm: 0, yMm: 3000),
      ]);
      floor.walls.addAll([
        PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
        PlanWall(id: 'eg', startNodeId: 'e', endNodeId: 'g'),
        PlanWall(id: 'ga', startNodeId: 'g', endNodeId: 'a'),
        PlanWall(id: 'be', startNodeId: 'b', endNodeId: 'e'),
      ]);
      GeometryService.syncRoomMetadata(floor);
      final faces = GeometryService.roomFaces(floor);
      expect(faces.length, 2);
      floor.carpetRoomIds.addAll(floor.roomMetas.map((e) => e.id));
      floor.carpetAnchorX = faces.first.centroid.x;
      floor.carpetAnchorY = faces.first.centroid.y;
      final first = floor.roomMetaByKey(faces.first.key)!.materials;
      final second = floor.roomMetaByKey(faces.last.key)!.materials;
      first.laminateOffsetXMm = 115;
      first.laminatePlankLengthMm = 1220;
      LayoutService.copyFloorPattern(first, second);
      final restored = FloorPlan.fromJson(floor.toJson());
      expect(restored.carpetRoomIds.length, 2);
      expect(restored.roomMetas.last.materials.laminateOffsetXMm, 115);
      final bounds = LayoutService.groupBounds(
        faces,
        0,
        math.Point(floor.carpetAnchorX, floor.carpetAnchorY),
      );
      expect(bounds.maxX - bounds.minX, greaterThan(5500));
    },
  );

  test('only a shared low door opening receives continuous flooring', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 0),
      PlanNode(id: 'd', xMm: 4000, yMm: 2500),
      PlanNode(id: 'e', xMm: 2000, yMm: 2500),
      PlanNode(id: 'f', xMm: 0, yMm: 2500),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
      PlanWall(id: 'ef', startNodeId: 'e', endNodeId: 'f'),
      PlanWall(id: 'fa', startNodeId: 'f', endNodeId: 'a'),
      PlanWall(
        id: 'be',
        startNodeId: 'b',
        endNodeId: 'e',
        thicknessMm: 120,
        openings: [
          WallOpening(
            id: 'door',
            type: OpeningType.door,
            widthMm: 900,
            heightMm: 2100,
            offsetFromStartMm: 800,
          ),
        ],
      ),
    ]);
    final faces = GeometryService.roomFaces(floor);
    expect(faces.length, 2);
    final quads = FloorContinuityService.doorThresholds(floor, faces);
    expect(quads, hasLength(1));
    expect(quads.single.map((p) => p.x).reduce(math.min), lessThan(2000));
    expect(quads.single.map((p) => p.x).reduce(math.max), greaterThan(2000));
    expect(
      quads.single.map((p) => p.y).reduce(math.max) -
          quads.single.map((p) => p.y).reduce(math.min),
      closeTo(900, 1),
    );
    expect(
      FloorContinuityService.doorThresholds(floor, [faces.first]),
      isEmpty,
    );
  });
}
