import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_wall_elevation_service.dart';
import 'package:zamer_app/widgets/electrical_wall_elevation_screen.dart';

FloorPlan elevationFixture() {
  final f = FloorPlan(
    id: 'f', name: 'План', defaultHeightMm: 2700,
    nodes: [
      PlanNode(id: 'n1', xMm: 100, yMm: 200),
      PlanNode(id: 'n2', xMm: 4100, yMm: 200),
      PlanNode(id: 'n3', xMm: 4100, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w', startNodeId: 'n1', endNodeId: 'n2',
        openings: [
          WallOpening(
            id: 'window', type: OpeningType.window,
            widthMm: 1200, heightMm: 1400,
            offsetFromStartMm: 1800, sillHeightMm: 800,
          ),
        ]),
      PlanWall(id: 'w2', startNodeId: 'n2', endNodeId: 'n3'),
    ],
    electricalPoints: [
      ElectricalPoint(id: 'p', type: ElectricalPointType.panel,
          xMm: 100, yMm: 200, heightMm: 500,
          wallId: 'w', label: 'Щит'),
      ElectricalPoint(id: 's', type: ElectricalPointType.socket,
          xMm: 4100, yMm: 200, heightMm: 1000,
          wallId: 'w', label: 'Розетка'),
      // Similar XY position is NOT evidence of belonging to w.
      ElectricalPoint(id: 'free', type: ElectricalPointType.socket,
          xMm: 2100, yMm: 200, heightMm: 800, label: 'Без стены'),
      ElectricalPoint(id: 'on-other', type: ElectricalPointType.socket,
          xMm: 4100, yMm: 1000, heightMm: 800,
          wallId: 'w2', label: 'Соседняя'),
    ],
  );
  f.electricalNetwork = ElectricalNetwork(
    circuits: [
      ElectricalCircuitRecord(id: 'c1', name: 'Кухня'),
      ElectricalCircuitRecord(id: 'c2', name: 'Свет'),
    ],
    cables: [
      ElectricalCableRecord(id: 'cable', circuitId: 'c1',
          fromPointId: 'p', toPointId: 's', route3dId: 'route',
          cores: [ElectricalCableCore(id: '1')]),
    ],
    routes3d: [
      ElectricalRoute3d(
        id: 'route', fromPointId: 'p', toPointId: 's',
        vertices: const [
          ElectricalRouteVertex(xMm: 100, yMm: 200, zMm: 500),
          ElectricalRouteVertex(xMm: 2100, yMm: 200, zMm: 500),
          ElectricalRouteVertex(xMm: 2100, yMm: 200, zMm: 1000),
          ElectricalRouteVertex(xMm: 4100, yMm: 200, zMm: 1000),
        ],
        methods: [
          ElectricalInstallationMethod.inWall,
          ElectricalInstallationMethod.inWall,
          ElectricalInstallationMethod.inWall,
        ],
        source: ElectricalPathSource.drawing,
      ),
    ],
  );
  return f;
}

