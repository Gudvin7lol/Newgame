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
        preset.normalAsset,
        preset.normalAssetMobile,
        preset.metallicRoughnessAsset,
        preset.metallicRoughnessAssetMobile,
        preset.occlusionAsset,
        preset.occlusionAssetMobile,
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
      'oak-smoked',
      'paint-warm-white',
      'tile-light-stone',
    ]) {
      final preset = MaterialCatalog.byId(id);
      expect(preset.textureAsset, isNotNull);
      expect(preset.textureAssetMobile, isNotNull);
      expect(preset.normalAsset, isNotNull);
      expect(preset.normalAssetMobile, isNotNull);
      expect(preset.metallicRoughnessAsset, isNotNull);
      expect(preset.occlusionAsset, isNotNull);
    }
  });
}
