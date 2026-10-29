import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_frame_geometry.dart';
import 'package:zamer_app/services/electrical_wall_elevation_service.dart';
import 'package:zamer_app/widgets/electrical_point_properties.dart';

FloorPlan fixture() {
  final floor = FloorPlan(id: 'level', name: 'План');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return floor;
}

ElectricalPoint frame({
  String id = 'frame-1',
  double u = 650,
  double h = 300,
  bool vertical = false,
  int posts = 3,
  double pitch = 71,
  int side = 1,
}) => ElectricalPoint(
  id: id,
  type: ElectricalPointType.frame,
  xMm: u, yMm: 0,
  heightMm: h,
  wallId: 'w1',
  wallOffsetMm: u,
  wallSide: side,
  frameVertical: vertical,
  modulePitchMm: pitch,
  modules: List.filled(posts, ElectricalModuleType.socket220),
);

void main() {
  test('three-post frame has exact centres on horizontal and vertical axes', () {
    final horizontal = ElectricalFrameGeometry.centres(frame());
    expect(horizontal.map((c) => c.uMm).toList(), [579, 650, 721]);
    expect(horizontal.map((c) => c.zMm).toList(), [300, 300, 300]);
    final vertical = ElectricalFrameGeometry.centres(frame(vertical: true));
    expect(vertical.map((c) => c.uMm).toList(), [650, 650, 650]);
    expect(vertical.map((c) => c.zMm).toList(), [229, 300, 371]);
  });

  test('pitch survives JSON, legacy points keep nominal 71mm', () {
    final original = frame(pitch: 74.5);
    final imported = ElectricalPoint.fromJson(original.toJson());
    expect(imported.modulePitchMm, 74.5);
    final legacy = Map<String, dynamic>.from(original.toJson())
      ..remove('modulePitchMm');
    expect(ElectricalPoint.fromJson(legacy).modulePitchMm, 71);
    final floor = fixture()..electricalPoints.add(imported);
    final copy = FloorPlan.fromJson(floor.toJson());
    expect(copy.electricalPoints.single.modulePitchMm, 74.5);
  });

  test('frame cannot cross wall boundary or ceiling', () {
    final floor = fixture();
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame(u: 70)), contains('выходит за пределы'));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame(h: 30)), contains('выходит за пределы'));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame()), isNull);
  });

  test('frame checks its whole envelope against door, not only centre', () {
    final floor = fixture();
    final wall = floor.wallById('w1')!;
    wall.openings.add(WallOpening(
      id: 'door1', type: OpeningType.door, widthMm: 850,
      heightMm: 2100, offsetFromStartMm: 900,
    ));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame(u: 840)), contains('door1'));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame(u: 840, h: 2400)), isNull);
  });

  test('same-side frame collision blocks, opposite-side mount stays separate', () {
    final floor = fixture();
    floor.electricalPoints.add(ElectricalPoint(
      id: 'existing', type: ElectricalPointType.socket,
      xMm: 750, yMm: 0, wallId: 'w1',
      wallOffsetMm: 750, heightMm: 300,
    ));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame()), contains('existing'));
    expect(ElectricalFrameGeometry.placementIssue(
      floor, frame(side: -1)), isNull);
  });

  test('wall elevation uses the same post spacing as plan data', () {
    final floor = fixture();
    floor.electricalPoints.add(frame(pitch: 74.5));
    final data = ElectricalWallElevationService.build(floor, 'w1');
    expect(data.points, hasLength(1));
    expect(data.points.single.uMm, 650);
    expect(data.points.single.moduleCount, 3);
    expect(data.points.single.modulePitchMm, 74.5);
  });

  testWidgets('two-ring fan exposes an explicit frame tool',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: floor, onChanged: () async {}),
    )));
    await tester.tap(find.byKey(const ValueKey('electrical-fan-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-two-ring-fan')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-add-frame')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('electrical-add-frame')));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints, isEmpty); // Tool choice is not a point.
    expect(tester.takeException(), isNull);
  });

  testWidgets('frame editor validates a configurable manufacturer pitch',
      (tester) async {
    final p = frame(posts: 2);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final updated = await showModalBottomSheet<ElectricalPoint>(
            context: context, isScrollControlled: true,
            builder: (_) => ElectricalPointProperties(
              point: p, circuits: const [],
            ),
          );
          if (updated != null) p.modulePitchMm = updated.modulePitchMm;
        },
        child: const Text('Редактировать'),
      )),
    )));
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Состав рамки'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('point-module-pitch')), '74');
    await tester.tap(find.byKey(const ValueKey('point-save')));
    await tester.pumpAndSettle();
    expect(p.modulePitchMm, 74);
  });
}
