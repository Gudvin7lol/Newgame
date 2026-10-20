import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/wall_drawing_service.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';
import 'package:zamer_app/widgets/wall_draft_guide_painter.dart';

FloorPlan hostWithPartitionStart() {
  final floor = FloorPlan(id: 'f', name: 'Комната');
  floor.nodes.addAll([
    PlanNode(id: 'left', xMm: 0, yMm: 0),
    PlanNode(id: 'right', xMm: 4000, yMm: 0),
    PlanNode(id: 'partition-start', xMm: 2000, yMm: 1000),
  ]);
  floor.walls.add(PlanWall(
    id: 'host', startNodeId: 'left', endNodeId: 'right',
    type: WallType.exterior, thicknessMm: 300,
  ));
  return floor;
}

Widget editor(FloorPlan floor) => MaterialApp(
  home: Scaffold(
    body: PlanEditorProductionScreen(
      floor: floor,
      planTool: MeasurePlanTool.partition,
      onChanged: () async {},
      onOpenObjects: () {},
      onOpenReview: () {},
      onOpenPlanGeometry: () {},
    ),
  ),
);

void main() {
  test('300-mm host face snaps to true host axis, not floating partition', () {
    final floor = hostWithPartitionStart();
    final snap = WallDrawingService.snap(
      floor, startNodeId: 'partition-start',
      raw: const math.Point<double>(2000, 150),
      angleStepDegrees: 90,
      nodeCaptureMm: 80,
      wallCaptureMm: 55,
      allowWallFaces: true,
    );
    expect(snap.targetWallId, 'host');
    expect(snap.kind, NodeSnapKind.wall);
    expect(snap.label, contains('Грань'));
    expect(snap.facePoint!.y, closeTo(150, .001));
    expect(snap.point.x, closeTo(2000, .001));
    expect(snap.point.y, closeTo(0, .001));

    final end = GeometryService.addWallFromNode(
      floor, startNodeId: 'partition-start',
      endPoint: snap.point, type: WallType.partition,
      thicknessMm: 100, material: WallMaterial.drywall,
      endpointCaptureMm: .5, endpointRoundingMm: 0,
    );
    expect(floor.nodeDegree(end.id), 3);
    expect(floor.wallById('host'), isNull,
        reason: 'A real T joint splits its host into two linked walls');
    expect(floor.walls.length, 3);
  });

  test('switching to centreline-only prevents face attraction', () {
    final floor = hostWithPartitionStart();
    final snap = WallDrawingService.snap(
      floor, startNodeId: 'partition-start',
      raw: const math.Point<double>(2000, 150),
      angleStepDegrees: 90,
      nodeCaptureMm: 50,
      wallCaptureMm: 55,
      allowWallFaces: false,
    );
    expect(snap.targetWallId, isNull);
    expect(snap.facePoint, isNull);
    expect(snap.point.y, closeTo(150, .001));
  });

  test('a stray node 20-mm off the host cannot be reused for T join', () {
    final floor = hostWithPartitionStart();
    floor.nodes.add(PlanNode(
      id: 'wrong-nearby', xMm: 2018, yMm: 12,
    ));
    final p = WallDrawingService.snap(
      floor, startNodeId: 'partition-start',
      raw: const math.Point<double>(2003, 30),
      angleStepDegrees: 90, nodeCaptureMm: 80, wallCaptureMm: 80,
    );
    expect(p.point.x, closeTo(2000, .001));
    expect(p.point.y, closeTo(0, .001));
    final node = GeometryService.addWallFromNode(
      floor, startNodeId: 'partition-start',
      endPoint: p.point, type: WallType.partition,
      thicknessMm: 100, material: WallMaterial.drywall,
      endpointCaptureMm: .5, endpointRoundingMm: 0,
    );
    expect(node.id, isNot('wrong-nearby'));
    expect(node.xMm, closeTo(2000, .001));
    expect(node.yMm, closeTo(0, .001));
    expect(floor.nodeDegree(node.id), 3);
    expect(floor.nodeById('wrong-nearby')!.xMm, 2018);
  });

  test('pre-existing on-axis interior node splits host instead of skipping', () {
    final floor = hostWithPartitionStart();
    floor.nodes.add(PlanNode(id: 'joint', xMm: 2000, yMm: 0));
    final node = GeometryService.addWallFromNode(
      floor, startNodeId: 'partition-start',
      endPoint: const math.Point<double>(2000, 0),
      type: WallType.partition, thicknessMm: 100,
      material: WallMaterial.drywall,
      endpointCaptureMm: .5, endpointRoundingMm: 0,
    );
    expect(node.id, 'joint');
    expect(floor.nodeDegree(node.id), 3);
    expect(floor.walls.length, 3);
  });

  test('fractional intersections stay exact, not rounded to 5 mm', () {
    final floor = hostWithPartitionStart();
    final originalStart = floor.nodeById('partition-start')!;
    originalStart.xMm = 2000.3;
    final node = GeometryService.addWallFromNode(
      floor, startNodeId: 'partition-start',
      endPoint: const math.Point<double>(2000.3, 0),
      type: WallType.partition, thicknessMm: 100,
      material: WallMaterial.drywall,
      endpointCaptureMm: .5, endpointRoundingMm: 0,
    );
    expect(node.xMm, closeTo(2000.3, .00001));
    expect(node.yMm, 0);
    expect(floor.nodeDegree(node.id), 3);
  });

  test('host wall sockets stay linked after splitting into two segments', () {
    final floor = hostWithPartitionStart();
    final socket = ElectricalPoint(
      id: 'socket', type: ElectricalPointType.socket,
      xMm: 3200, yMm: 0,
      wallId: 'host', wallOffsetMm: 3200,
    );
    floor.electricalPoints.add(socket);
    final end = GeometryService.addWallFromNode(
      floor,
      startNodeId: 'partition-start',
      endPoint: const math.Point<double>(2000, 0),
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
      endpointCaptureMm: .5,
    );
    expect(floor.nodeDegree(end.id), 3);
    final linked = floor.wallById(socket.wallId!);
    expect(linked, isNotNull, reason: 'A socket must not reference the old host ID');
    expect(linked!.thicknessMm, 300);
    expect(linked.startNodeId, end.id);
    expect(socket.wallOffsetMm, closeTo(1200, .001));
    expect(socket.xMm, 3200);
    expect(socket.yMm, 0);
  });

  test('splitting through an opening is rejected before mutating host', () {
    final floor = hostWithPartitionStart();
    floor.wallById('host')!.openings.add(WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 900, heightMm: 2100,
      offsetFromStartMm: 1600,
    ));
    final before = floor.toJson().toString();
    expect(
      () => GeometryService.addWallFromNode(
        floor,
        startNodeId: 'partition-start',
        endPoint: const math.Point<double>(2000, 0),
        type: WallType.partition,
        thicknessMm: 100,
        material: WallMaterial.drywall,
        endpointCaptureMm: .5,
      ),
      throwsA(isA<StateError>()),
    );
    expect(floor.toJson().toString(), before);
  });

  test('replaced host segments are not reported as newly drawn walls', () {
    final floor = hostWithPartitionStart();
    final newWalls = <PlanWall>[];
    GeometryService.addWallFromNode(
      floor, startNodeId: 'partition-start',
      endPoint: const math.Point<double>(2000, 0),
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
      endpointCaptureMm: .5,
      newlyDrawnWalls: newWalls,
    );
    expect(newWalls.length, 1);
    newWalls.single.projectLayer = ProjectLayer.proposed;
    expect(floor.walls.where(
      (wall) => wall.projectLayer == ProjectLayer.proposed,
    ).length, 1);
    expect(floor.walls.where(
      (wall) => wall.projectLayer == ProjectLayer.existing,
    ).length, 2);
    expect(floor.walls.where(
      (wall) => wall.thicknessMm == 300,
    ).length, 2);
  });

  test('preview painter is a noninteractive overlay and labels hit kind', () {
    final painter = WallDraftGuidePainter(
      from: const Offset(100, 100),
      to: const Offset(300, 100),
      mmToPx: .1,
      zoom: 1,
      wallThicknessMm: 300,
      snapKind: NodeSnapKind.wall,
      snapLabel: 'Грань → общая ось',
      facePoint: const Offset(300, 115),
    );
    expect(painter.shouldRepaint(painter), isFalse);
    expect(painter.shouldRepaint(WallDraftGuidePainter(
      from: const Offset(100, 100),
      to: const Offset(320, 100),
      mmToPx: .1,
      zoom: 1,
      wallThicknessMm: 300,
      snapKind: NodeSnapKind.wall,
      snapLabel: 'Грань → общая ось',
      facePoint: const Offset(300, 115),
    )), isTrue);
  });

  testWidgets('touching second wall point reveals the draft on original canvas',
    (tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = hostWithPartitionStart();
    await tester.pumpWidget(editor(floor));
    await tester.pumpAndSettle();

    final view = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = view.transformationController!;
    Offset toGlobal(Offset p) =>
      tester.getTopLeft(find.byType(InteractiveViewer)) +
        MatrixUtils.transformPoint(transform.value, p);

    final source = const Offset(16200, 16100); // 2000, 1000 mm
    await tester.tapAt(toGlobal(source));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wall-build-exact-length')), findsOneWidget);

    final target = toGlobal(const Offset(16200, 15980));
    final finger = await tester.startGesture(target);
    await finger.moveBy(const Offset(10, 0));
    await tester.pump();
    final painter = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('measure-shared-canvas')),
    );
    expect(painter.foregroundPainter, isA<WallDraftGuidePainter>());
    final guide = painter.foregroundPainter! as WallDraftGuidePainter;
    expect(guide.snapLabel, isNotEmpty);
    expect(guide.mmToPx, .1);
    expect(find.byType(PlanEditorProductionScreen), findsOneWidget);
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
