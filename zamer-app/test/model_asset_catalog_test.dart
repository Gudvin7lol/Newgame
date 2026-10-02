import 'dart:io';
import 'dart:math' as math;

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
      if (!ZamerModelAssetCatalog.productionLodIds.contains(item.id)) {
        expect(model.nativeWidthMm, item.widthMm);
        expect(model.nativeDepthMm, item.depthMm);
        expect(model.nativeHeightMm, item.heightMm);
      }
    }
  });

  test('production assets expose complete existing LOD chains', () {
    expect(
      ZamerModelAssetCatalog.productionLodIds,
      containsAll(const {
        'washer',
        'toilet',
        'chandelier-ring',
        'rug-2000x1400',
      }),
    );
    for (final id in ZamerModelAssetCatalog.productionLodIds) {
      final model = ZamerModelAssetCatalog.byId(id);
      expect(model, isNotNull, reason: 'Missing production catalog item $id');
      expect(
        model!.hasCompleteLodChain,
        isTrue,
        reason: '$id has no LOD chain',
      );
      expect(File(model.assetPath).existsSync(), isTrue);
      expect(
        File(model.lod1AssetPath!).existsSync(),
        isTrue,
        reason: 'Missing LOD1 for $id',
      );
      expect(
        File(model.lod2AssetPath!).existsSync(),
        isTrue,
        reason: 'Missing LOD2 for $id',
      );
      expect(model.pathForLod(ZamerModelLod.lod0), model.assetPath);
      expect(model.pathForLod(ZamerModelLod.lod1), model.lod1AssetPath);
      expect(model.pathForLod(ZamerModelLod.lod2), model.lod2AssetPath);
    }
  });

  test('production native dimensions describe authored GLB bounds', () {
    final armchair = ZamerModelAssetCatalog.byId('armchair')!;
    expect(armchair.nativeWidthMm, 920);
    expect(armchair.nativeDepthMm, 900);
    expect(armchair.nativeHeightMm, 860);

    final sofa = ZamerModelAssetCatalog.byId('sofa-3')!;
    expect(sofa.nativeWidthMm, 2200);
    expect(sofa.nativeDepthMm, 950);
    expect(sofa.nativeHeightMm, 850);

    final featuredBed = ZamerModelAssetCatalog.byId('bed-180')!;
    expect(featuredBed.nativeWidthMm, 1800);
    expect(featuredBed.nativeDepthMm, 2200);
    expect(featuredBed.nativeHeightMm, 1130);

    final featuredTable = ZamerModelAssetCatalog.byId('coffee-table')!;
    expect(featuredTable.nativeWidthMm, 900);
    expect(featuredTable.nativeDepthMm, 900);
    expect(featuredTable.nativeHeightMm, 420);

    final bed = ZamerModelAssetCatalog.byId('bed-160')!;
    expect(bed.nativeWidthMm, 1800);
    expect(bed.nativeDepthMm, 2150);
    expect(bed.nativeHeightMm, 1050);

    final corner = ZamerModelAssetCatalog.byId('sofa-corner')!;
    expect(corner.nativeWidthMm, 2800);
    expect(corner.nativeDepthMm, 1900);
    expect(corner.nativeHeightMm, 880);
  });

  test('directional furniture carries a semantic facing correction', () {
    expect(
      ZamerModelAssetCatalog.byId('bed-160')!.yawCorrectionRad,
      closeTo(math.pi, 0.000001),
    );
    expect(
      ZamerModelAssetCatalog.byId('sofa-3')!.yawCorrectionRad,
      closeTo(math.pi, 0.000001),
    );
    expect(
      ZamerModelAssetCatalog.byId('dining-chair-upholstered')!.yawCorrectionRad,
      closeTo(math.pi, 0.000001),
    );
    expect(
      ZamerModelAssetCatalog.byId('dining-table-1800')!.yawCorrectionRad,
      0,
    );
    expect(ZamerModelAssetCatalog.byId('coffee-table')!.yawCorrectionRad, 0);
  });

  test('legacy assets fall back safely when an LOD is unavailable', () {
    const model = ZamerModelAsset(
      catalogId: 'legacy',
      assetPath: 'legacy.glb',
      nativeWidthMm: 500,
      nativeDepthMm: 500,
      nativeHeightMm: 500,
    );
    expect(model.hasCompleteLodChain, isFalse);
    expect(model.pathForLod(ZamerModelLod.lod0), 'legacy.glb');
    expect(model.pathForLod(ZamerModelLod.lod1), 'legacy.glb');
    expect(model.pathForLod(ZamerModelLod.lod2), 'legacy.glb');
    expect(model.yawCorrectionRad, 0);
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
