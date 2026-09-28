import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/engineering_service.dart';
import 'package:zamer_app/services/estimate_service.dart';
import 'package:zamer_app/services/geometry_service.dart';

FloorPlan sample() {
  final floor = FloorPlan(id: 'f', name: 'F');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3000, yMm: 0),
    PlanNode(id: 'c', xMm: 3000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
  ]);
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  test(
    'ceiling zones are clipped to room and warm floor has bounded circuits',
    () {
      final floor = sample();
      final face = GeometryService.roomFaces(floor).single;
      final zone = CeilingZone(
        id: 'z',
        xMm: 2750,
        yMm: 1500,
        widthMm: 1000,
        depthMm: 1000,
      );
      expect(EngineeringService.zoneAreaM2(face, zone), closeTo(.70, .02));
      final spec = HeatingSpec(
        enabled: true,
        coveragePct: 100,
        excludedAreaM2: 1,
        spacingMm: 150,
        maxCircuitLengthM: 30,
      );
      final takeoff = EngineeringService.warmFloor(face, spec);
      expect(takeoff.areaM2, closeTo(7.41, .01));
      expect(takeoff.pipeM, closeTo(54.34, .1));
      expect(takeoff.circuits, 2);
    },
  );

  test(
    'engineering routes and project prices survive snapshot and estimate',
    () {
      final floor = sample();
      final meta = floor.roomMetas.first;
      meta.ceiling = CeilingSpec(
        finish: 'stretch',
        dropMm: 100,
        zones: [CeilingZone(id: 'z', xMm: 1500, yMm: 1500)],
      );
      meta.heating = HeatingSpec(enabled: true, coveragePct: 100);
      floor.serviceRuns.add(
        ServiceRun(
          id: 'r',
          type: ServiceRunType.drain,
          diameterMm: 50,
          slopePct: 2,
          points: [ServiceVertex(0, 0), ServiceVertex(3000, 4000)],
        ),
      );
      expect(floor.serviceRuns.single.lengthM, 5);
      expect(floor.serviceRuns.single.fallMm, 100);
      final project = MeasureProject(
        id: 'p',
        name: 'P',
        floors: [floor],
        unitPrices: {'Труба: Канализация|м': 150},
      );
      final restored = MeasureProject.fromJson(project.toJson());
      expect(restored.floors.single.roomMetas.first.ceiling.finish, 'stretch');
      expect(restored.floors.single.roomMetas.first.heating.enabled, true);
      expect(restored.floors.single.serviceRuns.single.lengthM, 5);
      final estimate = EstimateService.build(restored);
      final drain = estimate.lines.singleWhere(
        (e) => e.name == 'Труба: Канализация',
      );
      expect(drain.quantity, closeTo(5.5, .001));
      expect(drain.total, 825);
      expect(estimate.lines.any((e) => e.name == 'Натяжной потолок'), true);
      expect(estimate.lines.any((e) => e.name == 'Труба тёплого пола'), true);
      expect(estimate.unpricedCount, greaterThan(0));
    },
  );

  test('old ceiling object moves into dedicated room zones', () {
    final floor = sample();
    floor.planObjects.add(
      PlanObject(
        id: 'legacy',
        type: PlanObjectType.ceilingZone,
        xMm: 1500,
        yMm: 1500,
        widthMm: 1000,
        depthMm: 700,
        elevationMm: 2580,
      ),
    );
    expect(EngineeringService.migrateLegacyCeilingZones(floor), 1);
    expect(floor.planObjects, isEmpty);
    final zone = floor.roomMetas.first.ceiling.zones.single;
    expect(zone.id, 'legacy');
    expect(zone.extraDropMm, 120);
  });

  test('pipe endpoint snaps to fixture or wall node within reach', () {
    final floor = sample();
    floor.planObjects.add(
      PlanObject(
        id: 'fixture',
        type: PlanObjectType.drainPoint,
        xMm: 1400,
        yMm: 1300,
      ),
    );
    expect(
      EngineeringService.snapRoutePoint(floor, const math.Point(1350, 1320)),
      const math.Point<double>(1400, 1300),
    );
    expect(
      EngineeringService.snapRoutePoint(floor, const math.Point(20, 30)),
      const math.Point<double>(0, 0),
    );
    expect(
      EngineeringService.snapRoutePoint(floor, const math.Point(900, 900)),
      isNull,
    );
  });

  test('orthogonal pipe step preserves target with a square bend', () {
    final steps = EngineeringService.orthogonalStep(
      ServiceVertex(100, 200),
      const math.Point<double>(900, 600),
    );
    expect(steps.map((p) => (p.xMm, p.yMm)).toList(),
        [(900.0, 200.0), (900.0, 600.0)]);
    expect(EngineeringService.orthogonalStep(
        ServiceVertex(100, 200), const math.Point<double>(100, 600)).length, 1);
  });
}
