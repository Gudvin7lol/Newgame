import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('rectangle produces one inner room with wall thickness', () {
    final f = FloorPlan(id: 'f', name: 'F');
    final n1 = PlanNode(id: 'a', xMm: 0, yMm: 0);
    final n2 = PlanNode(id: 'b', xMm: 4000, yMm: 0);
    final n3 = PlanNode(id: 'c', xMm: 4000, yMm: 3000);
    final n4 = PlanNode(id: 'd', xMm: 0, yMm: 3000);
    f.nodes.addAll([n1, n2, n3, n4]);
    f.walls.addAll([
      PlanWall(
        id: 'w1',
        startNodeId: 'a',
        endNodeId: 'b',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w2',
        startNodeId: 'b',
        endNodeId: 'c',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w3',
        startNodeId: 'c',
        endNodeId: 'd',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w4',
        startNodeId: 'd',
        endNodeId: 'a',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
    ]);
    final faces = GeometryService.roomFaces(f);
    expect(faces.length, 1);
    expect(faces.first.areaM2, closeTo(9.99, 0.02));
  });

  test('partition crossing exterior walls creates two rooms', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    f.walls.addAll([
      PlanWall(
        id: 'w1',
        startNodeId: 'a',
        endNodeId: 'b',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w2',
        startNodeId: 'b',
        endNodeId: 'c',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w3',
        startNodeId: 'c',
        endNodeId: 'd',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
      PlanWall(
        id: 'w4',
        startNodeId: 'd',
        endNodeId: 'a',
        type: WallType.exterior,
        thicknessMm: 300,
      ),
    ]);
    final top = GeometryService.ensureAnchor(f, const math.Point(2000, 0));
    GeometryService.addWallFromNode(
      f,
      startNodeId: top.id,
      endPoint: const math.Point(2000, 3000),
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
    );
    final faces = GeometryService.roomFaces(f);
    expect(faces.length, 2);
    expect(faces.fold<double>(0, (s, e) => s + e.areaM2), greaterThan(9.5));
  });

  test(
    'free partition ends inside room and elevations use inside perimeter',
    () {
      final f = FloorPlan(id: 'f', name: 'F');
      f.nodes.addAll([
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 3000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ]);
      f.walls.addAll([
        PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b', thicknessMm: 100),
        PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c', thicknessMm: 100),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd', thicknessMm: 100),
        PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a', thicknessMm: 100),
      ]);
      final start = GeometryService.ensureAnchor(f, const math.Point(1500, 0));
      final end = GeometryService.addWallFromNode(
        f,
        startNodeId: start.id,
        endPoint: const math.Point(1500, 1200),
        type: WallType.partition,
        thicknessMm: 100,
        material: WallMaterial.drywall,
      );
      expect(end.yMm, closeTo(1200, 1));
      final room = GeometryService.roomFaces(f).single;
      expect(room.innerPolygon.length, room.edges.length);
      expect(room.innerPolygon.length, 5);
      expect(room.edges.any((edge) => edge.wallId ==
          f.walls.last.id), isFalse);
      expect(room.areaM2, closeTo(8.41, .01));
      final runs = GeometryService.elevationRuns(f, room);
      final innerLength = runs.fold<double>(0, (sum, r) => sum + r.lengthMm);
      expect(innerLength, closeTo(room.perimeterM * 1000, 1));
      expect(innerLength, lessThan(14400));
    },
  );
}
