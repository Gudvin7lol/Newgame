import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';
import 'package:zamer_app/screens/recovered_measure_workspace_screen.dart';
import 'package:zamer_app/services/wall_drawing_service.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';

void main() {
  test('wall endpoint capture stays stable through finger jitter', () {
    final floor = FloorPlan(
      id: 'f', name: 'Flat',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 0, yMm: 2000),
      ],
      walls: [PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b')],
    );
    final captured = WallDrawingService.snap(
      floor, startNodeId: 'c',
      raw: const math.Point<double>(3050, 0),
      angleStepDegrees: 0,
      nodeCaptureMm: 80,
      wallCaptureMm: 20,
    );
    expect(captured.targetNodeId, 'b');
    final held = WallDrawingService.snap(
      floor, startNodeId: 'c',
      raw: const math.Point<double>(3090, 0),
      angleStepDegrees: 0,
      nodeCaptureMm: 80,
      wallCaptureMm: 20,
      previousSnap: captured,
    );
    expect(held.targetNodeId, 'b');
    expect(held.point, const math.Point<double>(3000, 0));
  });

  testWidgets('collapsed dial takes only quick controls, then releases blank taps',
      (tester) async {
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var backgroundTaps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Stack(children: [
        Positioned.fill(child: GestureDetector(
          key: const ValueKey('draw-canvas'),
          behavior: HitTestBehavior.opaque,
          onTap: () => backgroundTaps++,
          child: const ColoredBox(color: Colors.black),
        )),
        Positioned(right: 0, bottom: 0,
          child: ZamerKitFan(
            contextId: 'plan.idle',
            first: const ZamerKitCommand('nodes','Узлы',Icons.hub_outlined),
            second: const ZamerKitCommand('arc','Дуга',Icons.architecture),
            outer: const [
              ZamerKitCommand('measure', 'Измерить', Icons.straighten_outlined),
            ],
            onCommand: (_) {},
          )),
      ]),
    )));
    await tester.pump();
    // The hit areas are compact; the layout coordinate system remains
    // fixed so the central control never jumps when expanding.
    final folded = tester.getSize(find.byType(ZamerKitFan));
    expect(folded, const Size(244, 244));
    final foldedCenter = tester.getCenter(
        find.byKey(const ValueKey('fan-expand')));
    await tester.tap(find.byKey(const ValueKey('fan-expand')));
    await tester.pumpAndSettle();
    final full = tester.getSize(find.byType(ZamerKitFan));
    expect(full.width, 244);
    final expandedCenter = tester.getTopLeft(find.byType(ZamerKitFan))
        + const Offset(188, 188);
    expect((expandedCenter - foldedCenter).distance, lessThan(1.5));
    final top = tester.getTopLeft(find.byType(ZamerKitFan));
    await tester.tapAt(top + const Offset(18, 18));
    await tester.pump();
    expect(backgroundTaps, 1,
      reason: 'Transparent fan corners may never steal CAD touches');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one tap on Walls starts real drawing mode, no duplicate picker',
      (tester) async {
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor]);
    await tester.pumpWidget(MaterialApp(
      home: RecoveredMeasureWorkspaceScreen(
        project: project, floor: floor, onChanged: () async {},
        onUndo: null, onRedo: null, canUndo: false, canRedo: false,
        onMore: () {}, onOpen3D: () {}, onOpenPhoto: () {},
        onOpenReview: () {}, onOpenGeometry: () {},
        onOpenFloors: () {}, onHome: () {}, onProfile: () {},
        onPrimaryMode: (_) {},
      ),
    ));
    await tester.pump();
    expect(tester.widget<PlanEditorProductionScreen>(
      find.byType(PlanEditorProductionScreen)).planTool,
      MeasurePlanTool.select);
    await tester.tap(find.byKey(const ValueKey('kit-v2-task-0')));
    await tester.pump();
    expect(tester.widget<PlanEditorProductionScreen>(
      find.byType(PlanEditorProductionScreen)).planTool,
      MeasurePlanTool.exterior);
    expect(tester.takeException(), isNull);
  });
}
