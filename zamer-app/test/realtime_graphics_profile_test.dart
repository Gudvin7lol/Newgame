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
    expect(
      screen.contains('_ThreeDMasterHeader(graphicsMode: _graphicsMode)'),
      isTrue,
    );
    expect(screen.contains('graphicsMode.label'), isTrue);
    expect(
      screen.contains(
        "if (!_walkMode)\n          const Positioned(\n            left: ZamerSpace.md,\n            right: ZamerSpace.md,\n            top: ZamerSpace.sm,\n            child: SafeArea(\n              bottom: false,\n              child: _ThreeDMasterHeader(graphicsMode: _graphicsMode)",
      ),
      isFalse,
      reason: 'Runtime graphics mode cannot be nested under const Positioned.',
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
      viewport.contains('if (!widget.performanceMode)'),
      isTrue,
      reason: 'Performance mode should skip dynamic point lights.',
    );
  });
}
