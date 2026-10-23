import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/wall_drag_touch_policy.dart';
import 'package:zamer_app/services/wall_topology_diagnostics.dart';

FloorPlan rectangle() => FloorPlan(
  id: 'closed', name: 'Замкнутый контур',
  nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3000, yMm: 0),
    PlanNode(id: 'c', xMm: 3000, yMm: 2000),
    PlanNode(id: 'd', xMm: 0, yMm: 2000),
  ],
  walls: [
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
  ],
);

void main() {
  test('valid closed room has no false-positive topology gaps', () {
    expect(WallTopologyDiagnostics.findGaps(rectangle()), isEmpty);
  });

  test('detached endpoints within 12 mm produce one warning, not two', () {
    final f = FloorPlan(id: 'gap', name: 'Разрыв',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 1000, yMm: 0),
        PlanNode(id: 'c', xMm: 1012, yMm: 0),
        PlanNode(id: 'd', xMm: 2000, yMm: 0),
      ], walls: [
        PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      ]);
    final gaps = WallTopologyDiagnostics.findGaps(f);
    expect(gaps.length, 1);
    expect(gaps.single.kind, WallTopologyGapKind.detachedNodes);
    expect(gaps.single.distanceMm, closeTo(12, .00001));
  });

  test('visually coincident but unjoined endpoints still warn', () {
    final f = FloorPlan(id: 'same', name: 'Ложный стык', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 1000, yMm: 0),
      PlanNode(id: 'c', xMm: 1000, yMm: 0),
      PlanNode(id: 'd', xMm: 2000, yMm: 0),
    ], walls: [
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    ]);
    final gaps = WallTopologyDiagnostics.findGaps(f);
    expect(gaps.length, 1);
    expect(gaps.single.distanceMm, 0);
  });

  test('near host wall is a missing T junction, not a closed room', () {
    final f = FloorPlan(id: 'tee', name: 'Т-стык', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 0),
      PlanNode(id: 'tip', xMm: 1000, yMm: 18),
      PlanNode(id: 'out', xMm: 1000, yMm: 1200),
    ], walls: [
      PlanWall(id: 'host', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'branch', startNodeId: 'tip', endNodeId: 'out'),
    ]);
    final gaps = WallTopologyDiagnostics.findGaps(f);
    expect(gaps.length, 1);
    expect(gaps.single.sourceNodeId, 'tip');
    expect(gaps.single.targetWallId, 'host');
    expect(gaps.single.kind, WallTopologyGapKind.detachedWallEnd);
    expect(gaps.single.target, const math.Point<double>(1000, 0));
    expect(gaps.single.distanceMm, closeTo(18, .001));
  });

  test('real shared T junction has no false warning', () {
    final f = FloorPlan(id: 'real-tee', name: 'Общий узел', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'j', xMm: 1000, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 0),
      PlanNode(id: 'c', xMm: 1000, yMm: 1200),
    ], walls: [
      PlanWall(id: 'a-j', startNodeId: 'a', endNodeId: 'j'),
      PlanWall(id: 'j-b', startNodeId: 'j', endNodeId: 'b'),
      PlanWall(id: 'j-c', startNodeId: 'j', endNodeId: 'c'),
    ]);
    expect(WallTopologyDiagnostics.findGaps(f), isEmpty);
  });

  test('limited reach avoids auto-warning intentional distant openings', () {
    final f = FloorPlan(id: 'distant', name: 'Раздельно', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 1000, yMm: 0),
      PlanNode(id: 'c', xMm: 1080, yMm: 0),
      PlanNode(id: 'd', xMm: 2000, yMm: 0),
    ], walls: [
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    ]);
    expect(WallTopologyDiagnostics.findGaps(f), isEmpty);
  });

  test('finger jitter parallel to wall never activates wall movement', () {
    const start = Offset(120, 220);
    expect(WallDragTouchPolicy.shouldStart(
      start, const Offset(127, 400), verticalWall: true), isFalse);
    expect(WallDragTouchPolicy.shouldStart(
      start, const Offset(129, 220), verticalWall: true), isTrue);
    expect(WallDragTouchPolicy.shouldStart(
      start, const Offset(400, 227), verticalWall: false), isFalse);
    expect(WallDragTouchPolicy.shouldStart(
      start, const Offset(120, 211), verticalWall: false), isTrue);
  });

  test('production canvas shows diagnostics but does not auto-weld nodes', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains('WallTopologyDiagnostics.findGaps(floor)'));
    expect(src, contains("ValueKey('wall-gap-contours')"));
    expect(src, contains("ValueKey('wall-near-gap-indicator')"));
    expect(src, contains('_focusFirstTopologyGap'));
    expect(src, contains('WallDragTouchPolicy.shouldStart('));
  });
}
