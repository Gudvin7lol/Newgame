import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_junction_capacity.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_junction_capacity_service.dart';
import 'package:zamer_app/services/electrical_junction_connection_proposal_service.dart';
import 'package:zamer_app/services/electrical_junction_edit_service.dart';
import 'package:zamer_app/widgets/electrical_junction_editor.dart';

FloorPlan project() {
  final floor = FloorPlan(id:'f',name:'Этаж');
  floor.nodes.addAll([
    PlanNode(id:'a',xMm:0,yMm:0),
    PlanNode(id:'b',xMm:4000,yMm:0),
  ]);
  floor.walls.add(PlanWall(id:'w',startNodeId:'a',endNodeId:'b'));
  floor.electricalPoints.addAll([
    ElectricalPoint(id:'rk',type:ElectricalPointType.junctionBox,
      xMm:1800,yMm:0,wallId:'w',wallOffsetMm:1800,
      heightMm:2500,wallSide:1),
    ElectricalPoint(id:'s1',type:ElectricalPointType.socket,
      xMm:700,yMm:0,wallId:'w',wallOffsetMm:700,wallSide:1),
    ElectricalPoint(id:'s2',type:ElectricalPointType.socket,
      xMm:3300,yMm:0,wallId:'w',wallOffsetMm:3300,wallSide:1),
  ]);
  floor.electricalNetwork = ElectricalNetwork(
    circuits:[ElectricalCircuitRecord(id:'C1',name:'Розетки')],
    cables:[
      ElectricalCableRecord(
        id:'in',circuitId:'C1',fromPointId:'s1',toPointId:'rk',
        cores:[
          ElectricalCableCore(id:'1',purpose:ElectricalCorePurpose.phase),
          ElectricalCableCore(id:'2',purpose:ElectricalCorePurpose.neutral),
          ElectricalCableCore(id:'3',purpose:ElectricalCorePurpose.protectiveEarth),
        ],
      ),
      ElectricalCableRecord(
        id:'out',circuitId:'C1',fromPointId:'rk',toPointId:'s2',
        cores:[
          ElectricalCableCore(id:'1',purpose:ElectricalCorePurpose.phase),
          ElectricalCableCore(id:'2',purpose:ElectricalCorePurpose.neutral),
          ElectricalCableCore(id:'3',purpose:ElectricalCorePurpose.protectiveEarth),
        ],
      ),
    ],
  );
  return floor;
}

