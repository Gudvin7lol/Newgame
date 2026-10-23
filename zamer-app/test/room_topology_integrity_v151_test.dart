import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/node_move_constraint_service.dart';

FloorPlan crossedWalls({bool nearbyUnrelatedNode = false,
    bool protectedDoor = false}) {
  final floor = FloorPlan(id: 'crossings', name: 'Точный стык');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4100, yMm: 1500),
    PlanNode(id: 'c', xMm: 2013, yMm: -300),
    PlanNode(id: 'd', xMm: 2013, yMm: 2600),
  ]);
  if (nearbyUnrelatedNode) {
    floor.nodes.add(PlanNode(
      id: 'stranger', xMm: 2021, yMm: 1500 * 2013 / 4100 + 8,
    ));
  }
  floor.walls.addAll([
    PlanWall(id: 'diagonal', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'vertical', startNodeId: 'c', endNodeId: 'd',
      openings: protectedDoor
        ? [WallOpening(id: 'door', type: OpeningType.door,
            widthMm: 900, heightMm: 2100, offsetFromStartMm: 650)]
        : []),
  ]);
  return floor;
}

FloorPlan rectangularRoom() {
  return FloorPlan(id: 'room', name: 'Комната', nodes: [
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
}

void main() {
  test('fractional cross uses one exact vertex for four real wall edges', () {
    final floor = crossedWalls();
    GeometryService.normalizeIntersections(floor);
    final junctions = floor.nodes.where((n) => floor.nodeDegree(n.id) == 4)
        .toList();
    expect(junctions.length, 1);
    final junction = junctions.single;
    expect(junction.xMm, closeTo(2013, 1e-7));
    expect(junction.yMm, closeTo(1500 * 2013 / 4100, 1e-7));
    expect(floor.walls.length, 4);
    expect(floor.nodes.length, 5);
  });

  test('nearby unrelated node cannot replace the true intersection', () {
    final floor = crossedWalls(nearbyUnrelatedNode: true);
    GeometryService.normalizeIntersections(floor);
    expect(floor.nodeDegree('stranger'), 0);
    final junctions = floor.nodes.where((n) => floor.nodeDegree(n.id) == 4)
        .toList();
    expect(junctions.length, 1);
    expect(junctions.single.id, isNot('stranger'));
    expect(junctions.single.xMm, closeTo(2013, 1e-7));
    expect(junctions.single.yMm,
        closeTo(1500 * 2013 / 4100, 1e-7));
  });

  test('door blocks intersection normalization without partial wall cuts', () {
    final floor = crossedWalls(protectedDoor: true);
    final before = floor.toJson().toString();
    expect(() => GeometryService.normalizeIntersections(floor),
        throwsStateError);
    expect(floor.toJson().toString(), before);
    expect(floor.walls.length, 2);
    expect(floor.wallById('vertical')!.openings.single.id, 'door');
  });

  test('failed endpoint attachment restores exact pre-drag project', () {
    final floor = FloorPlan(id: 'door-join', name: 'Откат', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'x', xMm: 1511.25, yMm: 1300),
      PlanNode(id: 'tip', xMm: 1511.25, yMm: 2300),
    ], walls: [
      PlanWall(id: 'host', startNodeId: 'a', endNodeId: 'b',
        openings: [WallOpening(
          id: 'door', type: OpeningType.door, widthMm: 900,
          heightMm: 2100, offsetFromStartMm: 1000,
        )]),
      PlanWall(id: 'partition', startNodeId: 'x', endNodeId: 'tip'),
    ]);
    final before = floor.toJson().toString();
    expect(() => GeometryService.finalizeNodeMove(
      floor, movingNodeId: 'x', snap: NodeSnapResult(
        kind: NodeSnapKind.wall, targetWallId: 'host',
        point: const math.Point<double>(1511.25, 0),
      )), throwsStateError);
    expect(floor.toJson().toString(), before);
    expect(floor.nodeById('x')!.yMm, 1300);
    expect(floor.walls.length, 2);
  });

  test('dragging a shared rectangle corner keeps one closed room', () {
    final floor = rectangularRoom();
    final result = NodeMoveConstraintService.evaluate(
      floor, nodeId: 'a',
      destination: const math.Point<double>(450, 325),
    );
    expect(result.isValid, isTrue);
    expect(result.movedNodeIds, containsAll(['a', 'b', 'd']));
    NodeMoveConstraintService.apply(floor, result);
    expect(GeometryService.roomFaces(floor).length, 1);
    expect(floor.walls.length, 4);
    expect(floor.nodes.length, 4);
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId)!;
      final b = floor.nodeById(wall.endNodeId)!;
      expect((a.xMm - b.xMm).abs() <= .5 ||
          (a.yMm - b.yMm).abs() <= .5, isTrue,
          reason: 'no diagonal from a shared corner drag');
    }
  });
}
