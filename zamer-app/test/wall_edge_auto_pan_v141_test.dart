import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

void main() {
  testWidgets('drag to screen edge pans drawing camera and commits wall',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Door test');
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

    final viewport = find.byType(InteractiveViewer);
    final rect = tester.getRect(viewport);
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(viewport);
    final transform = viewer.transformationController!;
    final before = transform.value.storage[12];
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(Offset(rect.right - 12, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 300));
    expect(transform.value.storage[12], lessThan(before),
      reason: 'autopan follows a long wall only near the viewport edge');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(floor.walls, isNotEmpty,
      reason: 'releasing the drag completes a wall without a camera jump');
    expect(tester.takeException(), isNull);
  });
}
