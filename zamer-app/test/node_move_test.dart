import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';

FloorPlan baseFloor() {
  final f = FloorPlan(id: 'f', name: 'F');
  f.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  f.walls.addAll([
    PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b', type: WallType.exterior, thicknessMm: 300),
    PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c', type: WallType.exterior, thicknessMm: 300),
    PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd', type: WallType.exterior, thicknessMm: 300),
    PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a', type: WallType.exterior, thicknessMm: 300),
  ]);
  return f;
}

void main() {
  test('moving node snaps to another node and merges topology', () {
    final f = baseFloor();
    f.nodes.add(PlanNode(id: 'x', xMm: 2500, yMm: 1500));
    f.walls.add(PlanWall(id: 'wx', startNodeId: 'x', endNodeId: 'c', thicknessMm: 100));

    final snap = GeometryService.snapMoveTarget(
      f,
      movingNodeId: 'x',
      raw: const math.Point(3980, 20),
      enabled: true,
      angleStepRadians: 0,
    );
    expect(snap.kind, NodeSnapKind.node);
    expect(snap.targetNodeId, 'b');

    GeometryService.finalizeNodeMove(f, movingNodeId: 'x', snap: snap);
    expect(f.nodeById('x'), isNull);
    expect(f.walls.any((w) => w.startNodeId == 'b' || w.endNodeId == 'b'), isTrue);
  });

  test('moving node onto wall creates a real junction', () {
    final f = baseFloor();
    f.nodes.add(PlanNode(id: 'x', xMm: 2000, yMm: 1600));
    f.walls.add(PlanWall(id: 'wx', startNodeId: 'x', endNodeId: 'c', thicknessMm: 100));

    final snap = GeometryService.snapMoveTarget(
      f,
      movingNodeId: 'x',
      raw: const math.Point(2020, 30),
      enabled: true,
      angleStepRadians: 0,
    );
    expect(snap.kind, NodeSnapKind.wall);
    expect(snap.targetWallId, 'w1');

    final moved = GeometryService.finalizeNodeMove(f, movingNodeId: 'x', snap: snap);
    expect(moved, isNotNull);
    expect(moved!.yMm, closeTo(0, 0.1));
    expect(f.nodeDegree(moved.id), greaterThanOrEqualTo(3));
  });

  test('orthogonal guide keeps connected wall at 90 degrees', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 1000),
    ]);
    f.walls.add(PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b'));

    final snap = GeometryService.snapMoveTarget(
      f,
      movingNodeId: 'b',
      raw: const math.Point(2050, 70),
      enabled: true,
      angleStepRadians: math.pi / 2,
      nodeThresholdMm: 10,
      wallThresholdMm: 10,
    );
    expect(snap.kind, NodeSnapKind.ortho);
    expect(snap.point.y, closeTo(0, 0.1));
  });
}
