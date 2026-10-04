import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('release gate: 3D keeps close camera planes and perspective cutaway', () {
    final clip = source('lib/renderer3d/camera_clip_policy.dart');
    final cutaway = source('lib/renderer3d/cutaway_geometry.dart');

    expect(clip.contains('walkNearM = 0.008'), isTrue);
    expect(clip.contains('overviewNearM = 0.012'), isTrue);
    expect(cutaway.contains('depthFraction'), isTrue);
    expect(cutaway.contains('perspectiveHalfWidth'), isTrue);
    expect(cutaway.contains('insidePerspectiveCorridor'), isTrue);
  });

  test('release gate: visible finish changes rebuild the GPU scene', () {
    final fingerprint = source('lib/renderer3d/scene_fingerprint.dart');

    for (final required in const [
      'm.floorTile',
      'm.wallTilePattern',
      'm.wallTileFromMm',
      'm.wallTileToMm',
      'point.wallOffsetMm',
    ]) {
      expect(
        fingerprint.contains(required),
        isTrue,
        reason: 'Missing 3D fingerprint input: $required',
      );
    }
  });

  test('release gate: live GPU rebuild retains last valid frame', () {
    final viewport = source('lib/renderer3d/zamer_gpu_viewport.dart');

    for (final required in const [
      'final keepCurrentScene = _ready && _loadError == null',
      'if (mounted && !keepCurrentScene)',
      '_scheduleLiveRebuildRetry()',
      'if (_ready && _scene != null)',
      'SceneView(scene, camera: camera, warmUp: true)',
    ]) {
      expect(
        viewport.contains(required),
        isTrue,
        reason: 'Missing stable live rebuild contract: $required',
      );
    }
  });
}
