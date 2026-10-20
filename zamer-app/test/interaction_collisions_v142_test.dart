import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/space_check_service.dart';
import 'package:zamer_app/services/wall_drawing_service.dart';

FloorPlan testFloor() {
  final floor = FloorPlan(id: 'f', name: 'Две комнаты');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
  ]);
  floor.walls.add(PlanWall(
    id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 100,
    openings: [
      WallOpening(id: 'd', type: OpeningType.door,
        widthMm: 1000, heightMm: 2100, offsetFromStartMm: 1500,
        doorSwing: DoorSwing.leftIn),
    ],
  ));
  return floor;
}

PlanObject box(String id, double x, double y,
    {double w = 300, double d = 300}) =>
    PlanObject(id: id, type: PlanObjectType.furniture,
      xMm: x, yMm: y, widthMm: w, depthMm: d, heightMm: 650);

void main() {
  test('doorway is passable, but solid wall to its side still blocks', () {
    final floor = testFloor();
    expect(SpaceCheckService.intersectsWall(floor, box('door', 2000, 0)),
      isFalse);
    expect(SpaceCheckService.intersectsWall(floor, box('solid', 1000, 0)),
      isTrue);
  });

  test('door swept quarter circle, not just a generic rectangular corridor', () {
    final floor = testFloor();
    floor.planObjects.add(box('blocked', 1950, 350, w: 140, d: 140));
    final issues = SpaceCheckService.inspect(floor);
    expect(issues.where((i) => i.kind == SpaceIssueKind.doorClearance &&
      i.objectIds.contains('blocked')), isNotEmpty);
    floor.planObjects.clear();
    floor.planObjects.add(box('clear', 1950, -350, w: 140, d: 140));
    expect(SpaceCheckService.inspect(floor).where((i) =>
      i.kind == SpaceIssueKind.doorClearance), isEmpty);
  });

  test('distant opposite corner is only suggested along an accurate axis', () {
    final floor = testFloor();
    floor.nodes.addAll([
      PlanNode(id: 'corner', xMm: 3000, yMm: 1000),
      PlanNode(id: 'above', xMm: 3000, yMm: 2200),
      PlanNode(id: 'right', xMm: 3900, yMm: 1000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'w2', startNodeId: 'corner', endNodeId: 'above'),
      PlanWall(id: 'w3', startNodeId: 'corner', endNodeId: 'right'),
    ]);
    expect(WallDrawingService.alignedCornerAhead(floor,
      startNodeId: 'a', currentPoint: const math.Point<double>(1800, 1000)),
      isNull);
    floor.nodes.add(PlanNode(id: 'origin', xMm: 0, yMm: 1000));
    expect(WallDrawingService.alignedCornerAhead(floor,
      startNodeId: 'origin', currentPoint: const math.Point<double>(1800, 1000)),
      const math.Point<double>(3000, 1000));
  });

  test('collisions and door geometry are visible by default in shared editor',
    () {
      final src = File('lib/screens/plan_editor_master_v4_screen.dart')
          .readAsStringSync();
      expect(src, contains('PlanCollisionKind.values.toSet()'));
      expect(src, contains('_selectedObjectId'));
      expect(src, contains('details.globalPosition'));
      expect(src, contains('_pinchInProgress'));
      expect(src, contains('const margin = 105.0;'));
    });
}
