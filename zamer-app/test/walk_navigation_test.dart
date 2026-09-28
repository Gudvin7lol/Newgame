import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/walk_navigation_service.dart';

void main() {
  final floor = FloorPlan(id: 'walk', name: 'Two rooms');
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

  test('walk keeps the eye away from solid walls but crosses a door', () {
    const start = math.Point<double>(1000, 1250);
    expect(WalkNavigationService.canStand(floor, start), isTrue);
    expect(
      WalkNavigationService.canStand(
        floor,
        const math.Point<double>(1850, 300),
      ),
      isFalse,
    );
    final throughDoor = WalkNavigationService.advance(
      floor,
      start,
      math.pi / 2,
      1600,
      0,
    );
    expect(throughDoor.x, greaterThan(2300));
    final intoWall = WalkNavigationService.advance(floor, start, 0, -1500, 0);
    expect(intoWall.y, greaterThanOrEqualTo(300));
  });

  test('furniture blocks walking and starting position is walkable', () {
    floor.planObjects.add(
      PlanObject(
        id: 'cabinet',
        type: PlanObjectType.furniture,
        xMm: 3200,
        yMm: 1250,
        widthMm: 600,
        depthMm: 600,
      ),
    );
    final p = WalkNavigationService.startingPoint(floor);
    expect(WalkNavigationService.canStand(floor, p), isTrue);
    final approached = WalkNavigationService.advance(
      floor,
      const math.Point<double>(2200, 1250),
      math.pi / 2,
      1300,
      0,
    );
    expect(approached.x, lessThanOrEqualTo(2650));
  });

  test('diagonal movement slides along a wall instead of freezing', () {
    final moved = WalkNavigationService.advance(
      floor,
      const math.Point<double>(1000, 400),
      math.pi / 2,
      800,
      800,
    );

    expect(moved.y, greaterThanOrEqualTo(300));
    expect(moved.x, greaterThan(1600));
  });

  test('noclip can cross walls and furniture for inspection', () {
    const start = math.Point<double>(1000, 1250);
    final moved = WalkNavigationService.advance(
      floor,
      start,
      -math.pi / 2,
      1600,
      0,
      ignoreCollisions: true,
    );
    expect(moved.x, lessThan(0));
  });
}
