import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/electrical_route_exclusion_zone.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_issue_register_service.dart';
import 'package:zamer_app/services/electrical_issue_locator_service.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';
import 'package:zamer_app/widgets/electrical_issue_register_sheet.dart';

FloorPlan sample() {
  final floor = FloorPlan(id: 'f', name: 'Квартира');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id:'w1',startNodeId:'a',endNodeId:'b'),
    PlanWall(id:'w2',startNodeId:'b',endNodeId:'c'),
    PlanWall(id:'w3',startNodeId:'c',endNodeId:'d'),
    PlanWall(id:'w4',startNodeId:'d',endNodeId:'a'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(id:'s1',type:ElectricalPointType.socket,
      xMm:500,yMm:0,heightMm:300,
      wallId:'w1',wallOffsetMm:500,wallSide:1),
    ElectricalPoint(id:'s2',type:ElectricalPointType.socket,
      xMm:3400,yMm:0,heightMm:300,
      wallId:'w1',wallOffsetMm:3400,wallSide:1),
    ElectricalPoint(id:'rk',type:ElectricalPointType.junctionBox,
      xMm:2000,yMm:0,heightMm:2500,
      wallId:'w1',wallOffsetMm:2000,wallSide:1),
  ]);
  floor.electricalNetwork = ElectricalNetwork(
    circuits:[ElectricalCircuitRecord(id:'C',name:'Розетки')],
    cables:[ElectricalCableRecord(
      id:'c1',circuitId:'C',fromPointId:'s1',toPointId:'rk',
      cores:[ElectricalCableCore(id:'1')],
    )],
  );
  return floor;
}

