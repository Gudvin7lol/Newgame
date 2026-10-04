import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/camera_clip_policy.dart';

void main() {
  test('walk mode keeps a closer near plane than orbit mode', () {
    expect(
      ZamerCameraClipPolicy.near(walkMode: true),
      lessThan(ZamerCameraClipPolicy.near(walkMode: false)),
    );
  });

  test('near planes balance close inspection with depth precision', () {
    expect(ZamerCameraClipPolicy.walkNearM, lessThanOrEqualTo(0.018));
    expect(ZamerCameraClipPolicy.overviewNearM, lessThanOrEqualTo(0.030));
    expect(
      ZamerCameraClipPolicy.walkFarM / ZamerCameraClipPolicy.walkNearM,
      lessThan(10000),
    );
    expect(120 / ZamerCameraClipPolicy.overviewNearM, lessThan(5000));
  });
}
