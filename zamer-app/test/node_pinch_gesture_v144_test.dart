import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

void main() {
  testWidgets('two-finger pinch in nodes mode cannot drag structural nodes',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Floor', nodes: [
      PlanNode(id: 'start', xMm: 0, yMm: 0),
      PlanNode(id: 'end', xMm: 3000, yMm: 0),
    ], walls: [
      PlanWall(id: 'w', startNodeId: 'start', endNodeId: 'end'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanEditorProductionScreen(
          floor: floor,
          planTool: MeasurePlanTool.nodes,
          onChanged: () async {},
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenPlanGeometry: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final iv = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(iv.scaleEnabled, isTrue);
    expect(iv.panEnabled, isFalse);
    final transform = iv.transformationController!;
    final worldNode = MatrixUtils.transformPoint(
      transform.value, const Offset(16000, 16000),
    );
    final topLeft = tester.getTopLeft(find.byType(InteractiveViewer));
    final beforeX = floor.nodeById('start')!.xMm;
    final beforeY = floor.nodeById('start')!.yMm;

    final finger1 = await tester.startGesture(topLeft + worldNode);
    final finger2 = await tester.startGesture(
      topLeft + worldNode + const Offset(45, 20),
    );
    await finger2.moveBy(const Offset(50, 65));
    await tester.pump();
    await finger2.up();
    await finger1.up();
    await tester.pumpAndSettle();

    expect(floor.nodeById('start')!.xMm, beforeX);
    expect(floor.nodeById('start')!.yMm, beforeY);
    expect(tester.takeException(), isNull);
  });
}
