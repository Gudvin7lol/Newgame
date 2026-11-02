import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/electrical_route_3d.dart';
import 'package:zamer_app/models/electrical_route_exclusion_zone.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_auto_route_proposal_service.dart';
import 'package:zamer_app/services/electrical_route_exclusion_service.dart';
import 'package:zamer_app/services/electrical_route_service.dart';

FloorPlan floorFixture() {
  final floor = FloorPlan(id: 'f', name: 'Тест');
  floor.nodes.addAll([
    PlanNode(id:'a',xMm:0,yMm:0),PlanNode(id:'b',xMm:4000,yMm:0),
    PlanNode(id:'c',xMm:4000,yMm:3000),PlanNode(id:'d',xMm:0,yMm:3000),
  ]);
  floor.walls.addAll([
    PlanWall(id:'top',startNodeId:'a',endNodeId:'b'),
    PlanWall(id:'right',startNodeId:'b',endNodeId:'c'),
    PlanWall(id:'bottom',startNodeId:'c',endNodeId:'d'),
    PlanWall(id:'left',startNodeId:'d',endNodeId:'a'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(id:'s',type:ElectricalPointType.socket,
      xMm:500,yMm:0,wallId:'top',wallOffsetMm:500,
      wallSide:1,heightMm:300),
    ElectricalPoint(id:'t',type:ElectricalPointType.socket,
      xMm:3500,yMm:0,wallId:'top',wallOffsetMm:3500,
      wallSide:1,heightMm:300),
  ]);
  floor.electricalNetwork = ElectricalNetwork(cables:[
    ElectricalCableRecord(id:'c',circuitId:'C1',fromPointId:'s',toPointId:'t'),
  ]);
  return floor;
}

ElectricalRouteExclusionZone zone({String id='block', double bottom=2400,
  double top=2600}) => ElectricalRouteExclusionZone(
    id:id,name:'Балка',minXMm:1400,maxXMm:1900,
    minYMm:-100,maxYMm:100,minZMm:bottom,maxZMm:top,
);

ElectricalRoute3d manual({String id='manual'}) => ElectricalRoute3d(
  id:id,fromPointId:'s',toPointId:'t',
  vertices: const [
    ElectricalRouteVertex(xMm:500,yMm:0,zMm:300),
    ElectricalRouteVertex(xMm:500,yMm:0,zMm:2550),
    ElectricalRouteVertex(xMm:3500,yMm:0,zMm:2550),
    ElectricalRouteVertex(xMm:3500,yMm:0,zMm:300),
  ],
  methods: [
    ElectricalInstallationMethod.inWall,
    ElectricalInstallationMethod.aboveCeiling,
    ElectricalInstallationMethod.inWall,
  ],
  lockedLegs: {1},
  source: ElectricalPathSource.drawing,
);

void main() {
  test('saved exclusion prism is backward compatible and survives project JSON', () {
    final floor=floorFixture();
    ElectricalRouteExclusionService.add(floor,zone());
    final restored=FloorPlan.fromJson(floor.toJson());
    expect(restored.electricalNetwork!.routeExclusionZones.single.name, 'Балка');
    final old=ElectricalNetwork.fromJson({
      'version':1, 'circuits':[], 'cables':[], 'terminals':[], 'routes3d':[],
    });
    expect(old.routeExclusionZones,isEmpty);
    expect(old.toJson().containsKey('routeExclusionZones'),isFalse);
    final underfloor=zone(bottom:-350,top:-50);
    underfloor.validate();
    expect(underfloor.intersects(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:-100),
      const ElectricalRouteVertex(xMm:4000,yMm:0,zMm:-100)),isTrue);
    final roundTrip = ElectricalRouteExclusionZone.fromJson(zone().toJson());
    expect(roundTrip.intersects(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:2550),
      const ElectricalRouteVertex(xMm:4000,yMm:0,zMm:2550)),isTrue);
    expect(roundTrip.intersects(
      const ElectricalRouteVertex(xMm:0,yMm:0,zMm:2300),
      const ElectricalRouteVertex(xMm:4000,yMm:0,zMm:2300)),isFalse);
    expect(() => ElectricalRouteExclusionZone.fromJson({
      ...zone().toJson(),'minZMm':double.nan,
    }),throwsFormatException);
  });

  test('blocked same-wall candidate never mutates network or cable', () {
    final floor=floorFixture();
    ElectricalRouteExclusionService.add(floor,zone());
    final before=floor.toJson().toString();
    final cable=floor.electricalNetwork!.cables.single;
    expect(() => ElectricalAutoRouteProposalService.prepare(floor,cable),
      throwsFormatException);
    expect(floor.toJson().toString(),before);
    expect(cable.route3dId,isNull);
  });

  test('no-go prism above route height does not block geometry', () {
    final floor=floorFixture();
    ElectricalRouteExclusionService.add(floor,zone(bottom:2650,top:2690));
    final cable=floor.electricalNetwork!.cables.single;
    final proposal=ElectricalAutoRouteProposalService.prepare(floor,cable);
    expect(proposal.measurement.geometricMm,7500);
  });

  test('graph chooses longer corridor avoiding excluded high zone', () {
    final floor=floorFixture();
    final point=floor.electricalPoints.last
      ..wallId='right'..xMm=4000..yMm=1000..wallOffsetMm=1000;
    ElectricalRouteExclusionService.add(floor,zone());
    final result=ElectricalAutoRouteProposalService.prepare(
      floor,floor.electricalNetwork!.cables.single);
    expect(result.measurement.geometricMm,greaterThan(9000));
    expect(result.route.vertices.any((v)=>v.xMm==0&&v.yMm==3000),
      isTrue);
    expect(point.wallId,'right');
  });

  test('fixed manual leg survives JSON and forbids mutation/replacement/deletion', () {
    final floor=floorFixture();
    final network=floor.electricalNetwork!;
    final cable=network.cables.single;
    final original=manual();
    ElectricalRouteService.upsertForCable(floor,network,cable.id,original);
    final saved=FloorPlan.fromJson(floor.toJson());
    expect(saved.electricalNetwork!.routes3d.single.lockedLegs,{1});
    expect(ElectricalRoute3d(
      id:'untouched',fromPointId:'s',toPointId:'t',
      vertices:manual().vertices,methods:manual().methods,
    ).toJson().containsKey('lockedLegs'),isFalse);
    expect(saved.electricalNetwork!.cables.single.route3dId,'manual');

    final edited=ElectricalRoute3d.fromJson(original.toJson());
    edited.methods[1]=ElectricalInstallationMethod.inFloor;
    expect(() => ElectricalRouteService.upsertForCable(
        floor,network,cable.id,edited),throwsFormatException);
    expect(() => ElectricalRouteService.upsertForCable(
        floor,network,cable.id,manual(id:'new-id')),throwsFormatException);
    expect(() => ElectricalRouteService.clearCableRoute(
        network,cable.id),throwsFormatException);
    expect(network.routes3d.single.methods[1],
        ElectricalInstallationMethod.aboveCeiling);
    expect(cable.route3dId,'manual');
  });

  test('new cable path overlapping forbidden volume cannot be saved', () {
    final floor=floorFixture();
    ElectricalRouteExclusionService.add(floor,zone());
    final network=floor.electricalNetwork!;
    expect(() => ElectricalRouteService.upsertForCable(
        floor,network,'c',manual()),throwsFormatException);
    expect(network.routes3d,isEmpty);
    expect(network.cables.single.route3dId,isNull);
  });

  test('malformed protected indices are rejected early', () {
    final floor=floorFixture();
    final candidate=manual()..lockedLegs.add(9);
    expect(() => ElectricalRouteService.measure(floor,candidate),
        throwsFormatException);
  });
}
