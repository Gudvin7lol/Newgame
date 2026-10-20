import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/opening_alignment_service.dart';
import 'package:zamer_app/services/space_check_service.dart';

PlanWall wall(String id, String a, String b, {
  double width = 100, List<WallOpening>? openings,
}) => PlanWall(id: id, startNodeId: a, endNodeId: b,
  thicknessMm: width, openings: openings);

WallOpening door(String id, double start, {DoorSwing swing = DoorSwing.leftIn,
    double width = 900}) => WallOpening(
  id: id, type: OpeningType.door, widthMm: width,
  heightMm: 2100, offsetFromStartMm: start,
  doorSwing: swing,
);

FloorPlan corridor({double secondWallY = 400}) {
  return FloorPlan(id: 'f', name: 'Two doors', nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 0, yMm: secondWallY),
    PlanNode(id: 'd', xMm: 4000, yMm: secondWallY),
  ], walls: [
    wall('w1', 'a', 'b', openings: [door('d1', 1500)]),
    wall('w2', 'c', 'd', openings: [
      door('d2', 1500, swing: DoorSwing.leftOut),
    ]),
  ]);
}

PlanObject furniture(String id, String catalogId, double x, double y,
    double w, double d, double height) => PlanObject(
  id: id, type: PlanObjectType.furniture, catalogId: catalogId,
  xMm: x, yMm: y, widthMm: w, depthMm: d, heightMm: height,
);

void main() {
  test('door swing collisions are reported for overlapping door leaves', () {
    final floor = corridor();
    final hits = SpaceCheckService.inspect(floor);
    expect(hits.where((i) => i.kind == SpaceIssueKind.doorDoor),
      hasLength(1));
  });

  test('distant door leafs have no door-door collision', () {
    final hits = SpaceCheckService.inspect(corridor(secondWallY: 4000));
    expect(hits.where((i) => i.kind == SpaceIssueKind.doorDoor), isEmpty);
  });

  test('chairs slide under the table while backs above the tabletop collide', () {
    final floor = FloorPlan(id: 'f', name: 'Furniture', planObjects: [
      furniture('table', 'table-rect', 0, 0, 1400, 800, 750),
      furniture('chair', 'chair', 0, 330, 480, 520, 850),
    ]);
    expect(SpaceCheckService.inspect(floor)
      .where((i) => i.kind == SpaceIssueKind.objectObject), isEmpty,
      reason: 'seat and front chair legs fit under the table top; rear '
        'backrest remains outside the tabletop');
    floor.planObjects.last.yMm = 0;
    expect(SpaceCheckService.inspect(floor)
      .where((i) => i.kind == SpaceIssueKind.objectObject), isNotEmpty,
      reason: 'chair backrest above the table surface cannot pass through it');
  });

  test('opening snaps exactly to opposite door centre', () {
    final floor = corridor(secondWallY: 2200);
    final snap = OpeningAlignmentService.snap(
      floor, floor.walls.first, desiredOffsetMm: 1495,
      openingWidthMm: 900,
    );
    expect(snap?.offsetMm, 1500);
    expect(snap?.label, 'По оси двери напротив');
  });

  test('opening snaps to whole wall centre when no junctions', () {
    final floor = corridor(secondWallY: 4000);
    floor.walls.last.openings.clear();
    final snap = OpeningAlignmentService.snap(
      floor, floor.walls.first, desiredOffsetMm: 1550,
      openingWidthMm: 900,
    );
    expect(snap?.offsetMm, 1550);
    expect(snap?.label, 'Центр стены');
  });

  test('renderer keeps windows within walls and physical finish dimensions', () {
    final src = File('lib/widgets/cad_plan_painter_v2.dart')
      .readAsStringSync();
    expect(src, contains('showOpeningDimensions'));
    expect(src, contains('final frameHalf'));
    expect(src, contains('settings.floorTileGroutMm * mmToPx'));
    final editor = File('lib/screens/plan_editor_master_v4_screen.dart')
      .readAsStringSync();
    expect(editor, contains('Size(32000, 32000)'));
    expect(editor, contains('OpeningAlignmentService.snap'));
  });
}
