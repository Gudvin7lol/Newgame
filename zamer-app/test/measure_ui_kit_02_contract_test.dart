import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure production screen routes through UI KIT 02 master editor v2', () {
    final source = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    expect(
      source.contains("import 'plan_editor_master_v2_screen.dart';"),
      isTrue,
    );
    expect(source.contains('PlanEditorMasterV2Screen('), isTrue);
    expect(source.contains('PlanEditorMasterScreen('), isFalse);
  });

  test('UI KIT 02 CAD essentials are present and functional in v2', () {
    final source = File('lib/screens/plan_editor_master_v2_screen.dart')
        .readAsStringSync();

    for (final required in const [
      '_MasterToolRail',
      '_MasterActionRail',
      '_WallInspectorV2',
      '_ToolbeltV2',
      '_CanvasNavigation',
      '_ScalePill',
      'DimensionSource _dimensionSource',
      "floor.dimensionRecords['control:",
      'source: _dimensionSource',
      'Стена',
      'Проём',
      'Размер',
      'Проверка',
      'WallMaterial.values',
      'Радиус / узлы',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing UI KIT 02 CAD contract element: $required',
      );
    }
  });

  test('Master editor v2 reserves canvas space for contextual inspector', () {
    final source = File('lib/screens/plan_editor_master_v2_screen.dart')
        .readAsStringSync();
    expect(source.contains('double get _bottomReserve'), isTrue);
    expect(source.contains('usableH'), isTrue);
    expect(source.contains('screenCenter'), isTrue);
    expect(source.contains('height: 160'), isTrue);
  });
}
