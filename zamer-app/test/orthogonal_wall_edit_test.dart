import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/orthogonal_wall_edit_service.dart';

FloorPlan rectangularFloor() {
  final floor = FloorPlan(id: 'f', name: 'Rectangle');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'right', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'bottom', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'left', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return floor;
}

void main() {
  test('moving right wall retains all four right angles and shared vertices', () {
    final floor = rectangularFloor();
    final state = OrthogonalWallEditService.preview(
      floor,
      wallId: 'right',
      offsetMm: 500,
    );
    expect(state.isValid, isTrue, reason: state.message);
    final applied = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: 500,
    );
    expect(applied.isValid, isTrue);
    expect(floor.nodeById('a')!.xMm, 0);
    expect(floor.nodeById('b')!.xMm, 4500);
    expect(floor.nodeById('c')!.xMm, 4500);
    expect(floor.nodeById('d')!.xMm, 0);
    expect(floor.wallLengthMm(floor.wallById('right')!), 3000);
    expect(floor.wallLengthMm(floor.wallById('top')!), 4500);
    expect(floor.wallLengthMm(floor.wallById('bottom')!), 4500);
    final saved = FloorPlan.fromJson(floor.toJson());
    expect(saved.nodeById('b')!.xMm, 4500);
  });

  test('negative Y movement changes room height without diagonal walls', () {
    final floor = rectangularFloor();
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'bottom',
      offsetMm: -250,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodeById('c')!.yMm, 2750);
    expect(floor.nodeById('d')!.yMm, 2750);
    expect(floor.wallLengthMm(floor.wallById('left')!), 2750);
    expect(floor.wallLengthMm(floor.wallById('right')!), 2750);
  });

  test('too large move cannot invert room and is fully atomic', () {
    final floor = rectangularFloor();
    final original = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: -4100,
    );
    expect(result.isValid, isFalse);
    expect(floor.toJson().toString(), original);
  });

  test('T-junctions are rejected instead of silently deforming another room', () {
    final floor = rectangularFloor();
    floor.nodes.add(PlanNode(id: 'extra', xMm: 5200, yMm: 0));
    floor.walls.add(
      PlanWall(id: 'branch', startNodeId: 'b', endNodeId: 'extra'),
    );
    final original = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: 500,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('узел'));
    expect(floor.toJson().toString(), original);
  });

  test('moving wall into another wall is rejected', () {
    final floor = rectangularFloor();
    floor.nodes.addAll([
      PlanNode(id: 'e', xMm: 4700, yMm: -200),
      PlanNode(id: 'f', xMm: 4700, yMm: 3200),
    ]);
    floor.walls.add(
      PlanWall(id: 'obstacle', startNodeId: 'e', endNodeId: 'f'),
    );
    final original = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: 1000,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('пересечение'));
    expect(floor.toJson().toString(), original);
  });

  test('physical opening location is retained on adjacent resized wall', () {
    final floor = rectangularFloor();
    final opening = WallOpening(
      id: 'o',
      type: OpeningType.door,
      widthMm: 800,
      heightMm: 2100,
      offsetFromStartMm: 1000,
    );
    floor.wallById('bottom')!.openings.add(opening);
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: 500,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(opening.offsetFromStartMm, closeTo(1500, 0.001));
    expect(opening.offsetFromStartMm + opening.widthMm, lessThan(4500));
  });

  test('move is blocked if fixed door would be outside shortened wall', () {
    final floor = rectangularFloor();
    floor.wallById('bottom')!.openings.add(WallOpening(
      id: 'o',
      type: OpeningType.door,
      widthMm: 900,
      heightMm: 2100,
      offsetFromStartMm: 500,
    ));
    final original = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'right',
      offsetMm: -1000,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('окно'));
    expect(floor.toJson().toString(), original);
  });

  test('non-orthogonal wall or invalid input cannot be edited', () {
    final floor = rectangularFloor();
    floor.nodeById('c')!.xMm = 4070;
    final result = OrthogonalWallEditService.preview(
      floor,
      wallId: 'right',
      offsetMm: 200,
    );
    expect(result.isValid, isFalse);
    expect(OrthogonalWallEditService.preview(
      floor, wallId: 'right', offsetMm: double.nan,
    ).isValid, isFalse);
    expect(OrthogonalWallEditService.preview(
      floor, wallId: 'right', offsetMm: math.pow(10, 6).toDouble(),
    ).isValid, isFalse);
  });
}
