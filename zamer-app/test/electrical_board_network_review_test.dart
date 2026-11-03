import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_board_network_review_service.dart';

FloorPlan fixture() {
  final floor = FloorPlan(id: 'floor', name: 'Квартира', electricalPoints: [
    ElectricalPoint(id: 'panel', type: ElectricalPointType.panel,
        xMm: 0, yMm: 0, heightMm: 300, label: 'ЩР'),
    ElectricalPoint(id: 'rk', type: ElectricalPointType.junctionBox,
        xMm: 1000, yMm: 0, heightMm: 300),
    ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 2000, yMm: 0, heightMm: 300),
  ]);
  floor.electricalNetwork = ElectricalNetwork(
    circuits: [
      ElectricalCircuitRecord(
        id: 'C', name: 'Розеточная группа',
        kind: ElectricalCircuitKind.power,
        sourcePanelPointId: 'panel'),
    ],
    cables: [
      ElectricalCableRecord(
        id: 'feed', circuitId: 'C',
        fromPointId: 'panel', toPointId: 'rk',
        route3dId: 'feed-route', explicitReserveMm: 100,
        cores: [ElectricalCableCore(
          id: 'L', purpose: ElectricalCorePurpose.phase)]),
      ElectricalCableRecord(
        id: 'branch', circuitId: 'C',
        fromPointId: 'rk', toPointId: 'socket',
        route3dId: 'branch-route', explicitReserveMm: 150,
        cores: [ElectricalCableCore(
          id: 'L', purpose: ElectricalCorePurpose.phase)]),
    ],
    routes3d: [
      ElectricalRoute3d(
        id: 'feed-route', fromPointId: 'panel', toPointId: 'rk',
        vertices: const [
          ElectricalRouteVertex(xMm: 0, yMm: 0, zMm: 300),
          ElectricalRouteVertex(xMm: 1000, yMm: 0, zMm: 300),
        ],
        methods: const [ElectricalInstallationMethod.inWall],
      ),
      ElectricalRoute3d(
        id: 'branch-route', fromPointId: 'rk', toPointId: 'socket',
        vertices: const [
          ElectricalRouteVertex(xMm: 1000, yMm: 0, zMm: 300),
          ElectricalRouteVertex(xMm: 2000, yMm: 0, zMm: 300),
        ],
        methods: const [ElectricalInstallationMethod.inWall],
      ),
    ],
    terminals: [
      ElectricalTerminalRecord(
        id: 'join', junctionPointId: 'rk', members: const [
          ElectricalCoreReference(cableId: 'feed', coreId: 'L'),
          ElectricalCoreReference(cableId: 'branch', coreId: 'L'),
        ]),
    ],
  );
  return floor;
}

void main() {
  test('legacy lines without explicit network are not reported as cables', () {
    final floor = FloorPlan(id: 'empty', name: 'Legacy', electricalPoints: [
      ElectricalPoint(id: 'a', type: ElectricalPointType.socket,
          xMm: 0, yMm: 0, circuit: 'C'),
      ElectricalPoint(id: 'b', type: ElectricalPointType.socket,
          xMm: 1000, yMm: 0, circuit: 'C'),
    ], electricalRuns: [
      ElectricalRun(id: 'legacy', startPointId: 'a', endPointId: 'b'),
    ]);
    final result = ElectricalBoardNetworkReviewService.create(floor);
    expect(result.hasNetwork, isFalse);
    expect(result.circuits, isEmpty);
    expect(result.readyForInstallation, isFalse);
  });

  test('physical cable totals remain separate from legacy 2D runs', () {
    final floor = fixture();
    floor.electricalRuns.add(ElectricalRun(
      id: 'legacy', startPointId: 'panel', endPointId: 'socket',
      reservePct: 80, routeMode: 'orthogonal',
    ));
    final snapshot = floor.toJson().toString();
    final report = ElectricalBoardNetworkReviewService.create(floor);
    final row = report.circuits.single;
    expect(row.name, 'Розеточная группа');
    expect(row.panelLabel, 'ЩР');
    expect(row.cableCount, 2);
    expect(row.routedCount, 2);
    expect(row.knownGeometricMm, 2000);
    expect(row.knownWithReserveMm, 2250);
    expect(row.needsReview, isFalse);
    expect(row.readyForInstallation, isFalse);
    expect(floor.toJson().toString(), snapshot);
  });

  test('missing physical path blocks a total without pretending 0 cable', () {
    final floor = fixture();
    floor.electricalNetwork!.cables.last.route3dId = null;
    final row = ElectricalBoardNetworkReviewService.create(floor)
        .circuits.single;
    expect(row.cableCount, 2);
    expect(row.routedCount, 1);
    expect(row.missingRouteCount, 1);
    expect(row.knownGeometricMm, 1000);
    expect(row.knownWithReserveMm, isNull);
    expect(row.messages.join(' '), contains('Без 3D-трассы'));
  });

  test('moved endpoint makes route invalid and total unknown', () {
    final floor = fixture();
    floor.electricalPoints.last.xMm += 300;
    final snapshot = floor.toJson().toString();
    final row = ElectricalBoardNetworkReviewService.create(floor)
        .circuits.single;
    expect(row.invalidRouteCount, 1);
    expect(row.knownWithReserveMm, isNull);
    expect(row.messages.join(' '), contains('Недействительных'));
    expect(floor.toJson().toString(), snapshot);
  });

  test('missing source panel is never inferred from nearby equipment', () {
    final floor = fixture();
    floor.electricalNetwork!.circuits.single.sourcePanelPointId = null;
    final row = ElectricalBoardNetworkReviewService.create(floor)
        .circuits.single;
    expect(row.hasValidPanel, isFalse);
    expect(row.panelLabel, 'Не назначен');
    expect(row.messages.join(' '), contains('щит-источник'));
  });

  test('duplicate circuit ids must not claim reliable lengths', () {
    final floor = fixture();
    floor.electricalNetwork!.circuits.add(ElectricalCircuitRecord(
      id: 'C', name: 'Дубликат', kind: ElectricalCircuitKind.power,
      sourcePanelPointId: 'panel',
    ));
    final snapshot = floor.toJson().toString();
    final rows = ElectricalBoardNetworkReviewService.create(floor).circuits;
    expect(rows, hasLength(2));
    expect(rows.every((e) => e.hasAmbiguousId), isTrue);
    expect(rows.every((e) => e.knownWithReserveMm == null), isTrue);
    expect(rows.every((e) =>
        e.messages.any((m) => m.contains('Повторный'))), isTrue);
    expect(floor.toJson().toString(), snapshot);
  });

  testWidgets('existing board tabs show physical records without new tabs',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    final before = floor.toJson().toString();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(
        floor: floor, embedded: true, onChanged: () async {},
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-view-board')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-board-three-tabs')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('electrical-board-tab-wiring')));
    await tester.pumpAndSettle();
    expect(find.byKey(
        const ValueKey('board-physical-circuits-title')), findsOneWidget);
    expect(find.byKey(
        const ValueKey('board-network-circuit-C')), findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('electrical-board-tab-checks')));
    await tester.pumpAndSettle();
    expect(find.byKey(
        const ValueKey('board-network-checks-title')), findsOneWidget);
    expect(find.byKey(
        const ValueKey('board-network-check-C')), findsOneWidget);
    expect(floor.toJson().toString(), before);
    expect(tester.takeException(), isNull);
  });
}
