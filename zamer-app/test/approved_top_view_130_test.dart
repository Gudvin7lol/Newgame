import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/imported_top_view_assets.dart';

void main() {
  test('approved 130 atlas is bundled and can be decoded as WebP', () {
    final imageFile =
        File('assets/topview/imported_2026_10_02/approved_130_atlas.webp');
    expect(imageFile.existsSync(), isTrue);
    final bytes = imageFile.readAsBytesSync();
    expect(bytes.length, greaterThan(30000));
    expect(bytes.length, lessThan(100000));
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WEBP');
  });

  test('approved 130 source rectangles map exactly four catalog models', () {
    final rects = ImportedTopViewAssets.approvedRects;
    expect(rects.keys.toSet(),
        {'sofa-3', 'sofa-corner', 'armchair', 'nightstand'});
    for (final entry in rects.entries) {
      final rect = entry.value;
      expect(rect.isEmpty, isFalse, reason: entry.key);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(640));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }
    expect(rects['sofa-3'], const ui.Rect.fromLTRB(9, 94, 312, 229));
    expect(rects['nightstand'], const ui.Rect.fromLTRB(335, 342, 624, 599));
  });

  test('Plan and Equipment share raster selection and vector fallback', () {
    final painter = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final screen =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();
    expect(painter.contains('canvas.drawImageRect('), isTrue);
    expect(screen.contains('CadPlanPainter('), isTrue);
    // Curated furniture must bypass the unrelated 3D thumbnail widget,
    // otherwise the catalogue still differs from Plan and Equipment.
    expect(
      screen.contains(
        'ImportedTopViewAssets.approvedRects.containsKey(item.id)',
      ),
      isTrue,
    );
  });
}
