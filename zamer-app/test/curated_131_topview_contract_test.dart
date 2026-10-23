import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/imported_top_view_assets.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('all approved +131 top views are valid catalog models', () {
    final sprites = ImportedTopViewAssets.curated131Rects;
    expect(sprites.length, 29);
    for (final entry in sprites.entries) {
      final object = ObjectCatalog.byId(entry.key);
      expect(object.id, entry.key, reason: 'Unregistered: ${entry.key}');
      expect(object.widthMm, greaterThan(0));
      expect(object.depthMm, greaterThan(0));
      expect(entry.value.left, greaterThanOrEqualTo(0));
      expect(entry.value.top, greaterThanOrEqualTo(0));
      expect(entry.value.right, lessThanOrEqualTo(1280));
      expect(entry.value.bottom, lessThanOrEqualTo(451));
      expect(entry.value.width, greaterThan(0));
      expect(entry.value.height, greaterThan(0));
    }
  });

  test('approved categories are present without adding unapproved chairs', () {
    const categories = [
      'Сантехника', 'Мягкая мебель', 'Кровати', 'Ковры', 'Столы и стулья',
    ];
    for (final group in categories) {
      expect(
        ObjectCatalog.inGroup(group).any(
          (item) => ImportedTopViewAssets.curated131Rects.containsKey(item.id),
        ),
        isTrue,
        reason: 'No top view in $group',
      );
    }
    expect(ImportedTopViewAssets.curated131Rects.containsKey('chair'), isFalse);
    expect(ImportedTopViewAssets.curated131Rects.containsKey('nightstand'), isFalse);
  });

  test('catalog recognizes the curated asset registry', () {
    final catalog = File('lib/screens/planning_objects_screen.dart').readAsStringSync();
    expect(catalog.contains('ImportedTopViewAssets.curated131Rects.containsKey(item.id)'),
        isTrue);
  });
}
