import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/generated_material_ids.dart';
import 'package:zamer_app/services/material_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('generated ZAMER materials are installable runtime assets', () {
    expect(MaterialCatalog.generatedV1.length, 12);
    final ids = MaterialCatalog.generatedV1.map((e) => e.id).toSet();
    expect(ids, GeneratedMaterialIds.all);

    for (final preset in MaterialCatalog.generatedV1) {
      final asset = preset.textureAsset;
      expect(asset, isNotNull, reason: 'No texture for ${preset.id}');
      expect(
        asset!.startsWith('assets/textures/generated_v1/'),
        isTrue,
        reason: 'Generated texture escaped the +79 pack: ${preset.id}',
      );
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
      expect(preset.roughness, isNotNull, reason: 'No roughness for ${preset.id}');
    }
  });

  test('production 3D furniture is present in catalog with complete LOD chains', () {
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
      expect(asset!.hasCompleteLodChain, isTrue, reason: 'Incomplete LOD for $id');
      expect(File(asset.assetPath).existsSync(), isTrue);
      expect(File(asset.lod1AssetPath!).existsSync(), isTrue);
      expect(File(asset.lod2AssetPath!).existsSync(), isTrue);
    }
  });

  test('catalog thumbnails render production models from richer LOD1', () {
    final source = File('lib/widgets/model_thumbnail.dart').readAsStringSync();
    expect(source.contains('asset.hasLod1'), isTrue);
    expect(source.contains('ZamerModelLod.lod1'), isTrue);
    expect(source.contains("'3D'"), isTrue);
  });
}
