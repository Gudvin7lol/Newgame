import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

Widget testEditor(FloorPlan floor, MeasurePlanTool mode) => MaterialApp(
  home: Scaffold(
    body: PlanEditorProductionScreen(
      floor: floor,
      onChanged: () async {},
      planTool: mode,
      onOpenObjects: () {},
      onOpenReview: () {},
      onOpenPlanGeometry: () {},
    ),
  ),
);

void main() {
  test('production canvas contains wall drag hooks and inline dimension UI', () {
    final source =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    for (final method in <String>[
      'onInteractionStart: _wallDragStart',
      'onInteractionUpdate: _wallDragUpdate',
      'onInteractionEnd: (_) => unawaited(_wallDragFinish())',
      'OrthogonalWallEditService.move(',
      'WallDrawingService.snap(',
      'wall-build-exact-length',
      'wall-build-length-mm',
      'wall-build-angle-deg',
      'wall-build-apply',
    ]) {
      expect(source, contains(method), reason: 'Missing action $method');
    }
    expect(source, contains('endpointCaptureMm: .5'));
    expect(source, contains('endpointRoundingMm: 0'));
  });

  testWidgets('enter exact length inside same CAD viewport', (tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Test');
    floor.nodes.add(PlanNode(id: 'start', xMm: 0, yMm: 0));
    await tester.pumpWidget(testEditor(floor, MeasurePlanTool.partition));
    await tester.pumpAndSettle();

    // Map the known world origin to viewport-local pixels using the actual
    // fitted InteractiveViewer matrix; never guess a tap coordinate.
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer));
    final control = viewer.transformationController!;
    final point = MatrixUtils.transformPoint(
      control.value, const Offset(3300, 1100),
    );
    final viewportTopLeft =
        tester.getTopLeft(find.byType(InteractiveViewer));
    await tester.tapAt(viewportTopLeft + point);
    await tester.pumpAndSettle();

    final lengthButton = find.byKey(const ValueKey('wall-build-exact-length'));
    expect(lengthButton, findsOneWidget);
    await tester.tap(lengthButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('wall-build-length-mm')), '3123');
    await tester.enterText(
      find.byKey(const ValueKey('wall-build-angle-deg')), '90');
    await tester.tap(find.byKey(const ValueKey('wall-build-apply')));
    await tester.pumpAndSettle();
    expect(floor.walls, isNotEmpty);
    final wall = floor.walls.last;
    final a = floor.nodeById(wall.startNodeId)!;
    final b = floor.nodeById(wall.endNodeId)!;
    final distance = math.sqrt(math.pow(a.xMm - b.xMm, 2) +
        math.pow(a.yMm - b.yMm, 2));
    expect(distance, closeTo(3123, .0001));
    expect(tester.takeException(), isNull);
  });
}
