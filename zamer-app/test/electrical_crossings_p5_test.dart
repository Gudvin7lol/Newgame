import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_crossing_service.dart';
import 'package:zamer_app/widgets/electrical_crossing_sheet.dart';
import 'package:zamer_app/screens/electrical_screen.dart';

FloorPlan crossingFixture({
  double height = 300,
  double trackY = 1000,
  WallOpening? opening,
}) {
  final floor = FloorPlan(
    id: 'f', name: 'Объект',
    nodes: [
      PlanNode(id: 'a', xMm: 500, yMm: 0),
      PlanNode(id: 'b', xMm: 500, yMm: 2000),
    ],
    walls: [
      PlanWall(
        id: 'wall', startNodeId: 'a', endNodeId: 'b',
        thicknessMm: 100,
        openings: opening == null ? [] : [opening],
      ),
    ],
    electricalPoints: [
      ElectricalPoint(id: 'start', type: ElectricalPointType.panel,
          xMm: 0, yMm: trackY, heightMm: height),
      ElectricalPoint(id: 'end', type: ElectricalPointType.socket,
          xMm: 1000, yMm: trackY, heightMm: height),
    ],
  );
  floor.electricalNetwork = ElectricalNetwork(
    circuits: [
      ElectricalCircuitRecord(id: 'c1', name: 'Розетки'),
      ElectricalCircuitRecord(id: 'c2', name: 'Свет'),
    ],
    cables: [
      ElectricalCableRecord(id: 'wire', circuitId: 'c1',
          fromPointId: 'start', toPointId: 'end',
          route3dId: 'path', cores: [ElectricalCableCore(id: '1')]),
    ],
    routes3d: [
      ElectricalRoute3d(
        id: 'path', fromPointId: 'start', toPointId: 'end',
        vertices: [
          ElectricalRouteVertex(xMm: 0, yMm: trackY, zMm: height),
          ElectricalRouteVertex(xMm: 1000, yMm: trackY, zMm: height),
        ],
        methods: [ElectricalInstallationMethod.inWall],
      ),
    ],
  );
  return floor;
}

