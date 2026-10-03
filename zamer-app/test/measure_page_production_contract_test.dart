import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page keeps UI Kit 02 CAD inside the unified workspace', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();
    final production = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    final editor = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final adapter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final painter =
        File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final v3 = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();

    expect(workspace.contains('MeasureUnifiedWorkspaceScreen('), isTrue);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(production.contains('PlanEditorMasterV4Screen('), isTrue);
    expect(production.contains('PlanEditorMasterV3Screen('), isFalse);

    expect(measure.contains("modeLabel: 'ЗАМЕР'"), isTrue);
    expect(measure.contains('onUndo: widget.onUndo'), isTrue);
    expect(measure.contains('onRedo: widget.onRedo'), isTrue);
    expect(measure.contains('ZMeasureViewTabs('), isTrue);
    expect(measure.contains('ZWorkspaceSubnav('), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isTrue);

    for (final required in const [
      'class _ToolRail',
      'class _ViewRail',
      'class _WallInspector',
      'class _ActionBar',
      'class _MaterialPanel',
      "'Сетка'",
      "'3D вид'",
      "'Этажи'",
      "'Привязка'",
      "'Настройки'",
    ]) {
      expect(
        editor.contains(required),
        isTrue,
        reason: 'Missing UI Kit CAD element: $required',
      );
    }

    for (final layer in const [
      "('План'",
      "('Пол'",
      "('Объекты'",
      "('Электрика'",
      "('Инженерия'",
      "('Материалы'",
    ]) {
      expect(measure.contains(layer), isTrue, reason: 'Missing Measure layer: $layer');
    }

    expect(adapter.contains('class CadPlanPainter'), isTrue);
    expect(adapter.contains('extends CadPlanPainterV3'), isTrue);
    expect(v3.contains('CadPlanPainterV2('), isTrue);
    expect(v3.contains('ImportedTopViewAssets.instance'), isTrue);
    expect(v3.contains('paintImage('), isTrue);
    expect(painter.contains('_objects(canvas)'), isTrue);
    expect(painter.contains('_drawFinish('), isTrue);
    expect(painter.contains('DoorSwing'), isTrue);
    expect(painter.contains('TopViewObjectRenderer.draw('), isTrue);
  });
}
