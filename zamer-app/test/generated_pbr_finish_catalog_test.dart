import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/generated_material_ids.dart';
import 'package:zamer_app/services/generated_pbr_finish_catalog.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  test('all generated ZAMER finishes have complete PBR texture sets', () {
    expect(
      GeneratedPbrFinishCatalog.byMaterialId.length,
      GeneratedMaterialIds.all.length,
    );
    expect(
      GeneratedPbrFinishCatalog.byMaterialId.keys.toSet(),
      GeneratedMaterialIds.all,
    );

    for (final entry in GeneratedPbrFinishCatalog.byMaterialId.entries) {
      final finish = entry.value;
      expect(
        File(finish.baseColorAsset).existsSync(),
        isTrue,
        reason: 'Missing base color for ${entry.key}: ${finish.baseColorAsset}',
      );
      expect(
        File(finish.normalAsset).existsSync(),
        isTrue,
        reason: 'Missing normal map for ${entry.key}: ${finish.normalAsset}',
      );
      expect(
        File(finish.heightAsset).existsSync(),
        isTrue,
        reason: 'Missing height map for ${entry.key}: ${finish.heightAsset}',
      );
      expect(
        File(finish.metallicRoughnessAsset).existsSync(),
        isTrue,
        reason:
            'Missing metallic/roughness for ${entry.key}: ${finish.metallicRoughnessAsset}',
      );
      expect(finish.realWorldTileMm, greaterThan(0));
      expect(finish.normalScale, greaterThan(0));
    }
  });

  test('live GPU viewport consumes generated normal and roughness maps', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source.contains('GeneratedPbrFinishCatalog.byId'), isTrue);
    expect(source.contains('normalTexture = normal'), isTrue);
    expect(
      source.contains('metallicRoughnessTexture = metallicRoughness'),
      isTrue,
    );
    expect(source.contains('realWorldTileMm'), isTrue);
    expect(source.contains('normalTextureTransform = transform'), isTrue);
    expect(
      source.contains('metallicRoughnessTextureTransform = transform'),
      isTrue,
    );
  });

  test('legacy floor finishes inherit PBR channels in existing projects', () {
    final oak = GeneratedPbrFinishCatalog.byId('oak-natural');
    final walnut = GeneratedPbrFinishCatalog.byId('walnut');
    final marble = GeneratedPbrFinishCatalog.byId('tile-marble');

    expect(oak, isNotNull);
    expect(walnut, isNotNull);
    expect(marble, isNotNull);
    expect(oak!.normalAsset, contains('white_oak_normal'));
    expect(walnut!.normalAsset, contains('dark_oak_normal'));
    expect(marble!.metallicRoughnessAsset, contains('metallic_roughness'));
  });

  test('legacy wall finishes inherit suitable PBR surface detail', () {
    final paint = GeneratedPbrFinishCatalog.byId('paint-warm-white');
    final plaster = GeneratedPbrFinishCatalog.byId('plaster-sand');
    final concrete = GeneratedPbrFinishCatalog.byId('concrete-raw');
    final brick = GeneratedPbrFinishCatalog.byId('brick-red');

    expect(paint, isNotNull);
    expect(plaster, isNotNull);
    expect(concrete, isNotNull);
    expect(brick, isNotNull);
    expect(paint!.normalScale, lessThan(1));
    expect(plaster!.realWorldTileMm, 900);
    expect(concrete!.realWorldTileMm, 1000);
    expect(brick!.normalScale, greaterThan(4));
  });

  test('every textured catalog finish resolves to a PBR surface set', () {
    for (final preset in MaterialCatalog.presets.where(
      (preset) => preset.textureAsset != null,
    )) {
      expect(
        GeneratedPbrFinishCatalog.byId(preset.id),
        isNotNull,
        reason: '${preset.id} has a base texture but no Normal/Roughness set',
      );
    }
  });

  test('all legacy PBR aliases point to canonical generated finishes', () {
    for (final entry in GeneratedPbrFinishCatalog.legacyAliases.entries) {
      expect(
        GeneratedPbrFinishCatalog.byMaterialId.containsKey(entry.value),
        isTrue,
        reason: '${entry.key} points to missing canonical PBR id ${entry.value}',
      );
    }
  });

  test('unknown material stays outside generated PBR catalog', () {
    expect(GeneratedPbrFinishCatalog.byId('totally-unknown'), isNull);
  });
}
