import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPU scene rebuild stages replacement before touching active scene', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();
    final start = source.indexOf(
      'Future<void> _rebuildScene({bool photoQuality = false}) async',
    );
    final end = source.indexOf('Node? _buildFloorNode(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(
      body,
      contains('final keepCurrentScene = _ready && _loadError == null;'),
    );
    expect(body, contains('final nextNodes = <Node>[];'));
    expect(body, contains('final nextWallVisuals = <_WallVisual>[];'));
    expect(body, contains('final nextCeilingNodes = <Node>[];'));

    final modelLoad = body.indexOf('await _buildObjectNode(');
    final activeSceneClear = body.indexOf('scene.removeAll();');
    final geometrySwap = body.indexOf('_geometry = geometry;');
    expect(modelLoad, greaterThanOrEqualTo(0));
    expect(activeSceneClear, greaterThan(modelLoad));
    expect(geometrySwap, greaterThan(activeSceneClear));

    expect(
      body.substring(0, activeSceneClear),
      isNot(contains('_wallVisuals.clear();')),
    );
    expect(
      body.substring(0, activeSceneClear),
      isNot(contains('_ceilingNodes.clear();')),
    );
  });
}
