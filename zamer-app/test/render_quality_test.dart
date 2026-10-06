import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/render_quality.dart';

void main() {
  group('ZamerRenderQuality', () {
    test('realtime profiles stay realtime', () {
      expect(ZamerRenderQuality.performance.isRealtime, isTrue);
      expect(ZamerRenderQuality.quality.isRealtime, isTrue);
      expect(ZamerRenderQuality.photo4k.isRealtime, isFalse);
    });

    test('Photo 4K uses a native 3840x2160 target', () {
      expect(ZamerRenderQuality.photo4k.width, 3840);
      expect(ZamerRenderQuality.photo4k.height, 2160);
    });

    test('Quality is materially richer than Performance', () {
      expect(
        ZamerRenderQuality.quality.shadowMapResolution,
        greaterThan(ZamerRenderQuality.performance.shadowMapResolution),
      );
      expect(ZamerRenderQuality.performance.ambientOcclusionEnabled, isFalse);
      expect(ZamerRenderQuality.quality.ambientOcclusionEnabled, isTrue);
      expect(ZamerRenderQuality.performance.reflectionsEnabled, isFalse);
      expect(ZamerRenderQuality.quality.reflectionsEnabled, isTrue);
    });

    test('Photo keeps the maximum profile', () {
      expect(
        ZamerRenderQuality.photo4k.shadowMapResolution,
        greaterThanOrEqualTo(ZamerRenderQuality.quality.shadowMapResolution),
      );
      expect(
        ZamerRenderQuality.photo4k.reflectionsResolutionScale,
        greaterThan(ZamerRenderQuality.quality.reflectionsResolutionScale),
      );
    });
  });
}
