from pathlib import Path

VIEWPORT = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
TEST = Path('zamer-app/test/staged_scene_rebuild_test.dart')

text = VIEWPORT.read_text(encoding='utf-8')
start_marker = '  Future<void> _rebuildScene({bool photoQuality = false}) async {'
end_marker = '\n  Node? _buildFloorNode('
start = text.find(start_marker)
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('rebuild scene anchors not found')

replacement = r'''  Future<void> _rebuildScene({bool photoQuality = false}) async {
    final generation = ++_buildGeneration;
    final keepCurrentScene = _ready && _loadError == null;
    if (mounted && !keepCurrentScene) {
      setState(() {
        _ready = false;
        _loadError = null;
      });
    }

    final scene = _scene;
    if (scene == null) {
      if (mounted) {
        setState(() {
          _loadError = StateError('GPU-контекст недоступен');
          _ready = false;
        });
      }
      return;
    }

    final geometry = ZamerSceneGeometry.fromFloor(widget.floor);
    final nextNodes = <Node>[];
    final nextWallVisuals = <_WallVisual>[];
    final nextCeilingNodes = <Node>[];
    final floorMaterialCache = <String, PhysicallyBasedMaterial>{};
    final activeModelPaths = <String>{};

    for (final surface in geometry.floors) {
      final node = _buildFloorNode(
        surface,
        geometry.bounds,
        floorMaterialCache,
      );
      if (node != null) nextNodes.add(node);
      final ceiling = _buildCeilingNode(surface, geometry.bounds);
      if (ceiling != null) {
        nextCeilingNodes.add(ceiling);
        nextNodes.add(ceiling);
      }
    }

    for (final wall in geometry.walls) {
      final node = _buildWallNode(wall, geometry.bounds);
      nextNodes.add(node);
      nextWallVisuals.add(
        _WallVisual(
          node: node,
          x: _mx(wall.centerXMm, geometry.bounds),
          z: _mz(wall.centerYMm, geometry.bounds),
        ),
      );
    }

    for (final opening in geometry.openings) {
      nextNodes.add(_buildOpeningNode(opening, geometry.bounds));
    }
    for (final point in geometry.electrical) {
      nextNodes.add(_buildElectricalNode(point, geometry.bounds));
    }

    for (final object in geometry.objects) {
      if (generation != _buildGeneration) return;
      final node = await _buildObjectNode(
        object,
        geometry.bounds,
        visibleObjectCount: geometry.objects.length,
        photoQuality: photoQuality,
        activeModelPaths: activeModelPaths,
      );
      if (generation != _buildGeneration) return;
      nextNodes.add(node);
    }

    if (!mounted || generation != _buildGeneration) return;

    // Keep the last valid frame visible while GLBs and materials are prepared.
    // Only touch the active Scene after the replacement graph is complete, so
    // editing a plan never produces an empty or half-populated 3D viewport.
    scene.removeAll();
    for (final node in nextNodes) {
      scene.add(node);
    }
    _geometry = geometry;
    _wallVisuals
      ..clear()
      ..addAll(nextWallVisuals);
    _ceilingNodes
      ..clear()
      ..addAll(nextCeilingNodes);

    _modelTemplates.removeWhere((path, _) => !activeModelPaths.contains(path));
    setState(() {
      _loadError = null;
      _ready = true;
    });
  }
'''

text = text[:start] + replacement + text[end:]
VIEWPORT.write_text(text, encoding='utf-8')

TEST.parent.mkdir(parents=True, exist_ok=True)
TEST.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPU scene rebuild stages replacement before touching active scene', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void> _rebuildScene({bool photoQuality = false}) async',
    );
    final end = source.indexOf('Node? _buildFloorNode(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, contains('final keepCurrentScene = _ready && _loadError == null;'));
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
''', encoding='utf-8')

print('Staged GPU scene rebuild applied.')
