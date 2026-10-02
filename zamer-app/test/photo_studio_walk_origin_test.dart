import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Walk mode forwards its physical camera origin into Photo Studio', () {
    final floor3d = File('lib/screens/floor_3d_screen.dart').readAsStringSync();
    final photo = File('lib/screens/photo_studio_screen.dart').readAsStringSync();
    final gpu = File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    expect(
      floor3d.contains('cameraOriginXMm: _walkMode ? _walkX : null'),
      isTrue,
      reason: 'Photo opened from Walk must inherit the current X position.',
    );
    expect(
      floor3d.contains('cameraOriginYMm: _walkMode ? _walkY : null'),
      isTrue,
      reason: 'Photo opened from Walk must inherit the current Y position.',
    );
    expect(photo.contains('final double? cameraOriginXMm;'), isTrue);
    expect(photo.contains('final double? cameraOriginYMm;'), isTrue);
    expect(
      photo.contains('photoCameraOriginXMm: widget.cameraOriginXMm'),
      isTrue,
    );
    expect(
      photo.contains('photoCameraOriginYMm: widget.cameraOriginYMm'),
      isTrue,
    );
    expect(
      photo.contains('final minTilt = _usesWalkOrigin ? -0.7 : 0.15'),
      isTrue,
      reason: 'First-person Photo must keep Walk pitch limits.',
    );
    expect(gpu.contains('final double? photoCameraOriginXMm;'), isTrue);
    expect(gpu.contains('final double? photoCameraOriginYMm;'), isTrue);
    expect(
      gpu.contains('widget.photoPreview &&\n        photoOriginXMm != null &&\n        photoOriginYMm != null'),
      isTrue,
      reason: 'Only Photo preview/export should use the explicit Walk origin.',
    );
    expect(
      gpu.contains('_mx(photoOriginXMm, bounds)'),
      isTrue,
      reason: 'Walk X must be converted from plan millimetres to scene metres.',
    );
    expect(
      gpu.contains('_mz(photoOriginYMm, bounds)'),
      isTrue,
      reason: 'Walk Y must be converted from plan millimetres to scene metres.',
    );
    expect(
      gpu.contains('final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble()'),
      isTrue,
      reason: 'Photo lenses must still control FOV from a Walk camera origin.',
    );
  });
}
