import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('parallel reference joins a split 4800 mm opposite wall', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    final start = PlanNode(id: 'start', xMm: 0, yMm: 0);
    final a = PlanNode(id: 'a', xMm: 0, yMm: 3000);
    final split = PlanNode(id: 'split', xMm: 1970, yMm: 3000);
    final b = PlanNode(id: 'b', xMm: 4800, yMm: 3000);
    floor.nodes.addAll([start, a, split, b]);
    floor.walls.addAll([
      PlanWall(id: 'opposite-a', startNodeId: 'a', endNodeId: 'split'),
      PlanWall(id: 'opposite-b', startNodeId: 'split', endNodeId: 'b'),
    ]);

    final result = GeometryService.parallelReferenceLength(floor, start, 0);
    expect(result, isNotNull);
    expect(result!, closeTo(4800, 0.01));
  });

  test('parallel reference keeps the opposite wall inside the active room', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'start', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
      PlanNode(id: 'outside-a', xMm: 0, yMm: -500),
      PlanNode(id: 'outside-b', xMm: 1200, yMm: -500),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'start', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'start'),
      PlanWall(
        id: 'outside',
        startNodeId: 'outside-a',
        endNodeId: 'outside-b',
      ),
    ]);

    expect(
      GeometryService.parallelReferenceLength(floor, floor.nodes.first, 0),
      closeTo(4000, 0.01),
    );
  });

  test('parallel reference ignores a non-parallel nearby fragment', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    final start = PlanNode(id: 'start', xMm: 0, yMm: 0);
    floor.nodes.addAll([
      start,
      PlanNode(id: 'a', xMm: 0, yMm: 2500),
      PlanNode(id: 'b', xMm: 4800, yMm: 2500),
      PlanNode(id: 'c', xMm: 400, yMm: 300),
      PlanNode(id: 'd', xMm: 400, yMm: 2270),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'good', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'wrong-1970', startNodeId: 'c', endNodeId: 'd'),
    ]);

    final result = GeometryService.parallelReferenceLength(floor, start, 0);
    expect(result!, closeTo(4800, 0.01));
  });

  test('opposite wall ignores a closer parallel wall in the next wing', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'start', xMm: 0, yMm: 0),
      PlanNode(id: 'a', xMm: 1800, yMm: 600),
      PlanNode(id: 'b', xMm: 3400, yMm: 600),
      PlanNode(id: 'c', xMm: 0, yMm: 2790),
      PlanNode(id: 'd', xMm: 3190, yMm: 2790),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'neighbour', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'opposite', startNodeId: 'c', endNodeId: 'd'),
    ]);
    expect(
      GeometryService.parallelReferenceLength(floor, floor.nodes.first, 0),
      closeTo(3190, 0.01),
    );
  });

  test('dangling partition remains a wall but cannot cut room floor', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 1500, yMm: 3000),
      PlanNode(id: 'e', xMm: 0, yMm: 3000),
      PlanNode(id: 'tip', xMm: 1500, yMm: 1900),
      PlanNode(id: 'tip2', xMm: 1800, yMm: 1800),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
      PlanWall(id: 'ea', startNodeId: 'e', endNodeId: 'a'),
      PlanWall(id: 'partition', startNodeId: 'd', endNodeId: 'tip'),
      PlanWall(id: 'branch', startNodeId: 'tip', endNodeId: 'tip2'),
    ]);
    final rooms = GeometryService.roomFaces(floor);
    expect(rooms, hasLength(1));
    expect(
      rooms.single.edges.map((e) => e.wallId),
      isNot(contains('partition')),
    );
    expect(rooms.single.edges.map((e) => e.wallId), isNot(contains('branch')));
    expect(rooms.single.areaM2, closeTo(8.41, 0.1));
  });

  test('opposite wall length stops at the boundary of the selected room', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 6000, yMm: 0),
      PlanNode(id: 'd', xMm: 6000, yMm: 3000),
      PlanNode(id: 'e', xMm: 3000, yMm: 3000),
      PlanNode(id: 'f', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
      PlanWall(id: 'ef', startNodeId: 'e', endNodeId: 'f'),
      PlanWall(id: 'fa', startNodeId: 'f', endNodeId: 'a'),
      PlanWall(id: 'be', startNodeId: 'b', endNodeId: 'e'),
    ]);
    expect(
      GeometryService.parallelReferenceLength(floor, floor.nodes.first, 0),
      closeTo(3000, 0.01),
    );
  });

  test('per-wall tile state survives project serialization', () {
    final settings = RoomMaterialSettings()
      ..wallTile = true
      ..wallTileRunEnabled['wall-a'] = true
      ..wallTileRunEnabled['wall-b'] = false
      ..wallTileRunOffsetX['wall-a'] = 125;

    final restored = RoomMaterialSettings.fromJson(settings.toJson());
    expect(restored.wallTileEnabledFor('wall-a'), isTrue);
    expect(restored.wallTileEnabledFor('wall-b'), isFalse);
    expect(restored.wallTileXFor('wall-a'), closeTo(125, 0.001));
  });

  test('geometry distance remains stable after v1 changes', () {
    final a = PlanNode(id: 'a', xMm: 0, yMm: 0);
    final b = PlanNode(id: 'b', xMm: 3000, yMm: 4000);
    expect(GeometryService.distance(a, b), closeTo(5000, 0.001));
    expect(math.atan2(b.yMm - a.yMm, b.xMm - a.xMm), greaterThan(0));
  });
}
