import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3D door keeps swing semantics and detailed hardware', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('opening.doorSwing == DoorSwing.leftIn'));
    expect(source, contains("name: 'door-leaf-root'"));
    expect(source, contains('door-panel-upper-front'));
    expect(source, contains('door-panel-lower-front'));
    expect(source, contains('door-handle-front'));
    expect(source, contains('door-handle-back'));
    expect(source, contains('door-lever-front'));
    expect(source, contains('door-hinge-plate'));
    expect(source, contains('metallicFactor = 0.86'));
    expect(source, isNot(contains('..metallic = 0.86')));

    // +111 opens the preview wider so the leaf and passage are readable in 3D.
    expect(source, contains('swingSign * 42 * math.pi / 180'));
    expect(source, contains('ZamerOpeningRenderMetrics.fromMillimetres'));
    expect(source, contains('opening-casing-left-front'));
    expect(source, contains('opening-casing-right-back'));
    expect(source, contains('window-sill-board'));
  });
}
