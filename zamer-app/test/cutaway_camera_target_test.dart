import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3D cutaway follows panned camera target instead of world origin', () {
    final source =
        File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    expect(source, contains('widget.tilt >= 1.32'));
    expect(source, contains('final target2 = vm.Vector2('));
    expect(source, contains('-widget.pan.dx * panScale'));
    expect(source, contains('-widget.pan.dy * panScale'));
    expect(source, contains('final cameraFromTarget = camera2 - target2;'));
    expect(source, contains('final relative = wallPos - target2;'));
    expect(source, contains('final inOcclusionBand ='));
    expect(source, contains('final inViewCorridor ='));
    expect(
      source,
      contains('towardCamera >= 0.30 && inOcclusionBand && inViewCorridor'),
    );

    expect(source, isNot(contains('final cameraDir = camera2.normalized();')));
    expect(source, isNot(contains('final radial = wallPos.length;')));
  });
}
