import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/doorway_floor_service.dart';

RoomFace face(String key, double top, double bottom) => RoomFace(
  key: key,
  nodeIds: const [],
  edges: const [],
  signedAreaMm2: 1000000,
  innerPolygon: [
    math.Point<double>(0, top),
    math.Point<double>(3000, top),
    math.Point<double>(3000, bottom),
    math.Point<double>(0, bottom),
  ],
);

void main() {
  test('floor transition is exactly 20 mm beyond swing-side wall face', () {
    final wall = PlanWall(
      id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 100,
    );
    final door = WallOpening(
      id: 'd', type: OpeningType.door, widthMm: 900,
      heightMm: 2100, offsetFromStartMm: 1000,
    );
    expect(DoorwayFloorService.jointFromWallAxisMm(wall, door), 30);
    door.doorSwing = DoorSwing.rightIn;
    expect(DoorwayFloorService.jointFromWallAxisMm(wall, door), 30);
    door.doorSwing = DoorSwing.leftOut;
    expect(DoorwayFloorService.jointFromWallAxisMm(wall, door), -30);
    door.doorSwing = DoorSwing.rightOut;
    expect(DoorwayFloorService.jointFromWallAxisMm(wall, door), -30);
    wall.thicknessMm = 300;
    expect(DoorwayFloorService.jointFromWallAxisMm(wall, door), -130);
  });

  test('adjacent room lookup samples both sides of the real opening', () {
    final floor = FloorPlan(id: 'f', name: 'Two rooms');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
    ]);
    final wall = PlanWall(
      id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 100,
    );
    final door = WallOpening(
      id: 'd', type: OpeningType.door, widthMm: 900,
      heightMm: 2100, offsetFromStartMm: 1000,
    );
    floor.walls.add(wall);
    final plus = face('plus', 50, 1000);
    final minus = face('minus', -1000, -50);
    final rooms = DoorwayFloorService.roomsByDoor(
      floor, wall, door, [plus, minus],
    );
    expect(rooms.positive?.key, 'plus');
    expect(rooms.negative?.key, 'minus');
    expect(DoorwayFloorService.continuous(
      floor, rooms.positive, rooms.negative,
    ), isFalse);
  });

  test('door drawing and gesture controls remain on the common canvas', () {
    final painter = File('lib/widgets/cad_plan_painter_v2.dart')
        .readAsStringSync();
    final screen = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(painter, contains('DoorwayFloorService.roomsByDoor'));
    expect(painter, contains('DoorwayFloorService.jointFromWallAxisMm'));
    expect(painter, contains('final hinge = isRight ? p2 : p1;'));
    expect(painter, isNot(contains('..color = ZamerColors.background\n          ..strokeWidth = wallWidth')));
    expect(screen, contains('void _edgePanTick()'));
    expect(screen, contains('void _openingDragUpdate('));
    expect(screen, contains('Future<void> _editOpening('));
    expect(screen, contains('wall-camera-navigation'));
  });
}