void main() {
  test('wall elevation uses start-node distance and finished-floor height', () {
    final f = elevationFixture();
    final result = ElectricalWallElevationService.build(f, 'w');
    expect(result.lengthMm, 4000);
    expect(result.heightMm, 2700);
    expect(result.openings.single.fromUMm, 1800);
    expect(result.openings.single.toUMm, 3000);
    expect(result.openings.single.bottomMm, 800);
    expect(result.openings.single.topMm, 2200);
    expect(result.points.map((e) => e.pointId), ['p', 's']);
    expect(result.points[0].uMm, 0);
    expect(result.points[0].zMm, 500);
    expect(result.points[1].uMm, 4000);
    expect(result.points[1].zMm, 1000);
    expect(result.segments, hasLength(3));
    expect(result.segments[1].fromUMm, 2000);
    expect(result.segments[1].fromZMm, 500);
    expect(result.segments[1].toZMm, 1000);
  });

  test('height override changes datum drawing and out-of-range device warns', () {
    final f = elevationFixture();
    f.walls.first.heightOverrideMm = 900;
    final result = ElectricalWallElevationService.build(f, 'w');
    expect(result.heightMm, 900);
    expect(result.points.map((p) => p.pointId), ['p']);
    expect(result.openings, isEmpty);
    expect(result.warnings.where((w) => w.contains('Проём')), isNotEmpty);
    expect(result.warnings.where((w) => w.contains('Электроточка')), isNotEmpty);
  });

  test('reversed wall direction gives dimensions from reversed start', () {
    final f = elevationFixture();
    final wall = f.walls.first;
    wall.startNodeId = 'n2';
    wall.endNodeId = 'n1';
    wall.openings.clear();
    final data = ElectricalWallElevationService.build(f, 'w');
    expect(data.points.first.pointId, 's');
    expect(data.points.first.uMm, 0);
    expect(data.points.last.pointId, 'p');
    expect(data.points.last.uMm, 4000);
  });

  test('diagonal wall projects assigned devices without pixel assumptions', () {
    final f = elevationFixture();
    f.nodes[1].xMm = 3100;
    f.nodes[1].yMm = 3200;
    f.walls.first.openings.clear();
    f.electricalPoints[1]
      ..xMm = 3100
      ..yMm = 3200;
    final data = ElectricalWallElevationService.build(f, 'w');
    expect(data.lengthMm, closeTo(4242.64, .05));
    expect(data.points.last.uMm, closeTo(data.lengthMm, .001));
    expect(data.segments, isEmpty,
      reason: 'Old cable path cannot be shown on a moved diagonal wall');
  });

  test('wall proximity is never treated as explicit wall assignment', () {
    final f = elevationFixture();
    final data = ElectricalWallElevationService.build(f, 'w');
    expect(data.points.any((p) => p.pointId == 'free'), false);
    expect(data.points.any((p) => p.pointId == 'on-other'), false);
  });

  test('transverse route crossing wall does not become on-wall route', () {
    final f = elevationFixture();
    f.electricalPoints.first
      ..xMm = 2100
      ..yMm = -1000
      ..wallId = null;
    f.electricalPoints[1]
      ..xMm = 2100
      ..yMm = 1000
      ..wallId = null;
    f.electricalNetwork!.routes3d.single.vertices
      ..clear()
      ..addAll(const [
        ElectricalRouteVertex(xMm: 2100, yMm: -1000, zMm: 500),
        ElectricalRouteVertex(xMm: 2100, yMm: 1000, zMm: 500),
      ]);
    f.electricalPoints[1].heightMm = 500;
    final data = ElectricalWallElevationService.build(f, 'w');
    expect(data.segments, isEmpty);
    expect(data.crossings, isNotEmpty);
  });

  test('curved wall reports unsupported instead of straight fake diagram', () {
    final f = elevationFixture();
    f.walls.first.curveGroupId = 'arc-group';
    final data = ElectricalWallElevationService.build(f, 'w');
    expect(data.supported, false);
    expect(data.points, isEmpty);
    expect(data.openings, isEmpty);
    expect(data.segments, isEmpty);
    expect(data.warnings, isNotEmpty);
  });

  test('missing wall reference and zero length are rejected', () {
    final f = elevationFixture();
    expect(() => ElectricalWallElevationService.build(f, 'missing'),
        throwsFormatException);
    f.nodes[1]
      ..xMm = 100
      ..yMm = 200;
    expect(() => ElectricalWallElevationService.build(f, 'w'),
        throwsFormatException);
  });

  test('read-only service leaves serialization unchanged', () {
    final f = elevationFixture();
    final before = jsonEncode(f.toJson());
    final result = ElectricalWallElevationService.build(f, 'w',
        circuitId: 'c2');
    expect(result.segments, isEmpty);
    expect(result.points.length, 2);
    expect(jsonEncode(f.toJson()), before);
  });

  testWidgets('390px mobile elevation shows dimension cards and opens wall',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = elevationFixture();
    await tester.pumpWidget(MaterialApp(home:
        ElectricalWallElevationScreen(floor: f)));
    await tester.pumpAndSettle();
    expect(find.text('Развёртка электрики'), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-elevation-drawing')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('wall-elevation-scroll')), findsOneWidget);
    expect(find.text('Длина'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded electrical toolbar opens elevation without floor edit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = elevationFixture();
    final before = jsonEncode(f.toJson());
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: f, embedded: true,
          onChanged: () async {}),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-wall-elevation')));
    await tester.pumpAndSettle();
    expect(find.text('Развёртка электрики'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(jsonEncode(f.toJson()), before);
    expect(tester.takeException(), isNull);
  });
}
