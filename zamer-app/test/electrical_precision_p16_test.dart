import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_snap_service.dart';
import 'package:zamer_app/services/electrical_frame_geometry.dart';

FloorPlan fixture() {
  final floor = FloorPlan(id: 'level', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return floor;
}

void main() {
  test('wall snap is in real mm; grid adapts to zoom', () {
    final floor = fixture();
    final wall = floor.walls.first;
    expect(ElectricalSnapService.stepMm(.1), 10);
    expect(ElectricalSnapService.stepMm(.02), 50);
    expect(ElectricalSnapService.wallOffset(
        floor, wall, 637, .1), 640);
    expect(ElectricalSnapService.wallOffset(
        floor, wall, 637, .02), 650);
    expect(ElectricalSnapService.captureMm(.08), closeTo(150, .001));
    expect(ElectricalSnapService.captureMm(.16), closeTo(75, .001));
  });

  test('opening edge is a magnetic anchor, never a fake connected wire', () {
    final floor = fixture();
    final wall = floor.walls.first;
    wall.openings.add(WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 900, heightMm: 2100,
      offsetFromStartMm: 1000,
    ));
    expect(ElectricalSnapService.wallOffset(
        floor, wall, 995, .8), 1000);
    expect(floor.electricalNetwork, isNull);
  });

  test('light aligns one axis while keeping the other on a precise grid', () {
    final floor = fixture();
    floor.electricalPoints.add(ElectricalPoint(
      id: 'lamp', type: ElectricalPointType.ceilingLight,
      xMm: 800, yMm: 800,
    ));
    final snapped = ElectricalSnapService.light(
        floor, const math.Point<double>(810, 1254), .4);
    expect(snapped.position.x, 800);
    expect(snapped.position.y, 1250);
    expect(snapped.reason, 'ось светильника');
  });

  test('light near room centroid snaps to the centre of geometry', () {
    final floor = fixture();
    final snapped = ElectricalSnapService.light(
        floor, const math.Point<double>(2005, 1504), .4);
    expect(snapped.position.x, closeTo(2000, 10));
    expect(snapped.position.y, closeTo(1500, 10));
    expect(snapped.reason, 'центр помещения');
  });

  test('a standalone socket cannot be silently placed inside a frame', () {
    final floor = fixture();
    floor.electricalPoints.add(ElectricalPoint(
      id: 'frame', type: ElectricalPointType.frame,
      xMm: 650, yMm: 0, wallId: 'w1',
      wallOffsetMm: 650, heightMm: 300,
      modules: [
        ElectricalModuleType.socket220,
        ElectricalModuleType.socket220,
        ElectricalModuleType.socket220,
      ],
    ));
    final single = ElectricalPoint(
      id: 'socket', type: ElectricalPointType.socket,
      xMm: 720, yMm: 0, wallId: 'w1',
      wallOffsetMm: 720, heightMm: 300,
    );
    expect(ElectricalFrameGeometry.conflictWithFrames(
        floor, single), contains('frame'));
    single.wallSide = -1;
    expect(ElectricalFrameGeometry.conflictWithFrames(
        floor, single), isNull);
  });

  testWidgets('v8 arcs keep the approved add/select/wire entry points',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: floor, onChanged: () async {}),
    )));
    await tester.tap(find.byKey(const ValueKey('electrical-fan-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-two-ring-fan')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-add-frame')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-fan-select')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-fan-wire')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outer fan scroll reveals wall light without creating a point',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: floor, onChanged: () async {}),
    )));
    await tester.tap(find.byKey(const ValueKey('electrical-fan-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-add-wallLight')),
        findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('electrical-two-ring-fan')),
      const Offset(0, 90),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-add-wallLight')),
        findsOneWidget);
    expect(floor.electricalPoints, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
