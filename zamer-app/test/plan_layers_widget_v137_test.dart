import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';
import 'package:zamer_app/services/plan_view_layers.dart';
import 'package:zamer_app/widgets/cad_plan_painter.dart';

void main() {
  testWidgets('Layers button opens controls without replacing shared canvas',
      (tester) async {
    tester.view.physicalSize = const Size(460, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'floor', name: 'Этаж');
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanEditorProductionScreen(
          floor: floor,
          onChanged: () async { saved++; },
          planTool: MeasurePlanTool.overview,
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenPlanGeometry: () {},
        ),
      ),
    ));
    await tester.pump();
    final canvas = find.byKey(const ValueKey('measure-shared-canvas'));
    expect(canvas, findsOneWidget);
    final painterBefore = tester.widget<CustomPaint>(canvas).painter;
    expect(painterBefore, isA<CadPlanPainter>());

    await tester.tap(find.byKey(
        const ValueKey('open-layers-and-collisions')));
    await tester.pumpAndSettle();

    expect(find.text('Слои и коллизии'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-layers-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('layer-furniture')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('layer-furniture')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(
        const ValueKey('collisions-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collisions-toggle')));
    await tester.pump();
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(saved, 1);
    final persisted = PlanViewLayers.fromMap(floor.layerVisibility);
    expect(persisted.content.contains(PlanContentLayer.furniture), isFalse);
    expect(persisted.showClashes, isTrue);
    expect(canvas, findsOneWidget);
    expect(tester.widget<CustomPaint>(canvas).painter, isA<CadPlanPainter>());
    expect(tester.takeException(), isNull);
  });
}
