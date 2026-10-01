import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/photo_render_quality_policy.dart';

void main() {
  group('ZamerPhotoRenderQualityPolicy', () {
    test('photo quality keeps local lights even in performance mode', () {
      expect(
        ZamerPhotoRenderQualityPolicy.useLocalLights(
          photoQuality: true,
          performanceMode: true,
        ),
        isTrue,
      );
      expect(
        ZamerPhotoRenderQualityPolicy.glowSegments(
          photoQuality: true,
          performanceMode: true,
        ),
        16,
      );
      expect(
        ZamerPhotoRenderQualityPolicy.glowRings(
          photoQuality: true,
          performanceMode: true,
        ),
        10,
      );
    });

    test('interactive performance still uses lightweight fixture glow', () {
      expect(
        ZamerPhotoRenderQualityPolicy.useLocalLights(
          photoQuality: false,
          performanceMode: true,
        ),
        isFalse,
      );
      expect(
        ZamerPhotoRenderQualityPolicy.glowSegments(
          photoQuality: false,
          performanceMode: true,
        ),
        10,
      );
      expect(
        ZamerPhotoRenderQualityPolicy.glowRings(
          photoQuality: false,
          performanceMode: true,
        ),
        6,
      );
    });

    test('interactive quality keeps full local lighting', () {
      expect(
        ZamerPhotoRenderQualityPolicy.useLocalLights(
          photoQuality: false,
          performanceMode: false,
        ),
        isTrue,
      );
    });
  });
}