void main() {
  test('register combines missing routes, junction unknowns without mutation', () {
    final floor = sample();
    final before = floor.toJson().toString();
    final register = ElectricalIssueRegisterService.inspect(floor);
    final pending = register.entries.where(
        (e) => e.code == 'missingPhysicalRoute').single;
    expect(pending.object, ElectricalIssueObject.cable);
    expect(pending.objectId, 'c1');
    expect(pending.focusPointId, 's1');
    expect(pending.canLocate, isTrue);
    expect(register.entries.any(
        (e) => e.code == 'junctionUnverified' &&
            e.focusPointId == 'rk'),isTrue);
    expect(register.toReview,greaterThanOrEqualTo(2));
    expect(register.approved,isFalse);
    expect(floor.toJson().toString(),before);
  });

  test('wall move points directly to invalid mounted device', () {
    final floor=sample();
    floor.nodes.first.yMm=200;
    final snapshot=floor.toJson().toString();
    final register=ElectricalIssueRegisterService.inspect(floor);
    final issue=register.entries.singleWhere(
      (e) => e.code=='wallAnchor' && e.objectId=='s1',
    );
    expect(issue.severity,ElectricalIssueSeverity.error);
    expect(issue.focusPointId,'s1');
    expect(issue.description,contains('привязкой к стене'));
    expect(floor.toJson().toString(),snapshot);
  });

  test('new obstruction references saved route and linked cable', () {
    final floor=sample();
    final network=floor.electricalNetwork!;
    network.routes3d.add(ElectricalRoute3d(
      id:'path',fromPointId:'s1',toPointId:'rk',
      vertices:const [
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:300),
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:2500),
        ElectricalRouteVertex(xMm:2000,yMm:0,zMm:2500),
      ],
      methods:const [
        ElectricalInstallationMethod.inWall,
        ElectricalInstallationMethod.aboveCeiling,
      ],
      source:ElectricalPathSource.drawing,
    ));
    network.cables.single.route3dId='path';
    network.routeExclusionZones.add(const ElectricalRouteExclusionZone(
      id:'beam',name:'Балка',
      minXMm:1000,maxXMm:1400,
      minYMm:-100,maxYMm:100,
      minZMm:2400,maxZMm:2600,
    ));
    final before=floor.toJson().toString();
    final register=ElectricalIssueRegisterService.inspect(floor);
    final issue=register.entries.singleWhere(
        (e) => e.code=='routeExclusionConflict');
    expect(issue.object,ElectricalIssueObject.route);
    expect(issue.objectId,'path');
    expect(issue.focusPointId,'s1');
    expect(issue.description,contains('Балка'));
    expect(register.hasBlockingIssues,isTrue);
    expect(floor.toJson().toString(),before);
  });

  test('route fault zoom targets the blocked leg, not an arbitrary endpoint', () {
    final floor=sample();
    final network=floor.electricalNetwork!;
    network.routes3d.add(ElectricalRoute3d(
      id:'route',fromPointId:'s1',toPointId:'rk',
      vertices:const [
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:300),
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:2500),
        ElectricalRouteVertex(xMm:2000,yMm:0,zMm:2500),
      ],
      methods:const [
        ElectricalInstallationMethod.inWall,
        ElectricalInstallationMethod.aboveCeiling,
      ],
    ));
    network.cables.single.route3dId='route';
    network.routeExclusionZones.add(const ElectricalRouteExclusionZone(
      id:'beam',name:'Перемычка',minXMm:1100,maxXMm:1450,
      minYMm:-200,maxYMm:200,minZMm:2400,maxZMm:2600,
    ));
    final snapshot=floor.toJson().toString();
    final issue=ElectricalIssueRegisterService.inspect(floor).entries
        .singleWhere((e)=>e.code=='routeExclusionConflict');
    final target=ElectricalIssueLocatorService.locate(floor,issue)!;
    expect(target.pointId,'s1');
    expect(target.diagnosticRouteId,'route');
    expect(target.xMm,1275); // exact intersection, not entire 1500 mm leg
    expect(target.yMm,0);
    expect(floor.toJson().toString(),snapshot);
  });

  test('narrow obstacle far along long cable is located precisely', () {
    const beam = ElectricalRouteExclusionZone(
      id:'beam',name:'Труба', minXMm:9100,maxXMm:9200,
      minYMm:-200,maxYMm:200,minZMm:2400,maxZMm:2600,
    );
    final actual = beam.intersectionMidpoint(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:2500),
      const ElectricalRouteVertex(xMm:10000,yMm:0,zMm:2500),
    );
    expect(actual,isNotNull);
    expect(actual!.xMm,9150);
    expect(actual.yMm,0);
    expect(beam.intersectionMidpoint(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:2000),
      const ElectricalRouteVertex(xMm:10000,yMm:0,zMm:2000),
    ),isNull);
    expect(beam.intersects(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:2500),
      const ElectricalRouteVertex(xMm:10000,yMm:0,zMm:2500),
    ),isTrue);
  });

  test('missing route reference locates the surviving point without drawing', () {
    final floor=sample();
    floor.electricalNetwork!.cables.single.route3dId='missing';
    final register=ElectricalIssueRegisterService.inspect(floor);
    final issue=register.entries.firstWhere(
      (e)=>e.code=='missingRoute3d');
    final target=ElectricalIssueLocatorService.locate(floor,issue)!;
    expect(target.xMm,500);
    expect(target.yMm,0);
    expect(target.diagnosticRouteId,isNull);
  });

  testWidgets('orphaned saved route remains locatable by real route coordinates',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor=sample();
    final network=floor.electricalNetwork!;
    network.routes3d.add(ElectricalRoute3d(
      id:'orphan-path',fromPointId:'s1',toPointId:'rk',
      vertices:const [
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:300),
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:2400),
        ElectricalRouteVertex(xMm:2000,yMm:0,zMm:2400),
      ],
      methods:const [
        ElectricalInstallationMethod.inWall,
        ElectricalInstallationMethod.aboveCeiling,
      ],
    ));
    network.cables.single.route3dId='orphan-path';
    floor.electricalPoints.removeWhere((p) =>
        p.id == 's1' || p.id == 'rk');
    final snapshot=floor.toJson().toString();
    final issue=ElectricalIssueRegisterService.inspect(floor).entries
        .singleWhere((e)=>e.code=='invalidRoute3d');
    expect(issue.focusPointId,isNull);
    expect(issue.canLocate,isFalse); // legacy field only means a point exists
    final location=ElectricalIssueLocatorService.locate(floor,issue);
    expect(location,isNotNull);
    expect(location!.diagnosticRouteId,'orphan-path');
    ElectricalIssueEntry? located;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ElectricalIssueRegisterSheet(
        floor:floor,onLocate:(entry)=>located=entry,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-issue-errors')));
    await tester.pumpAndSettle();
    final rows=ElectricalIssueRegisterService.inspect(floor).entries
        .where((e)=>e.severity==ElectricalIssueSeverity.error).toList();
    final index=rows.indexWhere((e)=>e.code=='invalidRoute3d');
    expect(index,greaterThanOrEqualTo(0));
    final button=find.byKey(ValueKey('electrical-issue-locate-$index'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(located?.code,'invalidRoute3d');
    expect(floor.toJson().toString(),snapshot);
    expect(tester.takeException(),isNull);
  });

  test('deleted objects have no made-up location or ghost warning overlay', () {
    final floor=sample();
    floor.electricalNetwork!.terminals.add(
      ElectricalTerminalRecord(id:'ghost',junctionPointId:'gone'));
    final issue=ElectricalIssueRegisterService.inspect(floor).entries
        .firstWhere((e)=>e.code=='invalidJunction');
    expect(ElectricalIssueLocatorService.locate(floor,issue),isNull);
  });

  testWidgets('fault painter renders selected route as diagnostics only',
      (tester) async {
    final floor=sample();
    final network=floor.electricalNetwork!;
    network.routes3d.add(ElectricalRoute3d(
      id:'invalid-route',fromPointId:'s1',toPointId:'rk',
      vertices:const [
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:300),
        ElectricalRouteVertex(xMm:500,yMm:0,zMm:2400),
        ElectricalRouteVertex(xMm:2000,yMm:0,zMm:2400),
      ],
      methods:const [
        ElectricalInstallationMethod.inWall,
        ElectricalInstallationMethod.aboveCeiling,
      ],
    ));
    network.cables.single.route3dId='invalid-route';
    network.routeExclusionZones.add(const ElectricalRouteExclusionZone(
      id:'block',name:'Стойка',minXMm:900,maxXMm:1600,
      minYMm:-100,maxYMm:100,minZMm:2300,maxZMm:2500));
    final snapshot=floor.toJson().toString();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:Center(child:CustomPaint(
        size:const Size(390,500),
        painter:ElectricalPlanPainter(
          floor:floor,scale:.09,origin:const Offset(5,80),
          show3dRoutes:true,diagnosticRouteId:'invalid-route',
        ),
      )),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    expect(floor.toJson().toString(),snapshot);
  });

  test('unresolvable broken terminal is visible but never navigates randomly', () {
    final floor=sample();
    floor.electricalNetwork!.terminals.add(
      ElectricalTerminalRecord(
        id:'bad',junctionPointId:'missing',
        members:const [],
      ),
    );
    final register=ElectricalIssueRegisterService.inspect(floor);
    final broken=register.entries.firstWhere(
      (e)=>e.code=='invalidJunction');
    expect(broken.focusPointId,isNull);
    expect(broken.canLocate,isFalse);
    expect(register.hasBlockingIssues,isTrue);
  });

  testWidgets('mobile filter and locate callback do not change project',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor=sample();
    floor.nodes.first.yMm=200; // includes a directly located error
    final snapshot=floor.toJson().toString();
    ElectricalIssueEntry? chosen;
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ElectricalIssueRegisterSheet(
        floor:floor,onLocate:(issue)=>chosen=issue,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-issue-counts')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('electrical-issue-errors')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-issue-row-0')),
        findsOneWidget);
    final target=find.byKey(const ValueKey('electrical-issue-locate-0'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(chosen,isNotNull);
    expect(chosen!.severity,ElectricalIssueSeverity.error);
    expect(chosen!.focusPointId,isNotNull);
    expect(floor.toJson().toString(),snapshot);
    expect(tester.takeException(),isNull);
  });
}
