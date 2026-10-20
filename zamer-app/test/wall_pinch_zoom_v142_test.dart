import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

void main() {
  testWidgets('pinch zoom works while drawing without creating a wall',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'План');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanEditorProductionScreen(
          floor: floor,
          planTool: MeasurePlanTool.exterior,
          onChanged: () async {},
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenPlanGeometry: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final finder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(finder);
    expect(viewer.panEnabled, false);
    expect(viewer.scaleEnabled, true);

    final rect = tester.getRect(finder);
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    final controller = viewer.transformationController!;
    final startScale = controller.value.getMaxScaleOnAxis();
    final finger1 = await tester.startGesture(
        rect.center - const Offset(40, 20), pointer: 11);
    final finger2 = await tester.startGesture(
        rect.center + const Offset(40, 20), pointer: 12);
    await tester.pump(const Duration(milliseconds: 50));
    await finger1.moveTo(rect.center - const Offset(90, 20));
    await finger2.moveTo(rect.center + const Offset(90, 20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(startScale));
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
    expect(floor.walls, isEmpty,
        reason: 'pinch must never commit a phantom wall');
  });
}
