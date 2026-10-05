import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/wall_texture_transform_policy.dart';

void main() {
  group('zamerWallTextureTransform', () {
    test('keeps vertical texture phase above a door opening', () {
      final lintel = zamerWallTextureTransform(
        textureStartMm: 1200,
        bottomMm: 2100,
        lengthMm: 900,
        heightMm: 600,
        realWorldTileMm: 1000,
      );

      expect(lintel.offsetU, closeTo(1.2, 1e-9));
      expect(lintel.offsetV, closeTo(2.1, 1e-9));
      expect(lintel.repeatU, closeTo(.9, 1e-9));
      expect(lintel.repeatV, closeTo(.6, 1e-9));
    });

    test('adjacent fragments use the same wall-space phase', () {
      final left = zamerWallTextureTransform(
        textureStartMm: 0,
        bottomMm: 0,
        lengthMm: 1200,
        heightMm: 2700,
        realWorldTileMm: 500,
      );
      final lintel = zamerWallTextureTransform(
        textureStartMm: 1200,
        bottomMm: 2100,
        lengthMm: 900,
        heightMm: 600,
        realWorldTileMm: 500,
      );

      expect(left.offsetU + left.repeatU, closeTo(lintel.offsetU, 1e-9));
      expect(lintel.offsetV, closeTo(4.2, 1e-9));
    });

    test('sanitizes corrupt dimensions without producing NaN', () {
      final transform = zamerWallTextureTransform(
        textureStartMm: double.nan,
        bottomMm: double.infinity,
        lengthMm: double.negativeInfinity,
        heightMm: -20,
        realWorldTileMm: double.nan,
      );

      expect(transform.offsetU, 0);
      expect(transform.offsetV, 0);
      expect(transform.repeatU, .001);
      expect(transform.repeatV, .001);
    });
  });
}
