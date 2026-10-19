import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/measure_unified_workspace_screen.dart';
import 'package:zamer_app/screens/plan_editor_master_v4_screen.dart';
import 'package:zamer_app/screens/plan_editor_production_screen.dart';
import 'package:zamer_app/widgets/cad_plan_painter.dart';

void main() {
  test('Measure uses one production canvas for every plan operation', () {
    final measure =
        File('lib/screens/measure_unified_workspace_screen.dart')
            .readAsStringSync();
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final master =
        File('lib/screens/plan_editor_master_v4_screen.dart')
            .readAsStringSync();

    for (final tool in <String>[
      'MeasurePlanTool.overview',
      'MeasurePlanTool.select',
      'MeasurePlanTool.nodes',
      'MeasurePlanTool.exterior',
      'MeasurePlanTool.partition',
      'MeasurePlanTool.arc',
      'MeasurePlanTool.precision',
      'MeasurePlanTool.openings',
      'MeasurePlanTool.demolition',
      'MeasurePlanTool.dimensions',
    ]) {
      expect(measure, contains(tool), reason: 'Missing main toolbar tool: $tool');
    }

    expect(measure, contains('PlanEditorProductionScreen('));
    expect(measure, contains('planTool: _planTool'));
    expect(measure, isNot(contains('PlanEditorScreen(')));
    expect(measure, isNot(contains('PlanGeometryToolsScreen(')));
    expect(measure, contains('_planToolbar()'));
    expect(measure, contains('measure-plan-more'));
    expect(measure, isNot(contains('_planActions()')));
    expect(workspace, isNot(contains('Расширенный редактор')));
    expect(workspace, isNot(contains('_openAdvancedEditor')));

    expect(master, contains('GeometryService.addWallFromNode('));
    expect(master, contains('GeometryService.addArcWallFromNode('));
    expect(master, contains('GeometryService.finalizeNodeMove('));
    expect(master, contains('GeometryService.snapMoveTarget('));
    expect(master, contains('OrthogonalWallEditService.move('));
    expect(master, contains('_toggleDemolition('));
    expect(master, contains('_addOpening(p, chooseType: true)'));
    expect(master, contains("ValueKey('measure-shared-canvas')"));
  });

  test('project operations moved to overflow, not another permanent toolbar', () {
    final measure =
        File('lib/screens/measure_unified_workspace_screen.dart')
            .readAsStringSync();
    for (final label in <String>[
      'Импорт плана',
      'Помещения',
      'Этажи',
      'Каталог',
      'Проверка обмера',
      'PDF',
    ]) {
      expect(measure, contains(label));
    }
    expect(measure, contains('PopupMenuButton<String>('));
    expect(measure, contains("if (_layer != 0) ...["));
  });

  testWidgets('production canvas state survives changing geometry tools',
      (tester) async {
    tester.view.physicalSize = const Size(460, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f', name: 'Этаж');
    Widget screen(MeasurePlanTool mode) => MaterialApp(
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

    await tester.pumpWidget(screen(MeasurePlanTool.overview));
    await tester.pump();
    final editor = find.byType(PlanEditorMasterV4Screen);
    expect(editor, findsOneWidget);
    final originalState = tester.state(editor);
    final canvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is CadPlanPainter,
    );
    expect(canvas, findsOneWidget);
    expect(find.byKey(const ValueKey('measure-shared-canvas')), findsOneWidget);

    for (final mode in [
      MeasurePlanTool.exterior,
      MeasurePlanTool.partition,
      MeasurePlanTool.nodes,
      MeasurePlanTool.precision,
      MeasurePlanTool.openings,
      MeasurePlanTool.demolition,
      MeasurePlanTool.select,
      MeasurePlanTool.overview,
    ]) {
      await tester.pumpWidget(screen(mode));
      await tester.pump();
      expect(tester.state(editor), same(originalState),
          reason: 'the plan renderer must never be swapped out for $mode');
      expect(tester.widget<PlanEditorMasterV4Screen>(editor).planTool, mode);
      expect(canvas, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Measure toolbar tool requests retain one plan painter',
      (tester) async {
    tester.view.physicalSize = const Size(460, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Этаж');
    final project = MeasureProject(id: 'p', name: 'Квартира', floors: [floor]);
    final current = ValueNotifier<MeasurePlanTool>(MeasurePlanTool.overview);
    addTearDown(current.dispose);
    await tester.pumpWidget(MaterialApp(
      home: MeasureUnifiedWorkspaceScreen(
        project: project,
        floor: floor,
        onChanged: () async {},
        onUndo: null,
        onRedo: null,
        canUndo: false,
        canRedo: false,
        onMore: () {},
        onOpen3D: () {},
        onOpenPhoto: () {},
        onOpenReview: () {},
        planToolRequest: current,
        onOpenFloors: () {},
        onOpenRooms: () {},
        onScanPlan: () {},
        onExportPdf: () {},
        onHome: () {},
        onCatalog: () {},
        onProfile: () {},
        onPrimaryMode: (_) {},
      ),
    ));
    await tester.pump();
    final editor = find.byType(PlanEditorMasterV4Screen);
    expect(editor, findsOneWidget);
    final originalState = tester.state(editor);
    current.value = MeasurePlanTool.exterior;
    await tester.pump();
    expect(tester.state(editor), same(originalState));
    expect(find.byKey(const ValueKey('measure-shared-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
