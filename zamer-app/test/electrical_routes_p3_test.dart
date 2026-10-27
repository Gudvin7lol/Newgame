import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_junction_edit_service.dart';
import 'package:zamer_app/services/electrical_network_service.dart';
import 'package:zamer_app/services/electrical_route_service.dart';
import 'package:zamer_app/widgets/electrical_route_editor.dart';

FloorPlan routeFixture() {
  final floor = FloorPlan(id: 'f', name: 'Монтаж', electricalPoints: [
    ElectricalPoint(id: 'j', type: ElectricalPointType.junctionBox,
        xMm: 0, yMm: 0, heightMm: 300),
    ElectricalPoint(id: 's', type: ElectricalPointType.socket,
        xMm: 1000, yMm: 500, heightMm: 600),
  ]);
  floor.electricalNetwork = ElectricalNetwork(
    circuits: [ElectricalCircuitRecord(id: 'g', name: 'Кухня')],
    cables: [ElectricalCableRecord(id: 'c', circuitId: 'g',
        fromPointId: 'j', toPointId: 's',
        cores: [ElectricalCableCore(id: '1')])],
  );
  return floor;
}

ElectricalRoute3d knownRoute() => ElectricalRoute3d(
  id: 'route-c', fromPointId: 'j', toPointId: 's',
  vertices: const [
    ElectricalRouteVertex(xMm: 0, yMm: 0, zMm: 300),
    ElectricalRouteVertex(xMm: 1000, yMm: 0, zMm: 300),
    ElectricalRouteVertex(xMm: 1000, yMm: 500, zMm: 300),
    ElectricalRouteVertex(xMm: 1000, yMm: 500, zMm: 600),
  ],
  methods: [
    ElectricalInstallationMethod.inWall,
    ElectricalInstallationMethod.inWall,
    ElectricalInstallationMethod.conduit,
  ],
  source: ElectricalPathSource.drawing,
);

