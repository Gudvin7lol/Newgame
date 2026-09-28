import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('lighting catalog contains ceiling, wall and floor fixtures', () {
    final lights = ObjectCatalog.items
        .where((item) => item.type == PlanObjectType.lighting)
        .toList(growable: false);

    expect(lights.length, greaterThanOrEqualTo(10));
    expect(lights.any((item) => item.mount == CatalogMount.ceiling), isTrue);
    expect(lights.any((item) => item.mount == CatalogMount.wall), isTrue);
    expect(lights.any((item) => item.mount == CatalogMount.floor), isTrue);

    for (final item in lights) {
      final model = ZamerModelAssetCatalog.byId(item.id);
      expect(model, isNotNull, reason: 'Нет GLB для ${item.id}');
      expect(File(model!.assetPath).existsSync(), isTrue);
    }
  });

  test('lighting plan objects survive project serialization', () {
    final object = PlanObject(
      id: 'light-1',
      type: PlanObjectType.lighting,
      xMm: 1500,
      yMm: 1200,
      widthMm: 900,
      depthMm: 900,
      heightMm: 180,
      elevationMm: 2520,
      catalogId: 'chandelier-ring',
    );

    final restored = PlanObject.fromJson(object.toJson());
    expect(restored.type, PlanObjectType.lighting);
    expect(restored.catalogId, 'chandelier-ring');
    expect(restored.elevationMm, 2520);
  });
}
