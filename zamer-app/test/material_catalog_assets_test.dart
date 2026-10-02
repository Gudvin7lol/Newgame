import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every material texture declared by the catalog is bundled and readable', () async {
    final textured = MaterialCatalog.presets.where(
      (preset) => preset.textureAsset != null,
    );

    expect(textured, isNotEmpty);

    for (final preset in textured) {
      final asset = preset.textureAsset!;
      final data = await rootBundle.load(asset);
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: '${preset.id} points to an empty texture: $asset',
      );
    }
  });

  test('material ids and texture bindings are unambiguous', () {
    final ids = <String>{};
    final bindings = <String, String>{};

    for (final preset in MaterialCatalog.presets) {
      expect(ids.add(preset.id), isTrue, reason: 'Duplicate material id: ${preset.id}');
      final asset = preset.textureAsset;
      if (asset != null) {
        expect(asset, startsWith('assets/textures/'));
        bindings[preset.id] = asset;
      }
    }

    expect(bindings, isNotEmpty);
  });
}
