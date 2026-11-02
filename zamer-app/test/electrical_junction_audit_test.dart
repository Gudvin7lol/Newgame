import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_junction_capacity.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_junction_audit_service.dart';
import 'package:zamer_app/widgets/electrical_junction_audit_sheet.dart';

FloorPlan fixture() {
  final floor=FloorPlan(id:'f',name:'Этаж');
  floor.electricalPoints.addAll([
    ElectricalPoint(id:'rk1',type:ElectricalPointType.junctionBox,
      xMm:1200,yMm:0,heightMm:2500),
    ElectricalPoint(id:'rk2',type:ElectricalPointType.junctionBox,
      xMm:3400,yMm:0,heightMm:2500),
    ElectricalPoint(id:'s1',type:ElectricalPointType.socket,
      xMm:700,yMm:0),
    ElectricalPoint(id:'s2',type:ElectricalPointType.socket,
      xMm:3700,yMm:0),
  ]);
  floor.electricalNetwork=ElectricalNetwork(
    circuits: [
      ElectricalCircuitRecord(id:'A',name:'A'),
      ElectricalCircuitRecord(id:'B',name:'B'),
    ],
    cables: [
      ElectricalCableRecord(id:'a',circuitId:'A',
        fromPointId:'s1',toPointId:'rk1',
        cores:[ElectricalCableCore(id:'L',
          purpose:ElectricalCorePurpose.phase)]),
      ElectricalCableRecord(id:'b',circuitId:'B',
        fromPointId:'rk1',toPointId:'s2',
        cores:[ElectricalCableCore(id:'L',
          purpose:ElectricalCorePurpose.neutral)]),
      ElectricalCableRecord(id:'c',circuitId:'A',
        fromPointId:'s1',toPointId:'rk2',
        cores:[ElectricalCableCore(id:'L',
          purpose:ElectricalCorePurpose.phase)]),
      ElectricalCableRecord(id:'d',circuitId:'A',
        fromPointId:'rk2',toPointId:'s2',
        cores:[ElectricalCableCore(id:'L',
          purpose:ElectricalCorePurpose.phase)]),
    ],
    terminals: [
      ElectricalTerminalRecord(
        id:'T',junctionPointId:'rk1',
        members:[
          const ElectricalCoreReference(cableId:'a',coreId:'L'),
          const ElectricalCoreReference(cableId:'b',coreId:'L'),
        ],
      ),
    ],
  );
  return floor;
}

void main() {
  test('whole-floor audit finds separate boxes and cross-circuit fault', () {
    final floor=fixture();
    final snapshot=floor.toJson().toString();
    final result=ElectricalJunctionAuditService.inspect(floor);
    expect(result.boxes,2);
    expect(result.blocked,1);
    expect(result.toReview,2);
    expect(result.entries.first.errors.join(' '),contains('разные цепи'));
    expect(result.entries.first.errors.join(' '),contains('функции жил'));
    expect(result.entries.last.capacity!.unassignedEnds,2);
    expect(result.approved,isFalse);
    expect(floor.toJson().toString(),snapshot);
  });

  test('capacity limit in a different RK is visible without opening it', () {
    final floor=fixture();
    floor.electricalNetwork!.junctionCapacities['rk2'] =
        const ElectricalJunctionCapacity(
          junctionPointId:'rk2',
          boxModel:'Паспортная модель',
          maxCableEntries:1,
        );
    final result=ElectricalJunctionAuditService.inspect(floor);
    final second=result.entries.singleWhere((r)=>r.junctionId=='rk2');
    expect(second.blocked,isTrue);
    expect(second.errors.join(' '),contains('Кабельных'));
  });

  test('orphaned capacity and terminal never disappear from audit', () {
    final floor=fixture();
    floor.electricalNetwork!.junctionCapacities['missing'] =
        const ElectricalJunctionCapacity(
          junctionPointId:'missing',maxCableEntries:2);
    floor.electricalNetwork!.terminals.add(
      ElectricalTerminalRecord(id:'ghost',junctionPointId:'unknown'));
    final result=ElectricalJunctionAuditService.inspect(floor);
    expect(result.globalErrors,hasLength(2));
    expect(result.hasBlockingIssues,isTrue);
  });

  test('even empty box is unknown, not automatically approved', () {
    final floor=FloorPlan(id:'one',name:'План',
      electricalPoints:[
        ElectricalPoint(id:'rk',type:ElectricalPointType.junctionBox,
          xMm:0,yMm:0),
      ],
    );
    final result=ElectricalJunctionAuditService.inspect(floor);
    expect(result.entries.single.errors,isEmpty);
    expect(result.entries.single.needsReview,isTrue);
    expect(result.approved,isFalse);
  });

  testWidgets('audit sheet shows capacity and selects box without mutation',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor=fixture();
    final before=floor.toJson().toString();
    String? selected;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ElectricalJunctionAuditSheet(
        floor:floor,
        onSelectJunction:(id) => selected=id,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('junction-audit-summary')),
      findsOneWidget);
    final first=find.byKey(const ValueKey('junction-audit-rk1'));
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('junction-audit-select-rk1')));
    await tester.pumpAndSettle();
    expect(selected,'rk1');
    expect(floor.toJson().toString(),before);
    expect(tester.takeException(),isNull);
  });
}
