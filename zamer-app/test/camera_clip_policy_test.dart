import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/camera_clip_policy.dart';

void main() {
  test('walk mode keeps a closer near plane than overview', () {
    expect(ZamerCameraClipPolicy.walkNearM, closeTo(0.018, 0.000001));
    expect(ZamerCameraClipPolicy.overviewNearM, closeTo(0.030, 0.000001));
    expect(
      ZamerCameraClipPolicy.near(walkMode: true),
      lessThan(ZamerCameraClipPolicy.near(walkMode: false)),
    );
  });

  test('overview near plane stays close without sacrificing depth precision', () {
    const representativeFarM = 120.0;
    final ratio = representativeFarM / ZamerCameraClipPolicy.overviewNearM;

    expect(ZamerCameraClipPolicy.overviewNearM, lessThanOrEqualTo(0.030));
    expect(ratio, lessThan(5000));
  });

  test('walk clipping still preserves sane depth precision', () {
    final ratio =
        ZamerCameraClipPolicy.walkFarM / ZamerCameraClipPolicy.walkNearM;
    expect(ratio, lessThan(10000));
  });
}