void main() {
  test('calculates precisely each X/Y/Z leg and explicit reserve', () {
    final floor = routeFixture();
    final measured = ElectricalRouteService.measure(
        floor, knownRoute(), reserveMm: 250);
    expect(measured.legLengthsMm, [1000, 500, 300]);
    expect(measured.geometricMm, 1800);
    expect(measured.procurementLengthMm, 2050);
    expect(ElectricalRouteService.measure(floor, knownRoute())
        .procurementLengthMm, isNull);
  });

  test('legacy cable stays unmeasured without a 3D route', () {
    final floor = routeFixture();
    expect(floor.electricalNetwork!.routes3d, isEmpty);
    expect(floor.electricalNetwork!.cables.first.route3dId, isNull);
    expect(() => ElectricalRouteService.measureCable(
      floor, floor.electricalNetwork!.cables.first,
    ), throwsFormatException);
  });

  test('allows negative signed travel but no zero, nan or wrong axes', () {
    const vertex = ElectricalRouteVertex(xMm: 0, yMm: 0, zMm: 1000);
    expect(ElectricalRouteService.step(vertex, 'Z', -600).zMm, 400);
    expect(() => ElectricalRouteService.step(vertex, 'Z', 0),
        throwsFormatException);
    expect(() => ElectricalRouteService.step(vertex, 'Z', double.nan),
        throwsFormatException);
    expect(() => ElectricalRouteService.step(vertex, 'Q', 3),
        throwsFormatException);
  });

  test('rejects diagonal, gaps, deleted points and stale floor heights', () {
    final floor = routeFixture();
    final diagonal = ElectricalRoute3d.fromJson(knownRoute().toJson());
    diagonal.vertices[1] =
        const ElectricalRouteVertex(xMm: 1000, yMm: 30, zMm: 300);
    expect(() => ElectricalRouteService.measure(floor, diagonal),
        throwsFormatException);
    final old = knownRoute();
    floor.electricalPoints.last.heightMm = 700;
    expect(() => ElectricalRouteService.measure(floor, old),
        throwsFormatException);
    floor.electricalPoints.removeLast();
    expect(() => ElectricalRouteService.measure(floor, old),
        throwsFormatException);
  });

  test('invalid reserve, nonfinite coords, and wrong count are rejected', () {
    final floor = routeFixture();
    for (final n in [-1.0, double.nan, double.infinity]) {
      expect(() => ElectricalRouteService.measure(floor, knownRoute(),
          reserveMm: n), throwsFormatException);
    }
    final bad = ElectricalRoute3d.fromJson(knownRoute().toJson());
    bad.methods.removeLast();
    expect(() => ElectricalRouteService.measure(floor, bad),
        throwsFormatException);
    final x = ElectricalRoute3d.fromJson(knownRoute().toJson());
    x.vertices[1] = const ElectricalRouteVertex(
        xMm: double.infinity, yMm: 0, zMm: 300);
    expect(() => ElectricalRouteService.measure(floor, x),
        throwsFormatException);
  });

  test('3D records persist through floor JSON, clone and undo', () {
    final floor = routeFixture();
    final original = FloorPlan.fromJson(floor.toJson());
    final draft = ElectricalJunctionEditService.copy(floor.electricalNetwork);
    ElectricalRouteService.upsertForCable(
        floor, draft, 'c', knownRoute(), reserveMm: 250);
    floor.electricalNetwork = ElectricalJunctionEditService.copy(draft);
    final restored = FloorPlan.fromJson(
        jsonDecode(jsonEncode(floor.toJson())) as Map<String, dynamic>);
    expect(restored.electricalNetwork!.routes3d.single.vertices.length, 4);
    expect(ElectricalRouteService.measureCable(restored,
        restored.electricalNetwork!.cables.single).procurementLengthMm, 2050);
    floor.restoreFrom(original);
    expect(floor.electricalNetwork!.routes3d, isEmpty);
    expect(floor.electricalNetwork!.cables.single.explicitReserveMm, isNull);
  });

  test('rejects shared path updates without silently moving another cable', () {
    final floor = routeFixture();
    final n = floor.electricalNetwork!;
    n.cables.add(ElectricalCableRecord(
        id: 'c2', circuitId: 'g', fromPointId: 'j', toPointId: 's'));
    ElectricalRouteService.upsertForCable(
      floor, n, 'c', knownRoute(), reserveMm: 100);
    n.cables.last.route3dId = 'route-c';
    final before = jsonEncode(n.toJson());
    expect(() => ElectricalRouteService.upsertForCable(
        floor, n, 'c', knownRoute(), reserveMm: 1000),
        throwsFormatException);
    expect(jsonEncode(n.toJson()), before);
    ElectricalRouteService.clearCableRoute(n, 'c');
    expect(n.routes3d, hasLength(1),
        reason: 'Other cable still references shared path');
    ElectricalRouteService.clearCableRoute(n, 'c2');
    expect(n.routes3d, isEmpty);
  });

  test('editing cable details preserves route and core IDs', () {
    final floor = routeFixture();
    final network = floor.electricalNetwork!;
    ElectricalRouteService.upsertForCable(
        floor, network, 'c', knownRoute(), reserveMm: 0);
    ElectricalJunctionEditService.editCableDetails(
        network, cableId: 'c', description: 'Кабель 01', circuitId: 'g');
    final cable = network.cables.single;
    expect(cable.description, 'Кабель 01');
    expect(cable.route3dId, 'route-c');
    expect(cable.cores.single.id, '1');
    expect(ElectricalNetworkService.inspect(floor)
        .where((i) => i.severity == ElectricalNetworkSeverity.error), isEmpty);
  });

  test('removing cable removes unshared path, terminal links protect cable', () {
    final floor = routeFixture();
    final draft = floor.electricalNetwork!;
    ElectricalRouteService.upsertForCable(
        floor, draft, 'c', knownRoute(), reserveMm: 90);
    ElectricalJunctionEditService.removeCable(draft, 'c');
    expect(draft.routes3d, isEmpty);
    expect(draft.cables, isEmpty);
  });

  testWidgets('route editor closes without mutating live floor', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = routeFixture();
    final before = jsonEncode(floor.toJson());
    ElectricalRouteEditResult? result;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          child: const Text('Редактор'),
          onPressed: () async {
            result = await Navigator.push<ElectricalRouteEditResult>(
              context, MaterialPageRoute(builder: (_) => ElectricalRouteEditor(
                floor: floor, cable: floor.electricalNetwork!.cables.first,
              )),
            );
          },
        ),
      ),
    )));
    await tester.tap(find.text('Редактор'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-save')), findsOneWidget);
    expect(tester.widget<FilledButton>(
        find.byKey(const ValueKey('route-save'))).onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(jsonEncode(floor.toJson()), before);
    expect(tester.takeException(), isNull);
  });
}
