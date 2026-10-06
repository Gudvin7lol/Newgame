import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure production screen routes through exact UI KIT 02 editor v4', () {
    final source = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    expect(source.contains("import 'plan_editor_master_v4_screen.dart';"), isTrue);
    expect(source.contains('PlanEditorMasterV4Screen('), isTrue);
    expect(source.contains('PlanEditorMasterV3Screen('), isFalse);
  });

  test('UI KIT 02 CAD essentials stay present without duplicate chrome', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final adapter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final painter =
        File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final v3 = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final objects =
        File('lib/widgets/top_view_object_renderer.dart').readAsStringSync();

    for (final required in const [
      '_ToolRail',
      '_ViewRail',
      '_WallInspector',
      '_MaterialPanel',
      '_CanvasControls',
      '_UndoRedo',
      'GeometryService.addWallFromNode(',
      'ControlMeasure(',
      'DimensionRecord(',
      'WallOpening(',
      'Стена',
      'Проём',
      'Размер',
      'Проверка',
      'Сетка',
      'Привязка',
      'Геометрия',
      "'Пол'",
      "'Стены'",
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing compact UI KIT 02 CAD element: $required',
      );
    }

    for (final removedDuplicate in const [
      'class _ActionBar',
      "label: '3D вид'",
      "label: 'Этажи'",
      "label: 'Настройки'",
    ]) {
      expect(
        source.contains(removedDuplicate),
        isFalse,
        reason: 'Duplicate Measure chrome returned: $removedDuplicate',
      );
    }

    expect(adapter.contains('extends CadPlanPainterV3'), isTrue);
    expect(v3.contains('CadPlanPainterV2('), isTrue);
    expect(v3.contains('ImportedTopViewAssets.instance'), isTrue);
    expect(v3.contains('paintImage('), isTrue);
    expect(painter.contains('_drawFinish('), isTrue);
    expect(painter.contains('_objects(canvas)'), isTrue);
    expect(painter.contains('TopViewObjectRenderer.draw('), isTrue);
    expect(painter.contains('DoorSwing'), isTrue);
    expect(painter.contains("settings.laminatePattern == 'herringbone'"), isTrue);
    expect(objects.contains("id.startsWith('bed-')"), isTrue);
    expect(objects.contains("id.startsWith('sofa-')"), isTrue);
    expect(objects.contains("id == 'shower'"), isTrue);
  });

  test('room can be selected and a material is applied directly', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    for (final required in const [
      '_selectedRoomFaceKey',
      '_pointInPolygon(',
      '_roomAt(',
      '_applyMaterial(',
      "settings.floorMaterialId = material.id",
      "settings.wallMaterialId = material.id",
      'Сначала нажмите на помещение.',
      'Нажмите на помещение на плане',
      "label: 'Помещение'",
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing direct room-material behavior: $required',
      );
    }
  });

  test('Master editor v4 keeps the plan dominant with collapsible materials', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source.contains('height: 66'), isTrue);
    expect(source.contains('height: expanded ? 132 : 38'), isTrue);
    expect(source.contains('width: 54'), isTrue);
    expect(source.contains('onZoomIn'), isTrue);
    expect(source.contains('onZoomOut'), isTrue);
    expect(source.contains('MaterialCatalog.floorFinishes'), isTrue);
    expect(source.contains('MaterialCatalog.wallFinishes'), isTrue);
    expect(source.contains('.take(8)'), isFalse);
  });
}
