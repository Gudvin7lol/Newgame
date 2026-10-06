import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/production_asset_catalog.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/generated_material_ids.dart';
import 'package:zamer_app/services/material_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('generated ZAMER materials are installable runtime assets', () {
    final generated = <VisualMaterialPreset>[
      ...MaterialCatalog.generatedV1,
      ...MaterialCatalog.runtimeV4,
    ];
    expect(generated.length, GeneratedMaterialIds.all.length);
    final ids = generated.map((e) => e.id).toSet();
    expect(ids, GeneratedMaterialIds.all);

    for (final preset in generated) {
      final asset = preset.textureAsset;
      expect(asset, isNotNull, reason: 'No texture for ${preset.id}');
      expect(
        asset!.startsWith('assets/textures/'),
        isTrue,
        reason:
            'Generated texture is outside bundled texture assets: ${preset.id}',
      );
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
      expect(
        preset.roughness,
        isNotNull,
        reason: 'No roughness for ${preset.id}',
      );
    }
  });

  test(
    'production 3D furniture is present in catalog with complete LOD chains',
    () {
      const expected = <String>{
        'armchair',
        'bed-160',
        'bed-180',
        'coffee-table',
        'dining-chair-upholstered',
        'dining-table-1800',
        'dresser-1200',
        'nightstand',
        'office-desk-1400',
        'sofa-2',
        'sofa-3',
        'sofa-corner',
        'sofa-modular',
        'table-round',
        'tv-console-1600',
        'wardrobe-sliding-2000',
      };

      expect(ZamerModelAssetCatalog.productionLodIds, containsAll(expected));
      for (final id in expected) {
        expect(
          ObjectCatalog.items.any((item) => item.id == id),
          isTrue,
          reason: '$id is not exposed in Оснащение',
        );
        final asset = ZamerModelAssetCatalog.byId(id);
        expect(asset, isNotNull, reason: 'No GLB mapping for $id');
        expect(
          asset!.hasCompleteLodChain,
          isTrue,
          reason: 'Incomplete LOD for $id',
        );
        expect(File(asset.assetPath).existsSync(), isTrue);
        expect(File(asset.lod1AssetPath!).existsSync(), isTrue);
        expect(File(asset.lod2AssetPath!).existsSync(), isTrue);
      }
    },
  );

  test('production links approved 2D objects to exact production GLBs', () {
    final linked = ZamerProductionCatalog.linked2d3d.toList(growable: false);
    expect(linked, isNotEmpty);
    expect(
      linked.length,
      greaterThanOrEqualTo(ZamerModelAssetCatalog.productionLodIds.length),
      reason: 'Production bridge must grow with the approved 3D library',
    );

    for (final production in linked) {
      final planId = production.planCatalogId!;
      final planItem = ObjectCatalog.items.singleWhere(
        (item) => item.id == planId,
        orElse: () => throw StateError('Missing 2D catalog item $planId'),
      );
      final model = ZamerModelAssetCatalog.byId(planId);

      expect(model, isNotNull, reason: 'No 3D resolver entry for $planId');
      expect(
        model!.assetPath,
        production.model3d,
        reason: '$planId does not resolve through production catalog',
      );
      expect(
        File(production.model3d!).existsSync(),
        isTrue,
        reason: 'Missing production GLB for ${production.id}',
      );
      expect(production.sizeMm.width, planItem.widthMm);
      expect(production.sizeMm.depth, planItem.depthMm);
      expect(production.sizeMm.height, planItem.heightMm);
      expect(ZamerProductionCatalog.byId(production.id), same(production));
      expect(ZamerProductionCatalog.byPlanCatalogId(planId), same(production));
    }
  });

  test('catalog thumbnails render production models from richer LOD1', () {
    final source = File('lib/widgets/model_thumbnail.dart').readAsStringSync();
    expect(source.contains('asset.hasLod1'), isTrue);
    expect(source.contains('ZamerModelLod.lod1'), isTrue);
    expect(source.contains("'3D'"), isTrue);
  });
}
