import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/photo_export_policy.dart';

void main() {
  group('ZamerPhotoExportPolicy', () {
    test('final Photo Render requires a real GPU scene', () {
      expect(ZamerPhotoExportPolicy.requiresGpu(photoQuality: true), isTrue);
      expect(
        ZamerPhotoExportPolicy.mayUseCompatibilityFallback(photoQuality: true),
        isFalse,
      );
    });

    test('non-photo capture may still use compatibility fallback', () {
      expect(ZamerPhotoExportPolicy.requiresGpu(photoQuality: false), isFalse);
      expect(
        ZamerPhotoExportPolicy.mayUseCompatibilityFallback(photoQuality: false),
        isTrue,
      );
    });

    test('GPU unavailable error is explicit for the Photo Studio', () {
      expect(
        ZamerPhotoExportPolicy.gpuUnavailableMessage,
        contains('GPU-сцена не готова'),
      );
    });
  });
}
