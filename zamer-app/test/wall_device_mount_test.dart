import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/wall_device_mount.dart';

void main() {
  test('wall light depth stays completely outside a 100 mm wall', () {
    const wallThicknessMm = 100.0;
    const depthM = 0.075;
    final offset = zamerWallDeviceCenterOffsetMm(
      wallThicknessMm: wallThicknessMm,
      deviceDepthM: depthM,
    );

    expect(offset, closeTo(88.5, 0.0001));
    final innerFaceFromWallCenter = offset - depthM * 500;
    expect(innerFaceFromWallCenter, greaterThan(wallThicknessMm / 2));
    expect(innerFaceFromWallCenter, closeTo(51.0, 0.0001));
  });

  test('socket and panel use the same surface-mount rule', () {
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: 100, deviceDepthM: 0.018),
      closeTo(60.0, 0.0001),
    );
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: 100, deviceDepthM: 0.055),
      closeTo(78.5, 0.0001),
    );
  });

  test('invalid negative dimensions cannot pull a device through the wall', () {
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: -20, deviceDepthM: -0.1),
      1.0,
    );
  });
}
