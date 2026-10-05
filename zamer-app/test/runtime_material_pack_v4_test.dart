import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/runtime_material_pack_v4.dart';

void main() {
  test('Runtime v4 exposes all nine production materials', () {
    expect(RuntimeMaterialPackV4.materials.length, 9);
    expect(RuntimeMaterialPackV4.walls.length, 3);
    expect(RuntimeMaterialPackV4.tiles.length, 3);
    expect(RuntimeMaterialPackV4.laminate.length, 3);
    expect(RuntimeMaterialPackV4.normalConvention, 'OpenGL_Y+');
    expect(RuntimeMaterialPackV4.metallic, 0);
  });

  test('walls use 2K maps at one metre physical scale', () {
    for (final material in RuntimeMaterialPackV4.walls) {
      expect(material.widthPx, 2048, reason: material.id);
      expect(material.heightPx, 2048, reason: material.id);
      expect(material.physicalWidthMm, 1000, reason: material.id);
      expect(material.physicalHeightMm, 1000, reason: material.id);
      expect(material.mapAsset('basecolor.webp'), contains('runtime_v4/walls/'));
    }
  });

  test('tiles stay procedural with separate two millimetre grout', () {
    for (final material in RuntimeMaterialPackV4.tiles) {
      expect(material.isTile, isTrue, reason: material.id);
      expect(material.physicalWidthMm, 600, reason: material.id);
      expect(material.physicalHeightMm, 600, reason: material.id);
      expect(material.groutWidthMm, 2, reason: material.id);
      expect(material.randomUvOffset, isTrue, reason: material.id);
    }
  });

  test('laminate keeps sixteen independent 2K planks', () {
    for (final material in RuntimeMaterialPackV4.laminate) {
      expect(material.isPlankCollection, isTrue, reason: material.id);
      expect(material.widthPx, 2048, reason: material.id);
      expect(material.heightPx, 286, reason: material.id);
      expect(material.physicalWidthMm, 1380, reason: material.id);
      expect(material.physicalHeightMm, 193, reason: material.id);
      expect(material.plankCount, 16, reason: material.id);
      expect(material.bevelMm, 1, reason: material.id);
      expect(
        material.plankMapAsset(16, 'normal.png'),
        contains('/planks/16/normal.png'),
      );
    }
    expect(RuntimeMaterialPackV4.laminatePatterns, contains('herringbone_45'));
    expect(RuntimeMaterialPackV4.laminatePatterns, contains('chevron'));
  });
}
