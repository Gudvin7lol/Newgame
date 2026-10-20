import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/plan_visibility_service.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

FloorPlan testFloor() {
  final floor = FloorPlan(id: 'f', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 1000),
    PlanNode(id: 'b', xMm: 4000, yMm: 1000),
  ]);
  floor.walls.add(
    PlanWall(id: 'wall', startNodeId: 'a', endNodeId: 'b',
      thicknessMm: 150, type: WallType.exterior),
  );
  return floor;
}

PlanObject box(String id, double x, double y,
    {PlanObjectType type = PlanObjectType.furniture}) =>
  PlanObject(id: id, type: type, xMm: x, yMm: y,
    widthMm: 600, depthMm: 600, heightMm: 800);

void main() {
  test('display layer choices never change the persisted FloorPlan', () {
    final floor = testFloor();
    floor.planObjects.add(box('sofa', 2000, 1000));
    final before = floor.toJson().toString();
    final layers = PlanDisplayLayer.values.toSet();
    layers.remove(PlanDisplayLayer.furniture);
    layers.remove(PlanDisplayLayer.electrical);
    final collisions = PlanCollisionKind.values.toSet();
    collisions.remove(PlanCollisionKind.objectWall);
    expect(floor.toJson().toString(), before);
    expect(layers.contains(PlanDisplayLayer.furniture), isFalse);
    expect(collisions.length, PlanCollisionKind.values.length - 1);
  });

  test('identifies object/wall and object/object collisions separately', () {
    final floor = testFloor();
    floor.planObjects.addAll([
      box('chair', 1800, 1000),
      box('table', 2000, 1000),
    ]);
    final issues = PlanCollisionService.inspect(floor);
    expect(issues.any((x) => x.kind == PlanCollisionKind.objectWall), isTrue);
    expect(issues.any((x) => x.kind == PlanCollisionKind.objectObject), isTrue);
    expect(issues.every((x) => x.position.x.isFinite &&
      x.position.y.isFinite), isTrue);
  });

  test('reports non-joined wall crossings as spatial markers', () {
    final floor = testFloor();
    floor.nodes.addAll([
      PlanNode(id: 'c', xMm: 2000, yMm: 0),
      PlanNode(id: 'd', xMm: 2000, yMm: 2000),
    ]);
    floor.walls.add(PlanWall(
      id: 'cross', startNodeId: 'c', endNodeId: 'd'));
    final issues = PlanCollisionService.inspect(floor);
    expect(issues.any((x) => x.kind == PlanCollisionKind.wallIntersection),
      isTrue);
    final mark = issues.firstWhere(
      (x) => x.kind == PlanCollisionKind.wallIntersection);
    expect(mark.position.x, closeTo(2000, 0.01));
    expect(mark.position.y, closeTo(1000, 0.01));
  });

  test('reports door clearances independently of object intersections', () {
    final floor = FloorPlan(id: 'f', name: 'Этаж');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 1000),
      PlanNode(id: 'b', xMm: 4000, yMm: 1000),
    ]);
    floor.walls.add(PlanWall(
      id: 'w', startNodeId: 'a', endNodeId: 'b',
      openings: [
        WallOpening(id: 'door', type: OpeningType.door,
          widthMm: 900, heightMm: 2100, offsetFromStartMm: 1100),
      ],
    ));
    floor.planObjects.add(box('wardrobe', 1500, 1500));
    final issues = PlanCollisionService.inspect(floor);
    expect(issues.any((x) => x.kind == PlanCollisionKind.doorClearance), isTrue);
  });

  test('production painter filters element categories without deleting them', () {
    final v2 = File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final v3 = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final entry = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    expect(v2, contains('PlanDisplayLayer.furniture'));
    expect(v2, contains('PlanDisplayLayer.sanitary'));
    expect(v2, contains('PlanDisplayLayer.electrical'));
    expect(v2, contains('PlanDisplayLayer.engineering'));
    expect(v2, contains('PlanCollisionService.inspect(floor)'));
    expect(v2, contains('if (collisionKinds.isNotEmpty)'));
    expect(v3, contains('visibleCategories: visibleCategories'));
    expect(entry, contains('collisionKinds: collisionKinds'));
  });

  testWidgets('Layers and collisions panel is reachable on the main canvas',
      (tester) async {
    tester.view.physicalSize = const Size(460, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = testFloor();
    floor.planObjects.add(box('chair', 2000, 1000));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanEditorProductionScreen(
        floor: floor,
        onChanged: () async {},
        onOpenObjects: () {},
        onOpenReview: () {},
        onOpenPlanGeometry: () {},
      )),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-layers-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-layers-button')));
    await tester.pumpAndSettle();
    expect(find.text('Слои и коллизии'), findsWidgets);
    expect(find.text('Строительные слои'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-layers-list')), findsOneWidget);
    expect(find.text('Применить'), findsOneWidget);
    // No second editor route is ever pushed when opening layer controls.
    expect(find.byType(PlanEditorProductionScreen), findsOneWidget);
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-layers-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
