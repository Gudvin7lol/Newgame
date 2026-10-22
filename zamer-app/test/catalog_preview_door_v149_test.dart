import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue uses the approved 2D atlas before expensive GLB renders', () {
    final source = File('lib/widgets/catalog_artwork_preview.dart')
        .readAsStringSync();
    expect(source, contains('assets.curated131RectForCatalog'));
    expect(source, contains('assets.curated131Atlas'));
    expect(source, contains('assets.imageForCatalog'));
    expect(source, contains('assets.approvedAtlas'));
    expect(source, contains('ImportedTopViewAssets.instance.ensureLoaded()'));
    expect(source, contains('_resolved'));
    expect(source, contains('_CatalogArtworkPainter'));
    final card = File('lib/screens/master_equipment_screen.dart')
        .readAsStringSync();
    expect(card, contains('ZamerCatalogArtwork('));
    expect(card, contains('fallback: ZamerModelThumbnail('));
  });

  test('door inspector reports both wall-relative offsets with quick edits', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains("ValueKey('opening-offset-from-start')"));
    expect(src, contains("ValueKey('opening-offset-to-end')"));
    expect(src, contains('length -'));
    expect(src, contains('opening.offsetFromStartMm - opening.widthMm'));
    expect(src, contains('onPressed: _changeDoorHinge'));
    expect(src, contains('onPressed: _changeDoorSide'));
    expect(src, contains('const cardHeight = 176.0'));
  });
}
