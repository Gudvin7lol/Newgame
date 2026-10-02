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
    expect(source, contains('swingSign * 32 * math.pi / 180'));
  });
}
