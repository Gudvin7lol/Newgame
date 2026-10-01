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
    final painter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();

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
      expect(source.contains(required), isTrue, reason: 'Missing UI KIT 02 CAD contract element: $required');
    }

    expect(painter.contains('_finishPattern'), isTrue);
    expect(painter.contains('_objects(canvas)'), isTrue);
    expect(painter.contains("id.startsWith('bed-')"), isTrue);
    expect(painter.contains("id.startsWith('sofa-')"), isTrue);
    expect(painter.contains("id == 'shower'"), isTrue);
  });

  test('Master editor v4 gives more vertical space to the plan', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source.contains('height: 66'), isTrue);
    expect(source.contains('height: 49'), isTrue);
    expect(source.contains('height: 108'), isTrue);
    expect(source.contains('width: 54'), isTrue);
    expect(source.contains('onZoomIn'), isTrue);
    expect(source.contains('onZoomOut'), isTrue);
  });
}
