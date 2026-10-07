import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  test('floor and tile visual presets bundle their finish textures', () {
    final textured = MaterialCatalog.presets.where(
      (preset) => preset.category == 'Пол' || preset.category == 'Плитка',
    );
    expect(textured, isNotEmpty);
    for (final preset in textured) {
      expect(
        preset.textureAsset,
        isNotNull,
        reason: 'Нет textureAsset у ${preset.id}',
      );
      expect(
        File(preset.textureAsset!).existsSync(),
        isTrue,
        reason: 'Не найден ${preset.textureAsset}',
      );

      for (final asset in <String?>[
        preset.textureAssetMobile,
        preset.textureAssetPhoto,
        preset.normalAsset,
        preset.normalAssetMobile,
        preset.normalAssetPhoto,
        preset.metallicRoughnessAsset,
        preset.metallicRoughnessAssetMobile,
        preset.metallicRoughnessAssetPhoto,
        preset.occlusionAsset,
        preset.occlusionAssetMobile,
        preset.occlusionAssetPhoto,
      ]) {
        if (asset == null) continue;
        expect(
          File(asset).existsSync(),
          isTrue,
          reason: 'Не найдена PBR-карта $asset для ${preset.id}',
        );
      }
      expect(preset.normalScale, greaterThanOrEqualTo(0));
      expect(preset.occlusionStrength, inInclusiveRange(0, 1));
    }

    for (final id in <String>[
      'PAINT_01',
      'PLASTER_01',
      'BRICK_01',
      'TILE_01',
      'TILE_02',
      'TILE_03',
      'LAM_01',
      'LAM_02',
      'LAM_03',
      'CONCRETE_01',
      'MARBLE_01',
      'TRAVERTINE_01',
    ]) {
      final preset = MaterialCatalog.byId(id);
      expect(preset.textureAsset, isNotNull);
      expect(preset.textureAssetMobile, isNotNull);
      expect(preset.textureAssetPhoto, isNotNull);
      expect(preset.normalAsset, isNotNull);
      expect(preset.normalAssetMobile, isNotNull);
      expect(preset.normalAssetPhoto, isNotNull);
      expect(preset.metallicRoughnessAsset, isNotNull);
      expect(preset.metallicRoughnessAssetPhoto, isNotNull);
      expect(preset.occlusionAsset, isNotNull);
      expect(preset.occlusionAssetPhoto, isNotNull);
      expect(preset.physicalWidthMm, greaterThan(0));
      expect(preset.physicalHeightMm, greaterThan(0));
    }
  });
}
