import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/orthogonal_wall_edit_service.dart';
import 'package:zamer_app/services/geometry_service.dart';

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
    // A parallel branch is a four-way/collinear constraint problem,
    // not a shared orthogonal partition end.
    floor.nodes.add(PlanNode(id: 'extra', xMm: 4000, yMm: -900));
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

  test('two rooms share a partition and resize together without losing faces', () {
    final floor = FloorPlan(id: 'f', name: 'Two rooms');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 7000, yMm: 0),
      PlanNode(id: 'd', xMm: 7000, yMm: 3000),
      PlanNode(id: 'e', xMm: 4000, yMm: 3000),
      PlanNode(id: 'f', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'top-left', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'top-right', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'right', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'bottom-right', startNodeId: 'd', endNodeId: 'e'),
      PlanWall(id: 'bottom-left', startNodeId: 'e', endNodeId: 'f'),
      PlanWall(id: 'left', startNodeId: 'f', endNodeId: 'a'),
      PlanWall(id: 'shared', startNodeId: 'b', endNodeId: 'e'),
    ]);
    final electricalOnShared = ElectricalPoint(
      id: 'shared-socket',
      type: ElectricalPointType.socket,
      xMm: 4000,
      yMm: 1200,
      wallId: 'shared',
      wallOffsetMm: 1200,
    );
    final electricalRightSide = ElectricalPoint(
      id: 'right-socket',
      type: ElectricalPointType.socket,
      xMm: 5500,
      yMm: 0,
      wallId: 'top-right',
      wallOffsetMm: 1500,
    );
    final unattached = PlanObject(
      id: 'chair',
      type: PlanObjectType.furniture,
      xMm: 5500,
      yMm: 1500,
    );
    floor.electricalPoints.addAll([electricalOnShared, electricalRightSide]);
    floor.planObjects.add(unattached);
    final beforeFaces = GeometryService.roomFaces(floor);
    expect(beforeFaces.length, 2);

    final preview = OrthogonalWallEditService.preview(
      floor,
      wallId: 'shared',
      offsetMm: 500,
    );
    expect(preview.isValid, isTrue, reason: preview.message);
    final result = OrthogonalWallEditService.move(
      floor,
      wallId: 'shared',
      offsetMm: 500,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodeById('b')!.xMm, 4500);
    expect(floor.nodeById('e')!.xMm, 4500);
    expect(floor.nodeDegree('b'), 3);
    expect(floor.nodeDegree('e'), 3);
    expect(floor.wallLengthMm(floor.wallById('top-left')!), 4500);
    expect(floor.wallLengthMm(floor.wallById('top-right')!), 2500);
    expect(floor.wallLengthMm(floor.wallById('bottom-left')!), 4500);
    expect(floor.wallLengthMm(floor.wallById('bottom-right')!), 2500);
    expect(GeometryService.roomFaces(floor).length, 2);

    expect(electricalOnShared.xMm, 4500);
    expect(electricalOnShared.yMm, 1200);
    expect(electricalOnShared.wallOffsetMm, 1200);
    expect(electricalRightSide.xMm, closeTo(5500, 0.001));
    expect(electricalRightSide.wallOffsetMm, closeTo(1000, 0.001));
    expect(unattached.xMm, 5500);
    expect(unattached.yMm, 1500);

    final reloaded = FloorPlan.fromJson(floor.toJson());
    expect(reloaded.nodeDegree('e'), 3);
    expect(GeometryService.roomFaces(reloaded).length, 2);
  });

  test('shared partition cannot consume adjacent room wall with a door', () {
    final floor = FloorPlan(id: 'f', name: 'Two rooms');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 7000, yMm: 0),
      PlanNode(id: 'd', xMm: 7000, yMm: 3000),
      PlanNode(id: 'e', xMm: 4000, yMm: 3000),
      PlanNode(id: 'f', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c',
        openings: [
          WallOpening(id: 'door', type: OpeningType.door,
            widthMm: 800, heightMm: 2100, offsetFromStartMm: 300),
        ]),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
      PlanWall(id: 'ef', startNodeId: 'e', endNodeId: 'f'),
      PlanWall(id: 'fa', startNodeId: 'f', endNodeId: 'a'),
      PlanWall(id: 'be', startNodeId: 'b', endNodeId: 'e'),
    ]);
    final snapshot = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor, wallId: 'be', offsetMm: 600,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('окно'));
    expect(floor.toJson().toString(), snapshot);
  });

  test('wall-attached device blocks shortening that pushes it off the wall', () {
    final floor = rectangularFloor();
    floor.electricalPoints.add(
      ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 3600, yMm: 0, wallId: 'top', wallOffsetMm: 3600),
    );
    final snapshot = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
      floor, wallId: 'right', offsetMm: -1000,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('Электроточка'));
    expect(floor.toJson().toString(), snapshot);
  });

  test('unattached electrical fixtures are not moved silently', () {
    final floor = rectangularFloor();
    final point = ElectricalPoint(
      id: 'ceiling', type: ElectricalPointType.ceilingLight,
      xMm: 2000, yMm: 1500,
    );
    floor.electricalPoints.add(point);
    expect(OrthogonalWallEditService.move(
      floor, wallId: 'right', offsetMm: 500,
    ).isValid, isTrue);
    expect(point.xMm, 2000);
    expect(point.yMm, 1500);
  });

}
