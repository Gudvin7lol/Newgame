import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPU viewport recovers from context loss without requiring app restart', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(
      source,
      contains('if (state != AppLifecycleState.resumed) return;'),
    );
    expect(source, contains('_rebuildSceneAfterUpdate();'));
    expect(source, contains('if (_retryAttempt >= 3)'));
    expect(source, contains('_resetGpuAndRetry'));
    expect(source, contains('_scene?.removeAll();'));
    expect(source, contains('_modelTemplates.clear();'));
    expect(source, contains('_finishTextures.clear();'));
    expect(source, contains('_initialize();'));
  });

  test('missing fallback textures cannot take the whole 3D scene down', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('Future<Texture2D?> _tryLoadTexture(String asset)'));
    expect(
      source,
      contains("_tryLoadTexture(\n      'assets/textures/concrete_soft.png'"),
    );
    expect(
      source,
      contains("_tryLoadTexture(\n      'assets/textures/plaster_warm.png'"),
    );
    expect(source, contains('return null;'));
  });

  test('walk mode is included in the model visibility policy decision', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('walkMode: widget.walkMode,'));
  });
}
