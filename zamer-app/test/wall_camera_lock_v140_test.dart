import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';

Widget testScreen(FloorPlan floor, MeasurePlanTool mode) => MaterialApp(
      home: Scaffold(
        body: PlanEditorProductionScreen(
          floor: floor,
          planTool: mode,
          onChanged: () async {},
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenPlanGeometry: () {},
        ),
      ),
    );

void main() {
  testWidgets('one finger cannot pan or zoom camera while building walls',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'floor', name: 'Обмер');
    await tester.pumpWidget(testScreen(floor, MeasurePlanTool.partition));
    await tester.pumpAndSettle();

    InteractiveViewer viewer() =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final transform = viewer().transformationController!;
    final initial = List<double>.of(transform.value.storage);
    expect(viewer().panEnabled, isFalse);
    expect(viewer().scaleEnabled, isFalse);

    final rect = tester.getRect(find.byType(InteractiveViewer));
    final fingerStart = rect.center - const Offset(45, 95);
    await tester.dragFrom(fingerStart, const Offset(95, 135));
    await tester.pumpAndSettle();
    expect(transform.value.storage, orderedEquals(initial),
        reason: 'drawing a wall must not pan the room on a phone');

    // The initial tap can still place the first vertex without navigation.
    await tester.tapAt(rect.center - const Offset(70, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wall-build-exact-length')),
        findsOneWidget);
    final before = List<double>.of(transform.value.storage);
    await tester.dragFrom(rect.center, const Offset(-75, 50));
    await tester.pumpAndSettle();
    expect(transform.value.storage, orderedEquals(before),
        reason: 'previewing a chained wall must not move its start');
  });

  testWidgets('hand toggles camera navigation without drawing new walls',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'floor', name: 'Обмер');
    await tester.pumpWidget(testScreen(floor, MeasurePlanTool.exterior));
    await tester.pumpAndSettle();
    InteractiveViewer viewer() =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final transform = viewer().transformationController!;
    final hand = find.byKey(const ValueKey('wall-camera-navigation'));
    expect(hand, findsOneWidget);
    expect(viewer().panEnabled, isFalse);

    await tester.tap(hand);
    await tester.pumpAndSettle();
    expect(viewer().panEnabled, isTrue);
    expect(viewer().scaleEnabled, isTrue);
    final rect = tester.getRect(find.byType(InteractiveViewer));
    final before = List<double>.of(transform.value.storage);
    await tester.dragFrom(rect.center, const Offset(60, -40));
    await tester.pumpAndSettle();
    expect(transform.value.storage, isNot(orderedEquals(before)),
        reason: 'hand mode should really let the user pan');

    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    expect(floor.walls, isEmpty);
    expect(floor.nodes, isEmpty,
        reason: 'tapping in hand mode must not start wall construction');

    await tester.tap(hand);
    await tester.pumpAndSettle();
    expect(viewer().panEnabled, isFalse);
    expect(viewer().scaleEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera lock is only for construction; select still pans',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'floor', name: 'Обмер');
    await tester.pumpWidget(testScreen(floor, MeasurePlanTool.select));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer));
    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isTrue);
    expect(find.byKey(const ValueKey('wall-camera-navigation')), findsNothing);
  });

  test('gesture lock implementation keeps CAD viewport and tool state',
      () {
    final src =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    expect(src, contains('bool get _cameraGestureEnabled'));
    expect(src, contains('panEnabled:'));
    expect(src, contains('_cameraGestureEnabled'));
    expect(src, contains('_edgePanTick()'));
    expect(src, contains('scaleEnabled:'));
    expect(src, contains('_moveCameraInsteadOfDrawing'));
    expect(src, contains('_openingDragUpdate'));
    expect(src, contains('if (_moveCameraInsteadOfDrawing) return;'));
    expect(src, contains('void _updateWallGuideAt('));
    expect(src, contains('_drawingWall'));
    expect(src, contains("ValueKey('wall-camera-navigation')"));
  });
}
