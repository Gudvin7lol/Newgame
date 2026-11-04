import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_interroom_passage_proposal_service.dart';
import 'package:zamer_app/services/electrical_route_service.dart';
import 'package:zamer_app/widgets/electrical_route_editor.dart';

FloorPlan rooms() {
  final floor = FloorPlan(id: 'two', name: 'Две комнаты');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
    PlanNode(id: 'e', xMm: 7000, yMm: 0),
    PlanNode(id: 'f', xMm: 7000, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'left-top', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'shared', startNodeId: 'b', endNodeId: 'c',
      thicknessMm: 200, openings: [
        WallOpening(id: 'door', type: OpeningType.door,
          offsetFromStartMm: 1000, widthMm: 900,
          heightMm: 2100),
      ]),
    PlanWall(id: 'left-bottom', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'left-end', startNodeId: 'd', endNodeId: 'a'),
    PlanWall(id: 'right-top', startNodeId: 'b', endNodeId: 'e'),
    PlanWall(id: 'right-end', startNodeId: 'e', endNodeId: 'f'),
    PlanWall(id: 'right-bottom', startNodeId: 'f', endNodeId: 'c'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(id: 'start', type: ElectricalPointType.socket,
      xMm: 2000, yMm: 0, heightMm: 300,
      wallId: 'left-top', wallOffsetMm: 2000, wallSide: 1),
    ElectricalPoint(id: 'finish', type: ElectricalPointType.socket,
      xMm: 6000, yMm: 0, heightMm: 300,
      wallId: 'right-top', wallOffsetMm: 2000, wallSide: 1),
  ]);
  return floor;
}

ElectricalCableRecord cable({String? route3dId}) =>
  ElectricalCableRecord(id: 'cable', circuitId: 'C1',
      fromPointId: 'start', toPointId: 'finish', route3dId: route3dId);

void main() {
  test('requires explicitly named door and keeps the project immutable', () {
    final floor = rooms();
    final before = floor.toJson().toString();
    expect(() => ElectricalInterroomPassageProposalService.prepare(
        floor, cable(),
        passageWallId: 'shared', openingId: 'door',
        explicitlySelected: false), throwsFormatException);
    final route = ElectricalInterroomPassageProposalService.prepare(
      floor, cable(), passageWallId: 'shared',
      openingId: 'door', explicitlySelected: true,
    );
    expect(route.source, ElectricalPathSource.unspecified);
    expect(route.note, contains('НЕ обмерены'));
    expect(route.vertices.any((v) =>
        v.xMm == 3900 && v.yMm == 1450 && v.zMm == 2550), isTrue);
    expect(route.vertices.any((v) =>
        v.xMm == 4100 && v.yMm == 1450 && v.zMm == 2550), isTrue);
    expect(ElectricalRouteService.measure(floor, route).geometricMm,
        greaterThan(4000));
    expect(floor.toJson().toString(), before);
  });

  test('fails for non-shared door, solid opening, impossible height', () {
    final floor = rooms();
    expect(() => ElectricalInterroomPassageProposalService.prepare(
      floor, cable(), passageWallId: 'left-top',
      openingId: 'non-existent', explicitlySelected: true,
    ), throwsFormatException);
    floor.walls.where((w) => w.id == 'shared').single
      .openings.single.heightMm = 2500;
    expect(() => ElectricalInterroomPassageProposalService.prepare(
      floor, cable(), passageWallId: 'shared',
      openingId: 'door', explicitlySelected: true,
    ), throwsFormatException);
  });

  test('never replaces a manual cable route', () {
    final floor = rooms();
    expect(() => ElectricalInterroomPassageProposalService.prepare(
      floor, cable(route3dId: 'manual'),
      passageWallId: 'shared', openingId: 'door',
      explicitlySelected: true,
    ), throwsFormatException);
    expect(floor.electricalNetwork, isNull);
  });

  test('refuses same-room or incomplete room geometry', () {
    final floor = rooms();
    floor.electricalPoints.last
      ..wallId = 'left-top'
      ..wallOffsetMm = 3000
      ..xMm = 3000;
    expect(() => ElectricalInterroomPassageProposalService.prepare(
      floor, cable(), passageWallId: 'shared',
      openingId: 'door', explicitlySelected: true,
    ), throwsFormatException);
    final broken = rooms();
    broken.walls.removeWhere((w) => w.id == 'right-bottom');
    expect(() => ElectricalInterroomPassageProposalService.prepare(
      broken, cable(), passageWallId: 'shared',
      openingId: 'door', explicitlySelected: true,
    ), throwsFormatException);
  });

  testWidgets('choosing and accepting a passage never persists by itself',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = rooms();
    final snapshot = floor.toJson().toString();
    final record = cable();
    await tester.pumpWidget(MaterialApp(
      home: ElectricalRouteEditor(floor: floor, cable: record),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('route-interroom-propose'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-passage-opening')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('route-passage-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-passage-accept')),
        findsOneWidget);
    expect(floor.toJson().toString(), snapshot);
    await tester.tap(find.byKey(
        const ValueKey('route-passage-accept')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(floor.toJson().toString(), snapshot);
    expect(record.route3dId, isNull);
    expect(tester.takeException(), isNull);
  });
}
