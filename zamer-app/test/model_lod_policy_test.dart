import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/renderer3d/model_lod_policy.dart';

void main() {
  test(
    'photo render uses LOD0 while dense interactive scenes use lower LODs',
    () {
      final asset = ZamerModelAssetCatalog.byId('armchair');
      expect(asset, isNotNull);
      final model = asset!;
      expect(model.hasCompleteLodChain, isTrue);

      expect(
        ZamerModelLodPolicy.pathFor(
          asset: model,
          visibleObjectCount: 40,
          photoQuality: true,
          walkMode: false,
        ),
        model.assetPath,
      );
      expect(
        ZamerModelLodPolicy.pathFor(
          asset: model,
          visibleObjectCount: 40,
          photoQuality: false,
          walkMode: false,
        ),
        model.lod2AssetPath,
      );
      expect(
        ZamerModelLodPolicy.pathFor(
          asset: model,
          visibleObjectCount: 12,
          photoQuality: false,
          walkMode: false,
        ),
        model.lod1AssetPath,
      );
    },
  );

  test('performance mode always chooses LOD2 while photo still wins', () {
    final asset = ZamerModelAssetCatalog.byId('armchair');
    expect(asset, isNotNull);
    final model = asset!;

    expect(
      ZamerModelLodPolicy.pathFor(
        asset: model,
        visibleObjectCount: 1,
        photoQuality: false,
        walkMode: false,
        performanceMode: true,
      ),
      model.lod2AssetPath,
    );
    expect(
      ZamerModelLodPolicy.pathFor(
        asset: model,
        visibleObjectCount: 1,
        photoQuality: true,
        walkMode: false,
        performanceMode: true,
      ),
      model.assetPath,
    );
  });
}
