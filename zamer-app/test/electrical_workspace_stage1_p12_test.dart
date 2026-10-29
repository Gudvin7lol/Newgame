import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/widgets/electrical_compact_inspector.dart';

FloorPlan _floor() {
  final floor = FloorPlan(id: 'floor', name: 'Этаж 1');
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
    xMm: 650,
    yMm: 0,
    heightMm: 300,
    wallId: 'w1',
    wallOffsetMm: 650,
    circuit: 'К1',
    powerW: 2200,
  ));
  return floor;
}

void main() {
  testWidgets('task switcher has exactly three surfaces and preserves plan',
      (tester) async {
    final floor = _floor();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElectricalScreen(
        floor: floor, onChanged: () async {},
      )),
    ));
    expect(find.byKey(const ValueKey('electrical-three-modes')),
        findsOneWidget);
    expect(find.text('Точки и трассы'), findsOneWidget);
    expect(find.text('Нагрузки'), findsOneWidget);
    expect(find.text('Щит'), findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-fan-add')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('electrical-load-inventory')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-loads-workspace')),
        findsOneWidget);
    expect(find.text('К1'), findsWidgets);
    expect(find.byKey(const ValueKey('electrical-fan-add')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('electrical-view-board')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-board-workspace')),
        findsOneWidget);
    expect(find.textContaining('нельзя собирать щит'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('electrical-view-pointsRoutes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-fan-add')),
        findsOneWidget);
    expect(floor.electricalPoints, hasLength(1));
  });

  testWidgets('inspector shows precise non-finished datum and three actions',
      (tester) async {
    final floor = _floor();
    var datum = 0, height = 0, load = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalCompactInspector(
        floor: floor,
        point: floor.electricalPoints.single,
        onDatum: () => datum++,
        onHeight: () => height++,
        onLoad: () => load++,
      ),
    )));
    expect(find.byKey(const ValueKey('electrical-compact-inspector')),
        findsOneWidget);
    expect(find.text('От оси стены'), findsOneWidget);
    expect(find.text('650 мм'), findsOneWidget);
    expect(find.text('300 мм'), findsOneWidget);
    expect(find.textContaining('К1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('electrical-inspector-datum')));
    await tester.tap(find.byKey(const ValueKey('electrical-inspector-height')));
    await tester.tap(find.byKey(const ValueKey('electrical-inspector-load')));
    expect([datum, height, load], [1, 1, 1]);
  });
}
