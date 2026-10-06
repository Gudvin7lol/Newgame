import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPU renderer loads only textures used by the active scene', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('_ensureFinishTexturesForGeometry('));
    expect(source, contains('for (final surface in geometry.floors)'));
    expect(source, contains('for (final wall in geometry.walls)'));
    expect(source, contains('active.addAll(candidates);'));
    expect(
      source,
      contains('_finishTextures.removeWhere('),
      reason: 'Inactive material textures must not accumulate across edits.',
    );
    expect(
      source,
      isNot(contains('for (final preset in MaterialCatalog.presets)')),
      reason: 'Runtime v4 must not eagerly upload every 2K material to the GPU.',
    );
  });

  test('fallback textures remain optional and separate from the active cache', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('Future<void> _loadFallbackTextures()'));
    expect(source, contains("assets/textures/concrete_soft.png"));
    expect(source, contains("assets/textures/plaster_warm.png"));
  });
}