void main() {
  test('unknown ratings remain unknown and legacy JSON is unchanged', () {
    final floor = project();
    final network = floor.electricalNetwork!;
    final report = ElectricalJunctionCapacityService.inspect(
      floor,network,'rk');
    expect(report.cableEntries,2);
    expect(report.conductorEnds,6);
    expect(report.connectorCount,0);
    expect(report.unassignedEnds,6);
    expect(report.enteredLimits,isFalse);
    expect(report.incomplete,isTrue);
    expect(report.isApproved,isFalse);
    expect(report.exceeded,isFalse);
    expect(network.toJson().containsKey('junctionCapacities'),isFalse);
    final restored = ElectricalNetwork.fromJson(network.toJson());
    expect(restored.junctionCapacities,isEmpty);
  });

  test('limits round-trip and exceeding one of them blocks saving', () {
    final floor = project();
    final network = floor.electricalNetwork!;
    network.junctionCapacities['rk'] = const ElectricalJunctionCapacity(
      junctionPointId:'rk',boxModel:'Из паспорта A',
      maxCableEntries:1,maxConductorEnds:8,
      maxConnectorCount:3,maxEndsPerConnector:3,
    );
    expect(ElectricalJunctionCapacityService.inspect(
      floor,network,'rk').violations.single,contains('Кабельных'));
    expect(() => ElectricalJunctionEditService.validateForSave(
        floor,'rk',network),throwsFormatException);
    final restored = FloorPlan.fromJson(floor.toJson());
    expect(restored.electricalNetwork!.junctionCapacities['rk']!
        .boxModel,'Из паспорта A');
    network.junctionCapacities['rk'] = const ElectricalJunctionCapacity(
      junctionPointId:'rk',maxCableEntries:3,maxConductorEnds:6,
      maxConnectorCount:3,maxEndsPerConnector:2,
    );
    expect(ElectricalJunctionCapacityService.inspect(
        floor,network,'rk').exceeded,isFalse);
  });

  test('saving a different junction does not bypass another boxes limits', () {
    final floor = project();
    floor.electricalPoints.add(ElectricalPoint(
      id:'rk2', type:ElectricalPointType.junctionBox,
      xMm:2200, yMm:0, wallId:'w', wallOffsetMm:2200,
      wallSide:1, heightMm:2500,
    ));
    final draft = ElectricalJunctionEditService.copy(floor.electricalNetwork);
    draft.cables.addAll([
      ElectricalCableRecord(id:'x1',circuitId:'C1',
        fromPointId:'s1',toPointId:'rk2'),
      ElectricalCableRecord(id:'x2',circuitId:'C1',
        fromPointId:'rk2',toPointId:'s2'),
    ]);
    draft.junctionCapacities['rk2'] = const ElectricalJunctionCapacity(
      junctionPointId:'rk2', maxCableEntries:1,
    );
    expect(() => ElectricalJunctionEditService.validateForSave(
        floor,'rk',draft),throwsFormatException);
    expect(floor.electricalNetwork!.cables,hasLength(2));
    expect(floor.electricalNetwork!.junctionCapacities,isEmpty);
  });

  test('reject orphan or mismatched junction capacity records', () {
    final floor=project();
    final draft=ElectricalJunctionEditService.copy(floor.electricalNetwork);
    draft.junctionCapacities['ghost'] =
        const ElectricalJunctionCapacity(junctionPointId:'ghost');
    expect(() => ElectricalJunctionEditService.validateForSave(
        floor,'rk',draft),throwsFormatException);
    draft.junctionCapacities
      ..clear()
      ..['rk'] = const ElectricalJunctionCapacity(
          junctionPointId:'ghost',maxCableEntries:3);
    expect(() => ElectricalJunctionEditService.validateForSave(
        floor,'rk',draft),throwsFormatException);
    expect(floor.electricalNetwork!.junctionCapacities,isEmpty);
  });

  test('only explicit circuit+purpose members from different cables proposed', () {
    final floor = project();
    final network = floor.electricalNetwork!;
    final suggestions = ElectricalJunctionConnectionProposalService.propose(
        floor,network,'rk');
    expect(suggestions,hasLength(3));
    expect(suggestions.map((p)=>p.purpose).toSet(),{
      ElectricalCorePurpose.phase,
      ElectricalCorePurpose.neutral,
      ElectricalCorePurpose.protectiveEarth,
    });
    expect(suggestions.every((p)=>p.members.length==2),isTrue);
    expect(network.terminals,isEmpty);
    expect(suggestions.every((p)=>p.warnings.isNotEmpty),isTrue);
    network.cables[1].cores[0].purpose=ElectricalCorePurpose.unspecified;
    expect(ElectricalJunctionConnectionProposalService.propose(
        floor,network,'rk'),hasLength(2));
  });

  test('no cross-circuit connections and stale proposal cannot be reused', () {
    final floor = project();
    final network = floor.electricalNetwork!;
    final suggestions = ElectricalJunctionConnectionProposalService.propose(
        floor,network,'rk');
    final one = suggestions.first;
    network.circuits.add(ElectricalCircuitRecord(id:'C2',name:'Вторая'));
    network.cables.last.circuitId = 'C2';
    expect(ElectricalJunctionConnectionProposalService.propose(
        floor,network,'rk'),isEmpty);
    expect(() => ElectricalJunctionConnectionProposalService.requireCurrent(
        floor,network,'rk',one),throwsFormatException);
  });

  test('configured connector limits reject oversized proposed bond', () {
    final floor=project();
    final network=floor.electricalNetwork!;
    network.junctionCapacities['rk'] = const ElectricalJunctionCapacity(
      junctionPointId:'rk',maxCableEntries:3,maxConductorEnds:6,
      maxConnectorCount:2,maxEndsPerConnector:1,
    );
    expect(ElectricalJunctionConnectionProposalService.propose(
        floor,network,'rk'),isEmpty);
    expect(network.terminals,isEmpty);
  });

  test('user-entered limits do not prove box safety after model validation', () {
    final floor=project();
    final network=floor.electricalNetwork!;
    network.junctionCapacities['rk']=const ElectricalJunctionCapacity(
      junctionPointId:'rk',maxCableEntries:10,maxConductorEnds:10,
      maxConnectorCount:10,maxEndsPerConnector:10,
    );
    final report=ElectricalJunctionCapacityService.inspect(
        floor,network,'rk');
    expect(report.exceeded,isFalse);
    expect(report.isApproved,isFalse);
    expect(report.incomplete,isTrue);
    expect(report.missing,contains(contains('габариты')));
    expect(report.missing,contains(contains('паспортная модель')));
  });

  testWidgets('connection proposal requires two explicit approvals',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor=project();
    await tester.pumpWidget(MaterialApp(home:ElectricalJunctionEditor(
      floor:floor,junctionPointId:'rk',
    )));
    await tester.pumpAndSettle();
    // The button is in a lazily built ListView, so ensureVisible()
    // cannot find it until its child has actually been laid out.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('junction-review-connections')),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await tester.tap(find.byKey(
        const ValueKey('junction-review-connections')));
    await tester.pumpAndSettle();
    final option=find.byKey(const ValueKey('junction-proposal-0'));
    expect(option,findsOneWidget);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('junction-proposal-accept')),
        findsOneWidget);
    expect(floor.electricalNetwork!.terminals,isEmpty);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();
    expect(floor.electricalNetwork!.terminals,isEmpty);
    expect(tester.takeException(),isNull);
  });
}
