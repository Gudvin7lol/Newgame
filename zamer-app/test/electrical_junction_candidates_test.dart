import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/models/electrical_route_exclusion_zone.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_junction_candidate_service.dart';
import 'package:zamer_app/services/electrical_route_exclusion_service.dart';
import 'package:zamer_app/widgets/electrical_junction_candidates_sheet.dart';

FloorPlan fixture() {
  final floor = FloorPlan(id: 'floor', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id:'a',xMm:0,yMm:0), PlanNode(id:'b',xMm:4000,yMm:0),
    PlanNode(id:'c',xMm:4000,yMm:3000), PlanNode(id:'d',xMm:0,yMm:3000),
  ]);
  floor.walls.addAll([
    PlanWall(id:'w1',startNodeId:'a',endNodeId:'b'),
    PlanWall(id:'w2',startNodeId:'b',endNodeId:'c'),
    PlanWall(id:'w3',startNodeId:'c',endNodeId:'d'),
    PlanWall(id:'w4',startNodeId:'d',endNodeId:'a'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(id:'s1',type:ElectricalPointType.socket,
      xMm:900,yMm:0,wallId:'w1',wallOffsetMm:900,wallSide:1,
      heightMm:300,circuit:'К1'),
    ElectricalPoint(id:'s2',type:ElectricalPointType.socket,
      xMm:3200,yMm:0,wallId:'w1',wallOffsetMm:3200,wallSide:1,
      heightMm:300,circuit:'К1'),
    ElectricalPoint(id:'l1',type:ElectricalPointType.ceilingLight,
      xMm:2000,yMm:1500,heightMm:2600,circuit:'К1'),
    ElectricalPoint(id:'d1',type:ElectricalPointType.dataSocket,
      xMm:500,yMm:0,wallId:'w1',wallOffsetMm:500,wallSide:1,
      heightMm:300,circuit:'К1'),
  ]);
  return floor;
}
ElectricalRouteExclusionZone blockAll() => const ElectricalRouteExclusionZone(
  id:'b',name:'Пространство коммуникаций',
  minXMm:-100,maxXMm:5000,
  minYMm:-100,maxYMm:4000,
  minZMm:2400,maxZMm:2600,
);

