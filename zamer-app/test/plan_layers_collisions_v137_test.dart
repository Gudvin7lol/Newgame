import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/plan_collision_service.dart';
import 'package:zamer_app/services/plan_view_layers.dart';

FloorPlan testFloor() {
  final floor = FloorPlan(id: 'f', name: 'Тестовый этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 5000, yMm: 0),
    PlanNode(id: 'c', xMm: 2500, yMm: -1200),
    PlanNode(id: 'd', xMm: 2500, yMm: 1200),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b',
        thicknessMm: 200, openings: [
          WallOpening(id: 'door', type: OpeningType.door, widthMm: 900,
              heightMm: 2100, offsetFromStartMm: 2100),
        ]),
    PlanWall(id: 'cross', startNodeId: 'c', endNodeId: 'd',
        thicknessMm: 150),
  ]);
  floor.planObjects.addAll([
    PlanObject(id: 'sofa', type: PlanObjectType.furniture,
        xMm: 2300, yMm: 180, widthMm: 1000, depthMm: 700),
    PlanObject(id: 'chair', type: PlanObjectType.furniture,
        xMm: 2750, yMm: 240, widthMm: 700, depthMm: 600),
    PlanObject(id: 'sink', type: PlanObjectType.sanitary,
        xMm: 4200, yMm: 1400, widthMm: 600, depthMm: 450),
    PlanObject(id: 'light', type: PlanObjectType.lighting,
        xMm: 3400, yMm: 2300),
  ]);
  floor.electricalPoints.add(ElectricalPoint(
    id: 'socket', type: ElectricalPointType.socket,
    xMm: 2500, yMm: 0,
  ));
  floor.serviceRuns.add(ServiceRun(
    id: 'cold', type: ServiceRunType.coldWater,
    points: [ServiceVertex(0, 2000), ServiceVertex(2500, 2000)],
  ));
  return floor;
}

void main() {
  test('visibility settings persist in floor JSON and in restoreFrom', () {
    final floor = testFloor();
    final settings = PlanViewLayers();
    settings.content.remove(PlanContentLayer.furniture);
    settings.content.remove(PlanContentLayer.dimensions);
    settings.clashTypes.remove(PlanClashCategory.objectObject);
    settings.stages.remove(ProjectLayer.demolition);
    settings.showClashes = true;
    floor.layerVisibility.addAll(settings.toMap());

    final reloaded = FloorPlan.fromJson(floor.toJson());
    final saved = PlanViewLayers.fromMap(reloaded.layerVisibility);
    expect(saved.showClashes, isTrue);
    expect(saved.content.contains(PlanContentLayer.furniture), isFalse);
    expect(saved.content.contains(PlanContentLayer.dimensions), isFalse);
    expect(saved.clashTypes.contains(PlanClashCategory.objectObject), isFalse);
    expect(saved.stages.contains(ProjectLayer.demolition), isFalse);

    final another = FloorPlan(id: 'copy', name: 'Copy');
    another.restoreFrom(reloaded);
    expect(another.layerVisibility, reloaded.layerVisibility);
    expect(FloorPlan.fromJson(testFloor().toJson()).layerVisibility, isEmpty);
  });

  test('separate type filters hide furniture without hiding plumbing', () {
    final floor = testFloor();
    final prefs = PlanViewLayers();
    final furniture = floor.planObjects.firstWhere((o) => o.id == 'sofa');
    final sink = floor.planObjects.firstWhere((o) => o.id == 'sink');
    final light = floor.planObjects.firstWhere((o) => o.id == 'light');

    expect(prefs.visibleObject(furniture), isTrue);
    expect(prefs.visibleObject(sink), isTrue);
    prefs.content.remove(PlanContentLayer.furniture);
    expect(prefs.visibleObject(furniture), isFalse);
    expect(prefs.visibleObject(sink), isTrue);
    prefs.content.remove(PlanContentLayer.electrical);
    expect(prefs.visibleObject(light), isFalse);
  });

  test('collisions are classified by actual services, not descriptions', () {
    final floor = testFloor();
    final issues = PlanCollisionService.inspect(floor);
    final types = issues.map((i) => i.category).toSet();
    expect(types, contains(PlanClashCategory.wallIntersection));
    expect(types, contains(PlanClashCategory.objectWall));
    expect(types, contains(PlanClashCategory.objectObject));
    expect(types, contains(PlanClashCategory.doorPassage));
    expect(issues.every((i) => i.position.x.isFinite
        && i.position.y.isFinite), isTrue);
  });

  test('collision marker toggle and category visibility are independent', () {
    final floor = testFloor();
    final issues = PlanCollisionService.inspect(floor);
    final prefs = PlanViewLayers();
    expect(PlanCollisionService.visible(issues, prefs, floor), isEmpty);

    prefs.showClashes = true;
    prefs.clashTypes
      ..clear()
      ..add(PlanClashCategory.wallIntersection);
    final geometry = PlanCollisionService.visible(issues, prefs, floor);
    expect(geometry, isNotEmpty);
    expect(geometry.every((i) =>
        i.category == PlanClashCategory.wallIntersection), isTrue);

    prefs.content.remove(PlanContentLayer.walls);
    expect(PlanCollisionService.visible(issues, prefs, floor), isEmpty);
    prefs.content.add(PlanContentLayer.walls);

    prefs.clashTypes
      ..clear()
      ..add(PlanClashCategory.objectObject);
    prefs.content.remove(PlanContentLayer.furniture);
    expect(PlanCollisionService.visible(issues, prefs, floor), isEmpty);
    prefs.content.add(PlanContentLayer.furniture);
    expect(PlanCollisionService.visible(issues, prefs, floor), isNotEmpty);
  });

  test('view layers never mutate floor objects or their locations', () {
    final floor = testFloor();
    final raw = floor.toJson().toString();
    final items = PlanCollisionService.inspect(floor);
    final prefs = PlanViewLayers(showClashes: true);
    prefs.content.clear();
    prefs.clashTypes.clear();
    prefs.stages.clear();
    PlanCollisionService.visible(items, prefs, floor);
    expect(floor.toJson().toString(), raw);
    expect(items.first.position, isA<math.Point<double>>());
  });
}
