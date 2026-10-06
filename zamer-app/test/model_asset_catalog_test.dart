import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('every non-procedural catalog item has a bundled GLB asset', () {
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
      expect(
        File(model!.assetPath).existsSync(),
        isTrue,
        reason: 'Missing GLB file for ${item.id}: ${model.assetPath}',
      );
      expect(model.nativeWidthMm, item.widthMm);
      expect(model.nativeDepthMm, item.depthMm);
      expect(model.nativeHeightMm, item.heightMm);
    }
  });
}
