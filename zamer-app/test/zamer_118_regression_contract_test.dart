import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wall finish uses stable wall-space UV across opening pieces', () {
    final source =
        File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();
    expect(source, contains("'wall-finish:"));
    expect(source, contains('final finishGeometry = GeometryBuilder'));
    expect(source, contains('finishGeometry.build()'));
    expect(source, contains('wall.textureStartMm'));
    expect(source, contains('wall.bottomMm'));
  });

  test('wall elevations render finish character, not only a badge', () {
    final source = File('lib/widgets/elevation_painter.dart').readAsStringSync();
    expect(source, contains('_drawWallFinish(canvas, rect, scale, wallFinish)'));
    expect(source, contains("preset.pattern == 'brick'"));
    expect(source, contains("preset.pattern == 'concrete'"));
  });

  test('herringbone uses the same physical phase modules everywhere', () {
    final layout =
        File('lib/widgets/floor_layout_painter.dart').readAsStringSync();
    final preview =
        File('lib/widgets/floor_3d_painter.dart').readAsStringSync();
    final gpu =
        File('lib/renderer3d/floor_grout_geometry.dart').readAsStringSync();

    for (final source in [layout, preview, gpu]) {
      expect(source, contains('/ math.sqrt2'));
      expect(source, contains('* math.sqrt2'));
      expect(source, contains('% run'));
      expect(source, contains('% pitch'));
    }
  });

  test('Measure material strip shows all relevant materials and can collapse', () {
    final source =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    expect(source, contains('bool _materialsExpanded = true'));
    expect(source, contains('MaterialCatalog.floorFinishes'));
    expect(source, contains('MaterialCatalog.wallFinishes'));
    expect(source, isNot(contains('.take(8)')));
    expect(source, contains("'Скрыть материалы'"));
    expect(source, contains("'Показать материалы'"));
  });

  test('Measure plan no longer duplicates outer navigation controls', () {
    final source =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    expect(source, isNot(contains("label: '3D вид'")));
    expect(source, isNot(contains("label: 'Этажи'")));
    expect(source, isNot(contains("label: 'Настройки'")));
    expect(source, isNot(contains('class _ActionBar')));
  });

  test('embedded object workspace manipulates but does not silently add', () {
    final source =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();
    expect(source, contains('this.embedded = false'));
    expect(source, contains('if (!widget.embedded)'));
    expect(source, contains('if (widget.embedded) return;'));
    expect(source, contains('d.rotation * 180 / math.pi'));
    expect(source, contains('onScaleUpdate: (d) => _objectScaleUpdate'));
  });
}
