import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/generated_material_ids.dart';
import 'package:zamer_app/services/generated_pbr_finish_catalog.dart';
import 'package:zamer_app/services/material_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('new finish pack is exposed as physical PBR materials', () {
    const ids = <String>{
      GeneratedMaterialIds.oakNaturalPbr,
      GeneratedMaterialIds.walnutPbr,
      GeneratedMaterialIds.marbleBiancoPbr,
      GeneratedMaterialIds.concreteWarmPbr,
      GeneratedMaterialIds.plasterMineralPbr,
      GeneratedMaterialIds.graphiteTilePbr,
    };

    for (final id in ids) {
      expect(MaterialCatalog.presets.any((preset) => preset.id == id), isTrue);
      final pbr = GeneratedPbrFinishCatalog.byId(id);
      expect(pbr, isNotNull, reason: '$id must have normal/roughness maps');
      expect(pbr!.realWorldTileMm, greaterThan(0));
      expect(pbr.normalScale, greaterThan(0));
    }
  });

  test('new equipment pack uses complete production LOD chains', () {
    const ids = <String>{'washer', 'toilet', 'chandelier-ring', 'rug-2000x1400'};

    for (final id in ids) {
      expect(ObjectCatalog.items.any((item) => item.id == id), isTrue);
      final asset = ZamerModelAssetCatalog.byId(id);
      expect(asset, isNotNull, reason: '$id must resolve to a render asset');
      expect(asset!.hasCompleteLodChain, isTrue);
      expect(ZamerModelAssetCatalog.productionLodIds, contains(id));
    }
  });
}
