import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('wall midpoint is a geometric snap and creates a T-junction', () {
    final floor = FloorPlan(id: 'f', name: 'Test');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'moving', xMm: 1800, yMm: 1000),
      PlanNode(id: 'other', xMm: 1800, yMm: 2200),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'base', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'attached', startNodeId: 'moving', endNodeId: 'other'),
    ]);
    final snap = GeometryService.snapMoveTarget(
      floor,
      movingNodeId: 'moving',
      raw: const math.Point<double>(2005, 8),
      nodeThresholdMm: 80,
      wallThresholdMm: 100,
      guideThresholdMm: 0,
      angleStepRadians: 0,
      gridMm: 0,
    );
    expect(snap.kind, NodeSnapKind.midpoint);
    expect(snap.targetWallId, 'base');
    expect(snap.point.x, closeTo(2000, 0.001));
    expect(snap.point.y, closeTo(0, 0.001));
    final moved = GeometryService.finalizeNodeMove(
      floor,
      movingNodeId: 'moving',
      snap: snap,
    );
    expect(moved, isNotNull);
    expect(floor.nodeDegree(moved!.id), greaterThanOrEqualTo(3));
  });

  test('captured vertex is held until finger leaves release radius', () {
    final floor = FloorPlan(id: 'f', name: 'Test');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 180, yMm: 0),
      PlanNode(id: 'moving', xMm: 1000, yMm: 1000),
    ]);
    NodeSnapResult snap(math.Point<double> raw, {NodeSnapResult? previous}) =>
        GeometryService.snapMoveTarget(
          floor,
          movingNodeId: 'moving',
          raw: raw,
          nodeThresholdMm: 100,
          wallThresholdMm: 0,
          guideThresholdMm: 0,
          angleStepRadians: 0,
          gridMm: 0,
          releaseThresholdMm: 160,
          previousSnap: previous,
        );
    final captured = snap(const math.Point<double>(75, 0));
    expect(captured.targetNodeId, 'a');
    final held = snap(const math.Point<double>(103, 0), previous: captured);
    expect(held.targetNodeId, 'a');
    final released = snap(const math.Point<double>(205, 0), previous: held);
    expect(released.targetNodeId, 'b');
  });

  test('scaled world thresholds preserve equivalent screen capture radius', () {
    final floor = FloorPlan(id: 'f', name: 'Test');
    floor.nodes.addAll([
      PlanNode(id: 'target', xMm: 0, yMm: 0),
      PlanNode(id: 'moving', xMm: 3000, yMm: 3000),
    ]);
    NodeSnapResult snap(double rawMm, double zoom) =>
        GeometryService.snapMoveTarget(
          floor,
          movingNodeId: 'moving',
          raw: math.Point<double>(rawMm, 0),
          nodeThresholdMm: 140 / zoom,
          wallThresholdMm: 0,
          guideThresholdMm: 0,
          angleStepRadians: 0,
          gridMm: 0,
        );
    expect(snap(120, 1).targetNodeId, 'target');
    expect(snap(30, 4).targetNodeId, 'target');
    expect(snap(160, 1).targetNodeId, isNull);
    expect(snap(40, 4).targetNodeId, isNull);
  });
}
