import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/production_asset_catalog.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('every production LOD model has an explicit 2D to 3D bridge', () {
    for (final id in ZamerModelAssetCatalog.productionLodIds) {
      final bridge = ZamerProductionCatalog.byPlanCatalogId(id);
      expect(bridge, isNotNull, reason: 'Missing production bridge for $id');
      expect(
        bridge!.hasLinked2d3d,
        isTrue,
        reason: '$id is not linked to both plan and 3D assets',
      );
      expect(
        File(bridge.model3d!).existsSync(),
        isTrue,
        reason: 'Missing production GLB for $id: ${bridge.model3d}',
      );
    }
  });

  test('production bridge keeps the exact 2D catalogue footprint', () {
    for (final bridge in ZamerProductionCatalog.linked2d3d) {
      final planId = bridge.planCatalogId!;
      final matches = ObjectCatalog.items.where((item) => item.id == planId);
      expect(matches, isNotEmpty, reason: 'Unknown plan catalogue id $planId');
      final item = matches.first;

      expect(bridge.sizeMm.width, item.widthMm, reason: '$planId width drift');
      expect(bridge.sizeMm.depth, item.depthMm, reason: '$planId depth drift');
      expect(bridge.sizeMm.height, item.heightMm, reason: '$planId height drift');
    }
  });

  test('renderer resolves the canonical production GLB path', () {
    for (final id in ZamerModelAssetCatalog.productionLodIds) {
      final bridge = ZamerProductionCatalog.byPlanCatalogId(id)!;
      final rendererAsset = ZamerModelAssetCatalog.byId(id);
      expect(rendererAsset, isNotNull);
      expect(
        rendererAsset!.assetPath,
        bridge.model3d,
        reason: '$id renderer path bypasses production registry',
      );
    }
  });
}
