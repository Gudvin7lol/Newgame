import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/wall_length_edit_service.dart';

FloorPlan rectangle() {
  final f = FloorPlan(id: 'floor', name: 'Квартира');
  f.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  f.walls.addAll([
    PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'right', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'bottom', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'left', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return f;
}

void main() {
  test('exact resize preserves start, rectangles and wall connectivity', () {
    final floor = rectangle();
    final before = floor.toJson().toString();
    final preview = WallLengthEditService.preview(
      floor, wallId: 'top', lengthMm: 4500,
    );
    expect(preview.isValid, isTrue, reason: preview.message);
    expect(floor.toJson().toString(), before,
        reason: 'preview must not mutate model');
    final result = WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 4500,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.wallLengthMm(floor.wallById('top')!), 4500);
    expect(floor.wallLengthMm(floor.wallById('bottom')!), 4500);
    expect(floor.nodeById('a')!.xMm, 0);
    expect(floor.nodeById('b')!.xMm, 4500);
    expect(floor.nodeById('c')!.xMm, 4500);
    expect(floor.nodeById('d')!.xMm, 0);
    expect(floor.nodeDegree('b'), 2);
    expect(floor.nodeDegree('c'), 2);
  });

  test('resize with end fixed moves the opposite boundary', () {
    final floor = rectangle();
    final result = WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 3200, keepStartFixed: false,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodeById('b')!.xMm, 4000);
    expect(floor.nodeById('c')!.xMm, 4000);
    expect(floor.nodeById('a')!.xMm, 800);
    expect(floor.nodeById('d')!.xMm, 800);
    expect(floor.wallLengthMm(floor.wallById('top')!), 3200);
    expect(floor.wallLengthMm(floor.wallById('bottom')!), 3200);
  });

  test('vertical wall can resize without introducing diagonal walls', () {
    final floor = rectangle();
    final result = WallLengthEditService.resize(
      floor, wallId: 'right', lengthMm: 3600,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodeById('a')!.yMm, 0);
    expect(floor.nodeById('b')!.yMm, 0);
    expect(floor.nodeById('c')!.yMm, 3600);
    expect(floor.nodeById('d')!.yMm, 3600);
    expect(floor.wallLengthMm(floor.wallById('right')!), 3600);
  });

  test('shortening with a door outside new wall rejects atomically', () {
    final floor = rectangle();
    final top = floor.wallById('top')!;
    top.openings.add(WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 900, heightMm: 2100, offsetFromStartMm: 200,
    ));
    final before = floor.toJson().toString();
    final result = WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 3500, keepStartFixed: false,
    );
    expect(result.isValid, isFalse);
    expect(floor.toJson().toString(), before);
  });

  test('opening offset adjusts when start moves but physical door stays put', () {
    final floor = rectangle();
    final top = floor.wallById('top')!;
    final door = WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 800, heightMm: 2100, offsetFromStartMm: 1000,
    );
    top.openings.add(door);
    final result = WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 3500, keepStartFixed: false,
    );
    expect(result.isValid, isTrue, reason: result.message);
    expect(door.offsetFromStartMm, closeTo(500, 0.01));
    expect(door.offsetFromStartMm + floor.nodeById('a')!.xMm, 1000);
  });

  test('T junction cannot be resized ambiguously and leaves no damage', () {
    final floor = rectangle();
    floor.nodes.add(PlanNode(id: 'extra', xMm: 4000, yMm: -1000));
    floor.walls.add(PlanWall(
      id: 'branch', startNodeId: 'b', endNodeId: 'extra',
    ));
    final before = floor.toJson().toString();
    final result = WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 4600,
    );
    expect(result.isValid, isFalse);
    expect(result.message, contains('сложный стык'));
    expect(floor.toJson().toString(), before);
  });

  test('invalid lengths and diagonal walls are rejected', () {
    final floor = rectangle();
    final before = floor.toJson().toString();
    for (final bad in <double>[double.nan, double.infinity, -5, 100, 200000]) {
      expect(WallLengthEditService.resize(
        floor, wallId: 'top', lengthMm: bad,
      ).isValid, isFalse);
    }
    final a = floor.nodeById('a')!;
    a.yMm = -25;
    expect(WallLengthEditService.resize(
      floor, wallId: 'top', lengthMm: 4500,
    ).isValid, isFalse);
    a.yMm = 0;
    expect(floor.toJson().toString(), before);
  });

  test('exact existing-wall input is available from the main wall inspector', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains("ValueKey('selected-wall-length')"));
    expect(src, contains("ValueKey('existing-wall-length-mm')"));
    expect(src, contains("ValueKey('existing-wall-length-apply')"));
    expect(src, contains('WallLengthEditService.resize('));
    expect(src, contains("ValueKey('floating-wall-inspector')"));
    expect(src, contains('onPressed: _resizeSelectedWall'));
    expect(src, contains('child: _canvas()'));
    expect(src, isNot(contains('onResize: _resizeSelectedWall')));
    expect(src, contains('SingleChildScrollView('));
  });
}
