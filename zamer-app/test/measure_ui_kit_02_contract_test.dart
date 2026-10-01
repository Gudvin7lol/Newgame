import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure production screen routes through exact UI KIT 02 editor v3', () {
    final source = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    expect(
      source.contains("import 'plan_editor_master_v3_screen.dart';"),
      isTrue,
    );
    expect(source.contains('PlanEditorMasterV3Screen('), isTrue);
    expect(source.contains('PlanEditorMasterV2Screen('), isFalse);
  });

  test('UI KIT 02 CAD essentials are present and functional in v3', () {
    final source = File('lib/screens/plan_editor_master_v3_screen.dart')
        .readAsStringSync();

    for (final required in const [
      '_ExactToolRail',
      '_ExactViewRail',
      '_ExactWallInspector',
      '_ExactActionBar',
      '_ExactMaterialPanel',
      '_ViewportMiniMap',
      '_ViewportUndoRedo',
      'DimensionSource _dimensionSource',
      "floor.dimensionRecords['control:",
      'source: _dimensionSource',
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
  });

  test('Master editor v3 keeps the plan viewport dominant', () {
    final source = File('lib/screens/plan_editor_master_v3_screen.dart')
        .readAsStringSync();
    expect(source.contains('leftRail = 82.0'), isTrue);
    expect(source.contains('rightRail = 74.0'), isTrue);
    expect(source.contains('usableH'), isTrue);
    expect(source.contains('screenCenter'), isTrue);
    expect(source.contains('height: 76'), isTrue);
    expect(source.contains('height: 52'), isTrue);
    expect(source.contains('height: 96'), isTrue);
  });
}
