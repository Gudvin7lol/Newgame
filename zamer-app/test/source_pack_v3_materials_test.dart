import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/generated_pbr_finish_catalog.dart';
import 'package:zamer_app/services/material_catalog.dart';
import 'package:zamer_app/services/source_pack_v3_material_ids.dart';

void main() {
  test('source pack v3 exposes all nine production material families', () {
    expect(MaterialCatalog.sourcePackV3, hasLength(9));
    expect(
      MaterialCatalog.sourcePackV3.map((material) => material.id).toSet(),
      SourcePackV3MaterialIds.all,
    );
  });

  test('source pack v3 keeps three floors, tiles and walls', () {
    final categories = <String, int>{};
    for (final material in MaterialCatalog.sourcePackV3) {
      categories.update(
        material.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    expect(categories['Пол'], 3);
    expect(categories['Плитка'], 3);
    expect(categories['Стены'], 3);
  });

  test('every source pack v3 finish resolves to validated production PBR', () {
    for (final material in MaterialCatalog.sourcePackV3) {
      expect(material.textureAsset, isNotNull, reason: material.name);
      final pbr = GeneratedPbrFinishCatalog.byId(material.id);
      expect(pbr, isNotNull, reason: '${material.name} must have runtime PBR');
      expect(pbr!.realWorldTileMm, greaterThan(0));
      expect(pbr.normalScale, greaterThan(0));
    }
  });

  test('laminate source pack materials stay procedural', () {
    final laminates = MaterialCatalog.sourcePackV3
        .where((material) => material.category == 'Пол')
        .toList(growable: false);
    expect(laminates, hasLength(3));
    for (final material in laminates) {
      expect(material.pattern, 'wood');
    }
  });

  test('source pack display names match the supplied references', () {
    final names = MaterialCatalog.sourcePackV3
        .map((material) => material.name)
        .toSet();
    for (final fragment in <String>[
      'Светлый дуб',
      'Тёплый орех',
      'Дымчатый дуб',
      'Бетон светлый',
      'Мрамор светлый',
      'Терраццо светлый',
      'Красный кирпич',
      'Гипсовая штукатурка',
      'Матовая краска',
    ]) {
      expect(names.any((name) => name.contains(fragment)), isTrue);
    }
  });
}
