import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure CAD uses the +78 material-aware renderer', () {
    final adapter = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final painter = File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();

    expect(adapter.contains('extends CadPlanPainterV2'), isTrue);
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
