import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure production screen routes through UI KIT 02 master editor', () {
    final source = File('lib/screens/plan_editor_production_screen.dart')
        .readAsStringSync();
    expect(source.contains("import 'plan_editor_master_screen.dart';"), isTrue);
    expect(source.contains('PlanEditorMasterScreen('), isTrue);
  });

  test('UI KIT 02 CAD essentials are present and functional', () {
    final source = File('lib/screens/plan_editor_master_screen.dart')
        .readAsStringSync();

    for (final required in const [
      '_CadToolRail',
      '_RightRail',
      '_SelectedWallPanel',
      '_QuickTools',
      '_MaterialStrip',
      '_MiniMap',
      '_ScaleBadge',
      'DimensionSource _dimensionSource',
      "floor.dimensionRecords['control:",
      'source: _dimensionSource',
      'Стена',
      'Проём',
      'Размер',
      'Проверка',
      'Материал стены',
      'Радиус/узлы',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing UI KIT 02 CAD contract element: $required',
      );
    }
  });

  test('Master editor reserves canvas space for CAD inspector', () {
    final source = File('lib/screens/plan_editor_master_screen.dart')
        .readAsStringSync();
    expect(source.contains('double _bottomReserve()'), isTrue);
    expect(source.contains('usableH'), isTrue);
    expect(source.contains('screenCenter'), isTrue);
  });
}
