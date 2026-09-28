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
    }
  });
}
