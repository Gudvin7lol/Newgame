import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/generated_material_ids.dart';
import 'package:zamer_app/services/generated_pbr_finish_catalog.dart';
import 'package:zamer_app/services/material_catalog.dart';
import 'package:zamer_app/services/runtime_material_pack_v4.dart';

void main() {
  test('Runtime v4 catalog exposes nine renderable production materials', () {
    expect(GeneratedMaterialIds.runtimeV4, hasLength(9));
    expect(MaterialCatalog.runtimeV4, hasLength(9));

    for (final preset in MaterialCatalog.runtimeV4) {
      expect(
        GeneratedMaterialIds.runtimeV4,
        contains(preset.id),
        reason: preset.name,
      );
      final pbr = GeneratedPbrFinishCatalog.byId(preset.id);
      expect(pbr, isNotNull, reason: preset.name);
      expect(File(preset.textureAsset!).existsSync(), isTrue, reason: preset.name);
      expect(File(pbr!.normalAsset).existsSync(), isTrue, reason: preset.name);
      expect(
        File(pbr.metallicRoughnessAsset).existsSync(),
        isTrue,
        reason: preset.name,
      );
    }
  });

  test('Runtime v4 laminate collections bundle compact 16-variant atlases', () {
    for (final material in RuntimeMaterialPackV4.laminate) {
      expect(material.plankCount, 16, reason: material.id);
      for (final mapName in RuntimeMaterialPackV4.mapNames) {
        expect(
          File(material.plankAtlasMapAsset(mapName)).existsSync(),
          isTrue,
          reason: '${material.id} atlas $mapName',
        );
      }
      expect(material.plankAtlasUv(1).u0, 0);
      expect(material.plankAtlasUv(16).u1, 1);
    }
  });

  test('Runtime v4 APK contract bundles only renderer-consumed channels', () {
    expect(
      RuntimeMaterialPackV4.mapNames,
      const <String>[
        'basecolor.webp',
        'normal.png',
        'metallic_roughness.png',
      ],
    );
    expect(RuntimeMaterialPackV4.mapNames, isNot(contains('height.png')));
    expect(RuntimeMaterialPackV4.mapNames, isNot(contains('ao.png')));
  });
}
