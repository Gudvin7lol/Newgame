import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3D graphics selector drives the live GPU viewport', () {
    final screen = File('lib/screens/floor_3d_screen.dart').readAsStringSync();
    final viewport = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(
      screen.contains(
        'performanceMode: _graphicsMode == ZGraphicsMode.performance',
      ),
      isTrue,
    );
    expect(screen.contains('ZGraphicsModeSelector('), isTrue);
    expect(screen.contains('value: _graphicsMode'), isTrue);
    expect(screen.contains('onChanged: _selectGraphicsMode'), isTrue);

    expect(
      screen.contains('ZMasterPageHeader('),
      isTrue,
      reason: '3D must use the shared Master UI header.',
    );
    expect(screen.contains("title: '3D'"), isTrue);
    expect(screen.contains(r'${_graphicsMode.label}'), isTrue);
    expect(
      screen.contains('_ThreeDMasterHeader'),
      isFalse,
      reason: 'The old page-local 3D header must not return.',
    );

    expect(viewport.contains('final bool performanceMode;'), isTrue);
    expect(
      viewport.contains('oldWidget.performanceMode != widget.performanceMode'),
      isTrue,
    );
    expect(viewport.contains('castsShadow: !performance'), isTrue);
    expect(viewport.contains('ambientOcclusionEnabled: !performance'), isTrue);
    expect(
      viewport.contains('performanceMode: widget.performanceMode'),
      isTrue,
    );
    expect(
      viewport.contains('ZamerPhotoRenderQualityPolicy.useLocalLights('),
      isTrue,
      reason:
          'Realtime point lights must stay behind the shared Performance/Photo quality policy.',
    );
  });
}
