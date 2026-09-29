import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('every current catalog item has a safe bundled GLB asset', () {
    for (final item in ObjectCatalog.items) {
      final model = ZamerModelAssetCatalog.byId(item.id);
      expect(model, isNotNull, reason: 'No safe model mapping for ${item.id}');
      expect(
        File(model!.assetPath).existsSync(),
        isTrue,
        reason: 'Missing GLB file for ${item.id}: ${model.assetPath}',
      );
      expect(model.hasRenderableDimensions, isTrue);
      expect(model.nativeWidthMm, item.widthMm);
      expect(model.nativeDepthMm, item.depthMm);
      expect(model.nativeHeightMm, item.heightMm);
    }
  });

  test('unknown catalogue id does not produce a GLB asset', () {
    expect(ZamerModelAssetCatalog.byId('missing-model-id'), isNull);
  });

  test('dimension guard rejects invalid values before GPU scaling', () {
    const zero = ZamerModelAsset(
      catalogId: 'zero',
      assetPath: 'zero.glb',
      nativeWidthMm: 0,
      nativeDepthMm: 500,
      nativeHeightMm: 500,
    );
    const negative = ZamerModelAsset(
      catalogId: 'negative',
      assetPath: 'negative.glb',
      nativeWidthMm: 500,
      nativeDepthMm: -1,
      nativeHeightMm: 500,
    );
    const infinite = ZamerModelAsset(
      catalogId: 'infinite',
      assetPath: 'infinite.glb',
      nativeWidthMm: 500,
      nativeDepthMm: double.infinity,
      nativeHeightMm: 500,
    );

    expect(zero.hasRenderableDimensions, isFalse);
    expect(negative.hasRenderableDimensions, isFalse);
    expect(infinite.hasRenderableDimensions, isFalse);
  });
}
