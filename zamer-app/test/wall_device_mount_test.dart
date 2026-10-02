import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/wall_device_mount.dart';

void main() {
  test('wall light clears both structural wall and finish stack', () {
    const wallThicknessMm = 100.0;
    const depthM = 0.075;
    final offset = zamerWallDeviceCenterOffsetMm(
      wallThicknessMm: wallThicknessMm,
      deviceDepthM: depthM,
    );

    expect(offset, closeTo(93.5, 0.0001));
    final innerFaceFromWallCenter = offset - depthM * 500;
    expect(innerFaceFromWallCenter, closeTo(56.0, 0.0001));
    expect(innerFaceFromWallCenter, greaterThan(wallThicknessMm / 2 + 4.5));
  });

  test('socket and panel use the same finish-safe surface-mount rule', () {
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: 100, deviceDepthM: 0.018),
      closeTo(65.0, 0.0001),
    );
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: 100, deviceDepthM: 0.055),
      closeTo(83.5, 0.0001),
    );
  });

  test('default clearance stays beyond the thickest rendered finish layer', () {
    const structuralSurfaceMm = 50.0;
    const renderedTileOuterSurfaceMm = structuralSurfaceMm + 4.5;
    final offset = zamerWallDeviceCenterOffsetMm(
      wallThicknessMm: 100,
      deviceDepthM: 0.018,
    );
    final deviceBackFaceMm = offset - 0.018 * 500;
    expect(deviceBackFaceMm, greaterThan(renderedTileOuterSurfaceMm));
  });

  test('invalid negative dimensions cannot pull a device through the wall', () {
    expect(
      zamerWallDeviceCenterOffsetMm(wallThicknessMm: -20, deviceDepthM: -0.1),
      6.0,
    );
  });
}
