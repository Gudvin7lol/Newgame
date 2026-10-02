import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure CAD uses the imported V3 renderer with V2 fallback', () {
    final adapter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final painter = File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final v3 = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final imported =
        File('lib/services/imported_top_view_assets.dart').readAsStringSync();

    expect(adapter.contains('extends CadPlanPainterV3'), isTrue);
    expect(v3.contains('CadPlanPainterV2('), isTrue);
    expect(v3.contains('ImportedTopViewAssets.instance'), isTrue);
    expect(v3.contains('paintImage('), isTrue);
    expect(imported.contains('assets/topview/imported_2026_10_02'), isTrue);

    // +107 renders top views from the exact production LOD0 GLBs, so the
    // approved 2D symbol and the live 3D object cannot silently diverge.
    expect(imported.contains("'sofa-3': 'featured_sofa_3'"), isTrue);
    expect(imported.contains("'bed-180': 'featured_bed_180'"), isTrue);
    expect(imported.contains("'armchair': 'featured_armchair'"), isTrue);
    expect(imported.contains("'coffee-table': 'featured_coffee_table'"), isTrue);
    expect(imported.contains("'tv-console-1600': 'featured_tv_console'"), isTrue);
    expect(imported.contains("'wardrobe-sliding-2000': 'featured_wardrobe'"), isTrue);
    expect(imported.contains("'kitchen-drawers-600': 'kitchen_drawers'"), isTrue);
    expect(imported.contains("'kitchen-sink-600-pro': 'kitchen_sink'"), isTrue);

    expect(painter.contains('settings.floorDirectionDeg'), isTrue);
    expect(painter.contains('settings.laminatePlankLengthMm'), isTrue);
    expect(painter.contains('settings.laminatePlankWidthMm'), isTrue);
    expect(painter.contains('settings.tileWidthMm'), isTrue);
    expect(painter.contains('settings.tileHeightMm'), isTrue);
    expect(painter.contains("settings.laminatePattern == 'herringbone'"), isTrue);
    expect(painter.contains('_marbleVeins('), isTrue);
    expect(painter.contains('_terrazzo('), isTrue);
    expect(painter.contains('TopViewObjectRenderer.draw('), isTrue);
  });

  test('top-view library contains real symbols for main interior categories', () {
    final source =
        File('lib/widgets/top_view_object_renderer.dart').readAsStringSync();

    for (final required in const [
      '_bed(',
      '_sofa(',
      '_cornerSofa(',
      '_armchair(',
      '_table(',
      '_chair(',
      '_storage(',
      '_kitchen(',
      '_fridge(',
      '_appliance(',
      '_toilet(',
      '_sink(',
      '_bath(',
      '_shower(',
      '_radiator(',
      '_plant(',
      '_lighting(',
    ]) {
      expect(source.contains(required), isTrue, reason: 'Missing $required');
    }
  });
}
