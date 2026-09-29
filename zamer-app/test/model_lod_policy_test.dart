import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/renderer3d/model_lod_policy.dart';

void main() {
  const production = ZamerModelAsset(
    catalogId: 'production',
    assetPath: 'model.glb',
    lod1AssetPath: 'model_lod1.glb',
    lod2AssetPath: 'model_lod2.glb',
    nativeWidthMm: 1000,
    nativeDepthMm: 1000,
    nativeHeightMm: 1000,
  );

  const legacy = ZamerModelAsset(
    catalogId: 'legacy',
    assetPath: 'legacy.glb',
    nativeWidthMm: 1000,
    nativeDepthMm: 1000,
    nativeHeightMm: 1000,
  );

  test('photo quality always selects production LOD0', () {
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 120,
        photoQuality: true,
        walkMode: true,
      ),
      ZamerModelLod.lod0,
    );
    expect(
      ZamerModelLodPolicy.pathFor(
        asset: production,
        visibleObjectCount: 120,
        photoQuality: true,
        walkMode: true,
      ),
      'model.glb',
    );
  });

  test('overview progressively lowers detail as scene gets heavier', () {
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 5,
        photoQuality: false,
        walkMode: false,
      ),
      ZamerModelLod.lod0,
    );
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 14,
        photoQuality: false,
        walkMode: false,
      ),
      ZamerModelLod.lod1,
    );
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 35,
        photoQuality: false,
        walkMode: false,
      ),
      ZamerModelLod.lod2,
    );
  });

  test('walk mode favors frame stability', () {
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 3,
        photoQuality: false,
        walkMode: true,
      ),
      ZamerModelLod.lod1,
    );
    expect(
      ZamerModelLodPolicy.select(
        asset: production,
        visibleObjectCount: 20,
        photoQuality: false,
        walkMode: true,
      ),
      ZamerModelLod.lod2,
    );
  });

  test('legacy models always remain on their base GLB', () {
    expect(
      ZamerModelLodPolicy.pathFor(
        asset: legacy,
        visibleObjectCount: 100,
        photoQuality: false,
        walkMode: true,
      ),
      'legacy.glb',
    );
  });
}
