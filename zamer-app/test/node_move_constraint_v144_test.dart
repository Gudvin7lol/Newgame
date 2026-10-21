import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/node_move_constraint_service.dart';

FloorPlan rectangle() => FloorPlan(id: 'f', name: 'Room', nodes: [
  PlanNode(id: 'a', xMm: 0, yMm: 0),
  PlanNode(id: 'b', xMm: 4000, yMm: 0),
  PlanNode(id: 'c', xMm: 4000, yMm: 3000),
  PlanNode(id: 'd', xMm: 0, yMm: 3000),
], walls: [
  PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
  PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
  PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
  PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
]);

void main() {
  test('moving rectangle corner updates connected axes, not diagonal walls',
      () {
    final f = rectangle();
    final before = FloorPlan.fromJson(f.toJson());
    final preview = NodeMoveConstraintService.evaluate(
      before, nodeId: 'a',
      destination: const math.Point<double>(500, 600),
    );
    expect(preview.isValid, isTrue);
    expect(preview.movedNodeIds, containsAll(['a', 'b', 'd']));
    NodeMoveConstraintService.apply(f, preview);
    expect(f.nodeById('a')!.xMm, 500);
    expect(f.nodeById('a')!.yMm, 600);
    expect(f.nodeById('b')!.xMm, 4000);
    expect(f.nodeById('b')!.yMm, 600);
    expect(f.nodeById('d')!.xMm, 500);
    expect(f.nodeById('d')!.yMm, 3000);
    for (final wall in f.walls) {
      final a = f.nodeById(wall.startNodeId)!;
      final b = f.nodeById(wall.endNodeId)!;
      expect((a.xMm - b.xMm).abs() < 1 ||
          (a.yMm - b.yMm).abs() < 1, isTrue,
          reason: 'right angles must not turn into triangles');
    }
  });

  test('rejects a drag that collapses a room side below 120 mm', () {
    final f = rectangle();
    final result = NodeMoveConstraintService.evaluate(
      f, nodeId: 'a',
      destination: const math.Point<double>(3950, 0),
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('120'));
  });

  test('rejects new cross-wall intersections, no partial mutation', () {
    final f = rectangle();
    f.nodes.addAll([
      PlanNode(id: 'e', xMm: 4300, yMm: 1000),
      PlanNode(id: 'g', xMm: 6000, yMm: 1000),
    ]);
    f.walls.add(PlanWall(id: 'eg',
      startNodeId: 'e', endNodeId: 'g'));
    final initial = f.toJson().toString();
    final result = NodeMoveConstraintService.evaluate(
      f, nodeId: 'b',
      destination: const math.Point<double>(5500, 0),
    );
    expect(result.isValid, isFalse);
    expect(f.toJson().toString(), initial);
  });

  test('diagonal and curved wall geometry are protected from node drag', () {
    final f = rectangle();
    f.nodes.add(PlanNode(id: 'e', xMm: 600, yMm: -400));
    f.walls.add(PlanWall(id: 'oblique',
      startNodeId: 'a', endNodeId: 'e'));
    final result = NodeMoveConstraintService.evaluate(
      f, nodeId: 'a',
      destination: const math.Point<double>(500, 200),
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('Косые'));
  });
}
