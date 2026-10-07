import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/renderer3d/render_quality.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('every non-procedural catalog item resolves to bundled GLB assets', () {
    for (final item in ObjectCatalog.items) {
      if (item.procedural) {
        expect(
          ZamerModelAssetCatalog.byId(item.id),
          isNull,
          reason: 'Procedural object ${item.id} must not request a GLB',
        );
        continue;
      }

      final model = ZamerModelAssetCatalog.byId(item.id);
      expect(model, isNotNull, reason: 'No model mapping for ${item.id}');
      for (final quality in ZamerRenderQuality.values) {
        final path = model!.assetPathFor(quality);
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'Missing ${quality.name} GLB for ${item.id}: $path',
        );
      }
      expect(model.nativeWidthMm, greaterThan(0));
      expect(model.nativeDepthMm, greaterThan(0));
      expect(model.nativeHeightMm, greaterThan(0));
    }
  });

  test('premium furniture uses mobile realtime and high Photo 4K assets', () {
    for (final id in <String>[
      'sofa-sand',
      'bed-sand',
      'armchair-sand',
      'table-walnut',
    ]) {
      final model = ZamerModelAssetCatalog.byId(id)!;
      expect(
        model.assetPathFor(ZamerRenderQuality.quality),
        contains('_mobile.glb'),
      );
      expect(
        model.assetPathFor(ZamerRenderQuality.photo4k),
        contains('_high.glb'),
      );
    }
  });
}
