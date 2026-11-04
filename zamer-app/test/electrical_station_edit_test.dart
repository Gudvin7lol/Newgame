import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_mounting.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_mounting_service.dart';
import 'package:zamer_app/services/electrical_point_dimension_service.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';

FloorPlan fixture() {
  final floor = FloorPlan(id: 'f', name: 'Этаж 1');
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
  floor.electricalPoints.add(ElectricalPoint(
    id: 'socket', type: ElectricalPointType.socket,
    xMm: 650, yMm: 0, wallId: 'w1', wallOffsetMm: 650,
    wallSide: 1, heightMm: 300,
  ));
  return floor;
}

void main() {
  test('1 mm station proposals stay in the same wall and do not mutate', () {
    final floor = fixture();
    final point = floor.electricalPoints.single;
    final proposal = ElectricalPointDimensionService.prepare(
        floor, point, 1251);
    expect(proposal.wallOffsetMm, 1251);
    expect(proposal.xMm, 1251);
    expect(proposal.yMm, 0);
    expect(proposal.wallId, 'w1');
    expect(proposal.wallSide, 1);
    expect(proposal.heightMm, 300);
    expect(point.wallOffsetMm, 650);
    for (final invalid in [-1.0, 4001.0, 1250.5, double.nan]) {
      expect(() => ElectricalPointDimensionService.prepare(
          floor, point, invalid), throwsFormatException);
    }
    expect(point.xMm, 650);
  });

  test('named datum remains consistent when a station is changed', () {
    final floor = fixture();
    final wall = floor.walls.first;
    final point = floor.electricalPoints.single;
    final mounting = ElectricalMounting(
      wallId: wall.id, datumNodeId: 'a', datumName: 'Угол А',
      datumInsetMm: 50, distanceMm: 600,
      heightAboveFinishedFloorMm: 300, wallSide: 1,
      geometrySnapshot: ElectricalMountingService.snapshot(floor, wall),
    );
    ElectricalMountingService.apply(floor, point, mounting);
    final proposal = ElectricalPointDimensionService.prepare(
        floor, point, 1250);
    expect(proposal.mounting!.distanceMm, 1200);
    expect(ElectricalMountingService.problem(floor, proposal), isNull);
    expect(point.mounting!.distanceMm, 600);
  });

  test('door and frame block station updates without changing plan', () {
    final floor = fixture();
    final point = floor.electricalPoints.single;
    floor.walls.first.openings.add(WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 900, heightMm: 2100, offsetFromStartMm: 1000,
    ));
    expect(() => ElectricalPointDimensionService.prepare(
        floor, point, 1250), throwsFormatException);
    floor.walls.first.openings.clear();
    floor.electricalPoints.add(ElectricalPoint(
      id: 'frame', type: ElectricalPointType.frame,
      xMm: 1250, yMm: 0, wallId: 'w1', wallOffsetMm: 1250,
      wallSide: 1, heightMm: 300,
      modules: [ElectricalModuleType.socket220,
        ElectricalModuleType.socket220],
    ));
    expect(() => ElectricalPointDimensionService.prepare(
        floor, point, 1250), throwsFormatException);
    expect(point.wallOffsetMm, 650);
  });

  testWidgets('tap dimension, enter station, save, undo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(
          floor: floor, onChanged: () async { saves++; }),
    )));
    await tester.pumpAndSettle();
    final painterFinder = find.byWidgetPredicate((w) =>
        w is CustomPaint && w.painter is ElectricalPlanPainter);
    final painter = tester.widget<CustomPaint>(painterFinder).painter!
        as ElectricalPlanPainter;
    final box = tester.renderObject<RenderBox>(painterFinder);
    await tester.tapAt(box.localToGlobal(painter.origin +
        Offset(650 * painter.scale, 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-dimension-station')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('electrical-dimension-station')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(
        const ValueKey('electrical-station-input')), '1250');
    await tester.tap(find.byKey(
        const ValueKey('electrical-station-confirm')));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints.single.wallOffsetMm, 1250);
    expect(floor.electricalPoints.single.wallId, 'w1');
    expect(saves, 1);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints.single.wallOffsetMm, 650);
    expect(tester.takeException(), isNull);
  });
}
