import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/wall_drawing_service.dart';

void main() {
  test('a three-segment contour finishes at its original node', () {
    expect(WallDrawingService.closesChain(
      firstNodeId: 'first', endNodeId: 'first',
      completedSegments: 2, changed: true,
    ), isTrue);
    expect(WallDrawingService.closesChain(
      firstNodeId: 'first', endNodeId: 'first',
      completedSegments: 1, changed: true,
    ), isFalse);
    expect(WallDrawingService.closesChain(
      firstNodeId: 'first', endNodeId: 'other',
      completedSegments: 5, changed: true,
    ), isFalse);
    expect(WallDrawingService.closesChain(
      firstNodeId: 'first', endNodeId: 'first',
      completedSegments: 3, changed: false,
    ), isFalse);
  });

  test('closure magnet respects 90-degree lock and real world nodes', () {
    final floor = FloorPlan(id: 'f', name: 'Room', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 2400),
      PlanNode(id: 'd', xMm: 0, yMm: 2400),
    ], walls: [
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    ]);
    final last = WallDrawingService.snap(floor,
      startNodeId: 'd', raw: const math.Point<double>(11, 23),
      angleStepDegrees: 90, nodeCaptureMm: 80,
      wallCaptureMm: 60, priorityNodeId: 'a');
    expect(last.targetNodeId, 'a');
    expect(last.point, const math.Point<double>(0, 0));
  });

  test('closure magnet never pulls a node off the locked axis', () {
    final floor = FloorPlan(id: 'f', name: 'Room', nodes: [
      PlanNode(id: 'initial', xMm: 45, yMm: 0),
      PlanNode(id: 'last', xMm: 0, yMm: 2400),
    ]);
    final snap = WallDrawingService.snap(floor,
      startNodeId: 'last', raw: const math.Point<double>(5, 10),
      angleStepDegrees: 90, nodeCaptureMm: 80,
      wallCaptureMm: 40, priorityNodeId: 'initial');
    expect(snap.targetNodeId, isNull);
    expect(snap.point.x, closeTo(0, .0001));
  });
}
