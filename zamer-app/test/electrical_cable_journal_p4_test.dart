import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_cable_journal_service.dart';
import 'package:zamer_app/services/electrical_route_service.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/widgets/electrical_cable_journal_sheet.dart';

FloorPlan journalFixture() {
  final floor = FloorPlan(id: 'f', name: 'Этаж', electricalPoints: [
    ElectricalPoint(id: 'j', type: ElectricalPointType.junctionBox,
        xMm: 0, yMm: 0, heightMm: 300, label: 'РК-1'),
    ElectricalPoint(id: 's', type: ElectricalPointType.socket,
        xMm: 1000, yMm: 0, heightMm: 300, label: 'Розетка'),
    ElectricalPoint(id: 'p', type: ElectricalPointType.panel,
        xMm: 0, yMm: 2000, heightMm: 1200, label: 'ЩР'),
  ], electricalRuns: [
    ElectricalRun(id: 'drawing', startPointId: 'j', endPointId: 'p',
        cable: 'Нарисовано ранее', reservePct: 40),
  ]);
  floor.electricalNetwork = ElectricalNetwork(circuits: [
    ElectricalCircuitRecord(id: 'g1', name: 'Розетки'),
    ElectricalCircuitRecord(id: 'g2', name: 'Свет'),
  ], cables: [
    ElectricalCableRecord(id: 'c1', circuitId: 'g1',
        fromPointId: 'j', toPointId: 's', route3dId: 'r1',
        explicitReserveMm: 250, description: 'Кабель 1',
        cores: [ElectricalCableCore(id: '1')]),
    ElectricalCableRecord(id: 'c2', circuitId: 'g1',
        fromPointId: 'j', toPointId: 'p', description: 'Кабель 2',
        cores: [ElectricalCableCore(id: '1')]),
    ElectricalCableRecord(id: 'c3', circuitId: 'g2',
        fromPointId: 'j', toPointId: 'p', route3dId: 'r3',
        cores: [ElectricalCableCore(id: '1')]),
  ], routes3d: [
    ElectricalRoute3d(id: 'r1', fromPointId: 'j', toPointId: 's',
        vertices: const [
          ElectricalRouteVertex(xMm: 0, yMm: 0, zMm: 300),
          ElectricalRouteVertex(xMm: 1000, yMm: 0, zMm: 300),
        ], methods: [ElectricalInstallationMethod.inWall],
        source: ElectricalPathSource.drawing),
    ElectricalRoute3d(id: 'r3', fromPointId: 'j', toPointId: 'p',
        vertices: const [
          ElectricalRouteVertex(xMm: 0, yMm: 0, zMm: 300),
          ElectricalRouteVertex(xMm: 0, yMm: 1999, zMm: 300),
        ], methods: [ElectricalInstallationMethod.inWall],
        source: ElectricalPathSource.drawing),
  ]);
  return floor;
}

void main() {
  test('journal never converts legacy drawn runs into physical cables', () {
    final floor = journalFixture();
    floor.electricalNetwork = null;
    final j = ElectricalCableJournalService.create(floor);
    expect(j.rows, isEmpty);
    expect(j.totals.cableCount, 0);
    expect(j.totals.complete, false);
  });

  test('counts each explicit cable once, with honest incomplete total', () {
    final j = ElectricalCableJournalService.create(journalFixture());
    expect(j.totals.cableCount, 3);
    expect(j.totals.routedCount, 1);
    expect(j.totals.unknownRouteCount, 1);
    expect(j.totals.invalidRouteCount, 1);
    expect(j.totals.knownGeometricMm, 1000);
    expect(j.totals.knownWithReserveMm, 1250);
    expect(j.totals.complete, false);
    expect(j.rows.where((r) => r.cable.id == 'c3').single.status,
        CableJournalStatus.invalidRoute);
    expect(j.rows.where((r) => r.cable.id == 'c2').single.withReserveMm, isNull);
  });

  test('groups filter by stable circuit ID, not legacy name', () {
    final floor = journalFixture();
    final j = ElectricalCableJournalService.create(floor, circuitId: 'g1');
    expect(j.rows.map((r) => r.cable.id), ['c1', 'c2']);
    expect(j.groups.keys.toList(), ['g1']);
    expect(j.totals.knownGeometricMm, 1000);
    expect(j.totals.unknownRouteCount, 1);
  });

  test('unknown reserve stays unknown even with a valid route', () {
    final floor = journalFixture();
    final network = floor.electricalNetwork!;
    final c = network.cables.first;
    c.explicitReserveMm = null;
    final j = ElectricalCableJournalService.create(floor, circuitId: 'g1');
    expect(j.totals.knownGeometricMm, 1000);
    expect(j.totals.knownWithReserveMm, 0);
    expect(j.totals.unknownReserveCount, 1);
    expect(j.totals.complete, false);
  });

  test('explicit zero reserve counts as known, but not as 0 geometry', () {
    final floor = journalFixture();
    final network = floor.electricalNetwork!;
    network.cables.removeRange(1, 3);
    network.cables.single.explicitReserveMm = 0;
    final j = ElectricalCableJournalService.create(floor);
    expect(j.totals.cableCount, 1);
    expect(j.totals.knownWithReserveMm, 1000);
    expect(j.totals.complete, true);
  });

  test('changing point geometry invalidates journal and overlay routing', () {
    final floor = journalFixture();
    floor.electricalPoints.first.xMm = 50;
    final j = ElectricalCableJournalService.create(floor, circuitId: 'g1');
    expect(j.rows.first.status, CableJournalStatus.invalidRoute);
    expect(j.totals.knownGeometricMm, 0);
    expect(j.totals.complete, false);
  });

  test('two physical cables sharing geometry count as two cables', () {
    final floor = journalFixture();
    final n = floor.electricalNetwork!;
    n.cables.add(ElectricalCableRecord(
        id: 'c4', circuitId: 'g1', fromPointId: 'j', toPointId: 's',
        route3dId: 'r1', explicitReserveMm: 100));
    final j = ElectricalCableJournalService.create(floor, circuitId: 'g1');
    expect(j.totals.knownGeometricMm, 2000);
    expect(j.totals.knownWithReserveMm, 2350);
    expect(j.totals.cableCount, 3);
  });

  testWidgets('journal shows missing routes without inventing total', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? chosen = 'g1';
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalCableJournalSheet(
        floor: journalFixture(),
        initialCircuitId: 'g1',
        onCircuitChanged: (v) => chosen = v,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Кабельный журнал'), findsOneWidget);
    expect(find.byKey(const ValueKey('cable-journal-incomplete')), findsOneWidget);
    expect(chosen, 'g1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded electrical mode exposes routes and journal actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = journalFixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(
          floor: floor, embedded: true, onChanged: () async {}),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-toggle-physical-routes')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-cable-journal')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('electrical-toggle-physical-routes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-cable-journal')));
    await tester.pumpAndSettle();
    expect(find.text('Кабельный журнал'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
