import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window glass uses the translucent GPU pass', () {
    final viewport = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(viewport.contains("name: 'window-glass'"), isTrue);
    expect(
      viewport.contains('..alphaMode = AlphaMode.blend'),
      isTrue,
      reason:
          'Window glass must use flutter_scene alpha blending instead of relying on color alpha alone.',
    );
    expect(
      viewport.contains('vm.Vector4(0.72, 0.88, 0.96, 0.28)'),
      isTrue,
      reason: 'Glass should keep a visibly transparent base alpha.',
    );
  });
}
