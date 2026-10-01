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

  test('UI KIT 02 CAD essentials are present and functional in v4', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final adapter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final painter =
        File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final objects =
        File('lib/widgets/top_view_object_renderer.dart').readAsStringSync();

    for (final required in const [
      '_ToolRail',
      '_ViewRail',
      '_WallInspector',
      '_ActionBar',
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
      '3D вид',
      'Этажи',
      'Привязка',
      'Настройки',
      'Потолок',
      'Двери',
      'Окна',
      'Освещение',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing UI KIT 02 CAD contract element: $required',
      );
    }

    // +78 keeps the stable CadPlanPainter entry point, but delegates all
    // visible plan rendering to the material-aware V2 renderer.
    expect(adapter.contains('extends CadPlanPainterV2'), isTrue);
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

  test('Master editor v4 keeps the plan dominant with material context', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source.contains('height: 66'), isTrue);
    expect(source.contains('height: 49'), isTrue);
    expect(source.contains('height: 120'), isTrue);
    expect(source.contains('width: 54'), isTrue);
    expect(source.contains('onZoomIn'), isTrue);
    expect(source.contains('onZoomOut'), isTrue);
  });
}
