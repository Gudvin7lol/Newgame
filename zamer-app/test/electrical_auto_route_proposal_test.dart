import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/widgets/electrical_route_editor.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_auto_route_proposal_service.dart';
import 'package:zamer_app/services/electrical_route_service.dart';

FloorPlan _floor() {
  final floor = FloorPlan(id: 'floor', name: 'Квартира');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'wall', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'other', startNodeId: 'b', endNodeId: 'c'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(id: 'from', type: ElectricalPointType.socket,
      xMm: 500, yMm: 0, heightMm: 300, wallId: 'wall',
      wallOffsetMm: 500, wallSide: 1),
    ElectricalPoint(id: 'to', type: ElectricalPointType.socket,
      xMm: 3500, yMm: 0, heightMm: 300, wallId: 'wall',
      wallOffsetMm: 3500, wallSide: 1),
  ]);
  return floor;
}

ElectricalCableRecord _cable({String? route3dId}) =>
    ElectricalCableRecord(
      id: 'cab1', circuitId: 'k1',
      fromPointId: 'from', toPointId: 'to',
      route3dId: route3dId);

void main() {
  test('preview remains detached, axis aligned and measurable', () {
    final floor = _floor();
    final before = floor.toJson().toString();
    final cable = _cable();
    final proposal = ElectricalAutoRouteProposalService.prepare(
        floor, cable);
    expect(proposal.route.vertices, hasLength(4));
    expect(proposal.route.methods, hasLength(3));
    expect(proposal.route.methods.every(
        (m) => m == ElectricalInstallationMethod.unspecified), isTrue);
    expect(proposal.route.source, ElectricalPathSource.unspecified);
    expect(proposal.route.vertices[1].zMm, 2550);
    expect(proposal.measurement.geometricMm, closeTo(7500, .001));
    expect(proposal.measurement.procurementLengthMm, isNull);
    expect(ElectricalRouteService.measure(
        floor, proposal.route).geometricMm, 7500);
    expect(floor.toJson().toString(), before);
    expect(cable.route3dId, isNull);
  });

  test('same wall door corridor at high Z can be previewed, never approved', () {
    final floor = _floor();
    floor.walls.first.openings.add(WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 850, heightMm: 2100, offsetFromStartMm: 1400,
    ));
    final proposal = ElectricalAutoRouteProposalService.prepare(
        floor, _cable());
    expect(proposal.warnings, isNotEmpty);
    expect(proposal.route.note, contains('Не проверены'));
  });

  test('opening occupying the proposed ceiling corridor blocks route', () {
    final floor = _floor();
    floor.walls.first.openings.add(WallOpening(
      id: 'high', type: OpeningType.window,
      widthMm: 800, heightMm: 900, sillHeightMm: 1800,
      offsetFromStartMm: 1300,
    ));
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable()), throwsFormatException);
  });

  test('existing routes and manual edits are never replaced by proposal', () {
    final floor = _floor();
    final manual = ElectricalRoute3d(
      id: 'r1', fromPointId: 'from', toPointId: 'to',
      vertices: [
        const ElectricalRouteVertex(xMm: 500, yMm: 0, zMm: 300),
        const ElectricalRouteVertex(xMm: 500, yMm: 0, zMm: 2000),
      ],
      methods: [ElectricalInstallationMethod.inWall],
      source: ElectricalPathSource.measured,
    );
    final fingerprint = manual.toJson().toString();
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable(route3dId: 'r1')), throwsFormatException);
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable(), existing: manual), throwsFormatException);
    expect(manual.toJson().toString(), fingerprint);
  });

  test('different walls and angled walls require a real corridor graph', () {
    final floor = _floor();
    floor.electricalPoints.last.wallId = 'other';
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable()), throwsFormatException);
    floor.electricalPoints.last.wallId = 'wall';
    floor.nodes[1].yMm = 100;
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable()), throwsFormatException);
  });

  testWidgets('route preview is explicit and never saves by preview alone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = _floor();
    final snapshot = floor.toJson().toString();
    final cable = _cable();
    await tester.pumpWidget(MaterialApp(home: ElectricalRouteEditor(
      floor: floor, cable: cable,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-auto-propose')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('route-auto-propose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-auto-accept-preview')),
        findsOneWidget);
    expect(floor.toJson().toString(), snapshot);
    expect(cable.route3dId, isNull);
    await tester.tap(find.byKey(
        const ValueKey('route-auto-accept-preview')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(
        const ValueKey('route-auto-propose'))).onPressed, isNull);
    expect(floor.toJson().toString(), snapshot);
    expect(cable.route3dId, isNull);
    expect(tester.takeException(), isNull);
  });

  test('insufficient height and invalid parameters fail closed', () {
    final floor = _floor();
    floor.electricalPoints.last.heightMm = 2700;
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable()), throwsFormatException);
    floor.electricalPoints.last.heightMm = 300;
    expect(() => ElectricalAutoRouteProposalService.prepare(
        floor, _cable(), ceilingDropMm: -1), throwsFormatException);
  });
}