void main() {
  test('candidate is room- and load-class-specific, without adding wiring', () {
    final floor = fixture();
    final before = floor.toJson().toString();
    final options = ElectricalJunctionCandidateService.propose(floor);
    expect(options, hasLength(1));
    final candidate = options.single;
    expect(candidate.circuitLabel, 'К1');
    expect(candidate.loadClass, 'силовая');
    expect(candidate.consumerIds.toSet(), {'s1','s2'});
    expect(candidate.wallId, isNotEmpty);
    expect(candidate.heightMm, 2500);
    expect(candidate.warnings, isNotEmpty);
    expect(floor.toJson().toString(), before);
    expect(floor.electricalNetwork, isNull);
  });

  test('verified placement creates only junction point, no cables or terminals', () {
    final floor = fixture();
    final candidate = ElectricalJunctionCandidateService.propose(floor).single;
    final preview = ElectricalJunctionCandidateService.preparePlacement(
      floor, candidate, id:'new-rk',
    );
    expect(preview.type, ElectricalPointType.junctionBox);
    expect(preview.wallId, candidate.wallId);
    expect(preview.wallSide, candidate.wallSide);
    expect(preview.heightMm, candidate.heightMm);
    expect(preview.circuit, 'К1');
    expect(floor.electricalPoints, hasLength(4));
    floor.electricalPoints.add(preview);
    expect(ElectricalJunctionCandidateService.propose(floor), isEmpty);
    expect(floor.electricalNetwork, isNull);
  });

  test('explicit exclusion makes stale candidate invalid and blocks search', () {
    final floor = fixture();
    final old = ElectricalJunctionCandidateService.propose(floor).single;
    floor.electricalNetwork = ElectricalNetwork();
    ElectricalRouteExclusionService.add(floor,blockAll());
    expect(ElectricalJunctionCandidateService.propose(floor), isEmpty);
    expect(() => ElectricalJunctionCandidateService.preparePlacement(
      floor, old, id:'rk'), throwsFormatException);
    expect(floor.electricalPoints, hasLength(4));
  });

  test('do not propose where the room is open or consumer groups are mixed', () {
    final floor = fixture();
    floor.walls.removeLast();
    expect(ElectricalJunctionCandidateService.propose(floor),isEmpty);
    final separate = fixture();
    separate.electricalPoints[1].circuit = 'К2';
    expect(ElectricalJunctionCandidateService.propose(separate),isEmpty);
    expect(() => ElectricalJunctionCandidateService.propose(fixture(),
        maxCandidates:0), throwsFormatException);
  });

  test('skip dedicated or wet consumers instead of inventing a shared RK', () {
    final floor = fixture();
    floor.electricalDesignDraft = ElectricalDesignDraft(consumers: {
      's1': const ElectricalConsumerDraft(
          pointId: 's1', isDedicated: true),
    });
    expect(ElectricalJunctionCandidateService.propose(floor), isEmpty);
    floor.electricalDesignDraft!.consumers['s1'] =
        const ElectricalConsumerDraft(pointId: 's1', isWetZone: true);
    expect(ElectricalJunctionCandidateService.propose(floor), isEmpty);
  });

  test('separate power and lighting boxes without duplicated power box', () {
    final floor = fixture();
    floor.electricalPoints.add(ElectricalPoint(
      id: 'l2',type: ElectricalPointType.ceilingLight,
      xMm: 2500,yMm:1200,heightMm:2600,circuit:'К1',
    ));
    final initial = ElectricalJunctionCandidateService.propose(floor);
    expect(initial.map((c) => c.loadClass).toSet(),
      {'силовая','освещение'});
    final power = initial.firstWhere((c) => c.loadClass == 'силовая');
    floor.electricalPoints.add(power.asPoint('installed-power-box'));
    final remaining = ElectricalJunctionCandidateService.propose(floor);
    expect(remaining, hasLength(1));
    expect(remaining.single.loadClass, 'освещение');
  });

  test('data-only frame is not mistaken for a powered consumer', () {
    final floor = fixture();
    floor.electricalPoints[1]
      ..type = ElectricalPointType.frame
      ..modules.clear()
      ..modules.addAll([
        ElectricalModuleType.data, ElectricalModuleType.tv,
      ]);
    expect(ElectricalJunctionCandidateService.propose(floor), isEmpty);
  });

  test('existing junction on the same provisional circuit prevents duplicate', () {
    final floor = fixture();
    final suggestion = ElectricalJunctionCandidateService.propose(floor).single;
    floor.electricalPoints.add(suggestion.asPoint('existing-box'));
    expect(ElectricalJunctionCandidateService.propose(floor),isEmpty);
  });

  testWidgets('candidate requires explicit confirmation; cancel never adds',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    var accepted = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalJunctionCandidatesSheet(
        floor: floor,
        onPlace: (candidate) async {
          final point = ElectricalJunctionCandidateService.preparePlacement(
            floor,candidate,id:'confirmed-junction',
          );
          floor.electricalPoints.add(point);
          accepted++;
        },
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('junction-candidate-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('junction-candidate-confirm')),
        findsOneWidget);
    expect(floor.electricalPoints,hasLength(4));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(accepted,0);
    expect(floor.electricalPoints,hasLength(4));
    await tester.tap(find.byKey(const ValueKey('junction-candidate-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('junction-candidate-confirm')));
    await tester.pumpAndSettle();
    expect(accepted,1);
    expect(floor.electricalPoints.last.type,
        ElectricalPointType.junctionBox);
    expect(floor.electricalNetwork,isNull);
    expect(tester.takeException(),isNull);
  });
}
