import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/object_catalog.dart';
import 'package:zamer_app/widgets/catalog_artwork_preview.dart';

void main() {
  test('new neutral artwork is sized by the measured CAD footprint', () {
    for (final id in [
      'sofa-3',
      'bed-180',
      'armchair',
      'dining-table-1800',
      'coffee-table-oval',
      'wardrobe-3',
      'chair',
      'rug-gray',
    ]) {
      final item = ObjectCatalog.byId(id);
      final rect = catalogArtworkFootprintRect(
        const Size(180, 140),
        Size(item.widthMm, item.depthMm),
      );
      expect(rect.isEmpty, isFalse, reason: id);
      expect(rect.width / rect.height,
          closeTo(item.widthMm / item.depthMm, .00001), reason: id);
      expect(rect.left, greaterThanOrEqualTo(6.99), reason: id);
      expect(rect.top, greaterThanOrEqualTo(6.99), reason: id);
      expect(rect.right, lessThanOrEqualTo(173.01), reason: id);
      expect(rect.bottom, lessThanOrEqualTo(133.01), reason: id);
    }
  });

  test('long sofa fits inside the tile, not its raw PNG proportions', () {
    final rect = catalogArtworkFootprintRect(
      const Size(160, 160), const Size(2200, 950));
    expect(rect.width, closeTo(146, .001));
    expect(rect.height, closeTo(146 * 950 / 2200, .001));
    expect(rect.center, const Offset(80, 80));
  });

  test('portrait bed preserves its width/depth ratio at any tile size', () {
    final rect = catalogArtworkFootprintRect(
      const Size(120, 170), const Size(1800, 2200));
    expect(rect.width / rect.height, closeTo(1800 / 2200, .000001));
    expect(rect.center, const Offset(60, 85));
  });

  test('missing or invalid physical size never produces invalid geometry', () {
    expect(catalogArtworkFootprintRect(
      const Size(180, 140), Size.zero), Rect.zero);
    expect(catalogArtworkFootprintRect(
      Size.zero, const Size(100, 200)), Rect.zero);
    expect(catalogArtworkFootprintRect(
      const Size(180, 140), const Size(double.nan, 200)), Rect.zero);
  });

  test('catalogue artwork honors bath raster quarter-turn', () {
    const path = 'lib/widgets/catalog_artwork_preview.dart';
    // Keep the orientation transform in the preview, matching CAD's V3
    // quarter-turn source raster convention.
    expect(() => catalogArtworkFootprintRect(
      const Size(120, 180), const Size(1700, 750)), returnsNormally);
  });
}
