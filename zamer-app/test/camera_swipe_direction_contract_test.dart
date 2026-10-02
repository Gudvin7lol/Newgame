import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('horizontal swipe direction stays intuitive in 3D and Photo', () {
    final floor3d = File('lib/screens/floor_3d_screen.dart').readAsStringSync();
    final photo = File('lib/screens/photo_studio_screen.dart').readAsStringSync();

    expect(
      floor3d,
      contains('final angle = _rotation - lookDelta.dx * lookSensitivity;'),
      reason: 'Dragging left must rotate the 3D/Walk camera left.',
    );
    expect(
      photo,
      contains('final angle = _rotation - lookDelta.dx * .008;'),
      reason: 'Dragging left must rotate the Photo camera left.',
    );

    expect(
      floor3d,
      isNot(contains('final angle = _rotation + lookDelta.dx * lookSensitivity;')),
    );
    expect(
      photo,
      isNot(contains('final angle = _rotation + lookDelta.dx * .008;')),
    );
  });
}
