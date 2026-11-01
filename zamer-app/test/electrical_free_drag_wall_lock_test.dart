import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';

FloorPlan _floor() {
  final floor = FloorPlan(id: 'f', name: 'Квартира');
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
    id: 'socket-1',
    type: ElectricalPointType.socket,
    xMm: 2000, yMm: 0,
    wallId: 'w1', wallOffsetMm: 2000, wallSide: 1,
    heightMm: 300,
  ));
  return floor;
}

Future<void> _mount(WidgetTester tester, FloorPlan floor,
    {Future<void> Function()? onChanged}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: ElectricalScreen(
      floor: floor,
      onChanged: onChanged ?? () async {},
    ),
  )));
  await tester.pumpAndSettle();
}

Offset _socketPosition(WidgetTester tester, FloorPlan floor) {
  final paint = find.byWidgetPredicate((w) =>
      w is CustomPaint && w.painter is ElectricalPlanPainter);
  expect(paint, findsOneWidget);
  final painter = tester.widget<CustomPaint>(paint).painter!
      as ElectricalPlanPainter;
  final point = floor.electricalPoints.single;
  final local = painter.origin + Offset(
    point.xMm * painter.scale, point.yMm * painter.scale);
  final box = tester.renderObject<RenderBox>(paint);
  return box.localToGlobal(local);
}

void main() {
  testWidgets('add mode selects an existing socket without duplicating it',
      (tester) async {
    final floor = _floor();
    await _mount(tester, floor);
    await tester.tapAt(_socketPosition(tester, floor));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints.length, 1);
    expect(find.byKey(const ValueKey('electrical-compact-inspector')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add mode drags an existing socket while keeping its wall',
      (tester) async {
    final floor = _floor();
    var updates = 0;
    await _mount(tester, floor, onChanged: () async { updates++; });
    final paint = find.byWidgetPredicate((w) =>
        w is CustomPaint && w.painter is ElectricalPlanPainter);
    final painter = tester.widget<CustomPaint>(paint).painter!
        as ElectricalPlanPainter;
    await tester.dragFrom(_socketPosition(tester, floor),
        Offset(450 * painter.scale, 0));
    await tester.pumpAndSettle();

    final point = floor.electricalPoints.single;
    expect(point.wallId, 'w1');
    expect(point.wallSide, 1);
    expect(point.wallOffsetMm, greaterThan(2000));
    expect(point.heightMm, 300);
    expect(updates, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wire mode cannot jump a mounted socket onto another wall',
      (tester) async {
    final floor = _floor();
    await _mount(tester, floor);
    await tester.tap(find.byKey(const ValueKey('electrical-fan-wire')));
    await tester.pumpAndSettle();
    // The gesture passes close to the perpendicular wall w2.
    await tester.dragFrom(_socketPosition(tester, floor),
        const Offset(180, 110));
    await tester.pumpAndSettle();

    final point = floor.electricalPoints.single;
    expect(point.wallId, 'w1');
    expect(point.wallSide, 1);
    expect(point.heightMm, 300);
    expect(floor.electricalRuns, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
