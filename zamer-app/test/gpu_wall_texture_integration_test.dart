import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPU wall materials use continuous wall-space texture transform', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    expect(source, contains("import 'wall_texture_transform_policy.dart';"));
    expect(source, contains('final transform = zamerWallTextureTransform('));
    expect(source, contains('textureStartMm: wall.textureStartMm'));
    expect(source, contains('bottomMm: wall.bottomMm'));
    expect(source, contains('scale: vm.Vector2(transform.repeatU, transform.repeatV)'));
    expect(source, contains('offset: vm.Vector2(transform.offsetU, transform.offsetV)'));
    expect(source, contains('material.baseColorTextureTransform = transform'));
  });
}