void main() {
  test('non-opening crossing is a review notice at correct XYZ', () {
    final f = crossingFixture();
    final report = ElectricalCrossingService.inspect(f);
    expect(report.notices, hasLength(1));
    final n = report.notices.single;
    expect(n.kind, ElectricalCrossingKind.wallAxis);
    expect(n.xMm, closeTo(500, .001));
    expect(n.yMm, closeTo(1000, .001));
    expect(n.zMm, closeTo(300, .001));
    expect(n.routeSegment, 0);
    expect(report.needsReview, 1);
  });

  test('route within physical opening is not reported as wall penetration', () {
    final f = crossingFixture(
      opening: WallOpening(
        id: 'door', type: OpeningType.door,
        widthMm: 900, heightMm: 2100,
        offsetFromStartMm: 550,
      ),
    );
    final report = ElectricalCrossingService.inspect(f);
    expect(report.notices, hasLength(1));
    expect(report.notices.single.kind, ElectricalCrossingKind.opening);
    expect(report.notices.single.openingId, 'door');
    expect(report.needsReview, 0);
  });

  test('same door XY but above the opening becomes wall-axis warning', () {
    final f = crossingFixture(
      height: 2300,
      opening: WallOpening(
        id: 'door', type: OpeningType.door,
        widthMm: 900, heightMm: 2100,
        offsetFromStartMm: 550,
      ),
    );
    final report = ElectricalCrossingService.inspect(f);
    expect(report.notices.single.kind, ElectricalCrossingKind.wallAxis);
  });

  test('window sill and height are checked at actual Z', () {
    const width = 400.0;
    final f = crossingFixture(
      height: 1000,
      opening: WallOpening(id: 'window', type: OpeningType.window,
        widthMm: width, heightMm: 500, sillHeightMm: 900,
        offsetFromStartMm: 900,
      ),
    );
    expect(ElectricalCrossingService.inspect(f).notices.single.kind,
        ElectricalCrossingKind.opening);
    f.electricalPoints.first.heightMm = 400;
    f.electricalPoints.last.heightMm = 400;
    f.electricalNetwork!.routes3d.single.vertices
      ..clear()
      ..addAll(const [
        ElectricalRouteVertex(xMm: 0, yMm: 1000, zMm: 400),
        ElectricalRouteVertex(xMm: 1000, yMm: 1000, zMm: 400),
      ]);
    expect(ElectricalCrossingService.inspect(f).notices.single.kind,
        ElectricalCrossingKind.wallAxis);
  });

  test('nonintersecting route and pure Z leg do not invent wall crossings', () {
    final f = crossingFixture(trackY: 2500);
    expect(ElectricalCrossingService.inspect(f).notices, isEmpty);
    final n = f.electricalNetwork!;
    f.electricalPoints.first
      ..xMm = 500
      ..yMm = 1000
      ..heightMm = 300;
    f.electricalPoints.last
      ..xMm = 500
      ..yMm = 1000
      ..heightMm = 500;
    n.routes3d.single.vertices
      ..clear()
      ..addAll(const [
        ElectricalRouteVertex(xMm: 500, yMm: 1000, zMm: 300),
        ElectricalRouteVertex(xMm: 500, yMm: 1000, zMm: 500),
      ]);
    expect(ElectricalCrossingService.inspect(f).notices, isEmpty);
  });

  test('running along a wall axis is flagged, not described as a penetration', () {
    final f = crossingFixture();
    f.electricalPoints.first
      ..xMm = 500
      ..yMm = 100;
    f.electricalPoints.last
      ..xMm = 500
      ..yMm = 1800;
    f.electricalNetwork!.routes3d.single.vertices
      ..clear()
      ..addAll(const [
        ElectricalRouteVertex(xMm: 500, yMm: 100, zMm: 300),
        ElectricalRouteVertex(xMm: 500, yMm: 1800, zMm: 300),
      ]);
    expect(ElectricalCrossingService.inspect(f).notices.single.kind,
        ElectricalCrossingKind.alongWall);
  });

  test('intersection at actual wall endpoint is an uncertain touch', () {
    final f = crossingFixture(trackY: 0);
    expect(ElectricalCrossingService.inspect(f).notices.single.kind,
        ElectricalCrossingKind.wallEndpoint);
  });

  test('unsupported curved wall is reported, not falsely cleared', () {
    final f = crossingFixture();
    f.walls.first.curveGroupId = 'curve';
    final report = ElectricalCrossingService.inspect(f);
    expect(report.notices.single.kind,
        ElectricalCrossingKind.unsupportedWall);
    expect(report.needsReview, 1);
  });

  test('demolition walls are excluded from active route notices', () {
    final f = crossingFixture();
    f.walls.first.demolition = true;
    expect(ElectricalCrossingService.inspect(f).notices, isEmpty);
  });

  test('missing and invalid 3D routes are disclosed and group-filtered', () {
    final f = crossingFixture();
    final n = f.electricalNetwork!;
    n.cables.add(ElectricalCableRecord(
        id: 'unknown', circuitId: 'c2',
        fromPointId: 'start', toPointId: 'end'));
    expect(ElectricalCrossingService.inspect(f, circuitId: 'c1').missingRoutes, 0);
    expect(ElectricalCrossingService.inspect(f, circuitId: 'c2').missingRoutes, 1);
    final first = ElectricalCrossingService.inspect(f);
    expect(first.notices, hasLength(1));
    expect(first.missingRoutes, 1);
    f.electricalPoints.last.xMm = 1200;
    final after = ElectricalCrossingService.inspect(f);
    expect(after.invalidRoutes, 1);
    expect(after.notices, isEmpty);
  });

  test('legacy-only drawing never becomes physical crossing', () {
    final f = crossingFixture();
    f.electricalNetwork = null;
    f.electricalRuns.add(ElectricalRun(
        id: 'legacy', startPointId: 'start', endPointId: 'end'));
    expect(ElectricalCrossingService.inspect(f).notices, isEmpty);
  });

  testWidgets('mobile review sheet shows geometric warnings, no edits',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = crossingFixture();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElectricalCrossingSheet(
        floor: f, initialCircuitId: null, onCircuitChanged: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Пересечения трасс'), findsOneWidget);
    expect(find.byKey(const ValueKey('crossings-review-count')),
        findsOneWidget);
    expect(find.text('Проход через стену'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing electrical screen includes optional crossing layer',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = crossingFixture();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElectricalScreen(
        floor: f, embedded: true, onChanged: () async {},
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-plan-layers')));
    await tester.pumpAndSettle();
    expect(find.text('Маркеры пересечений'), findsOneWidget);
    expect(find.text('Журнал пересечений'), findsOneWidget);
    await tester.tap(find.text('Маркеры пересечений'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-plan-layers')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Журнал пересечений'));
    await tester.pumpAndSettle();
    expect(find.text('Пересечения трасс'), findsOneWidget);
    expect(find.byKey(const ValueKey('crossings-review-count')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
