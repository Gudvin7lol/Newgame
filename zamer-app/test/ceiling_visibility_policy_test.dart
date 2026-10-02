import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/ceiling_visibility_policy.dart';

void main() {
  group('ZamerCeilingVisibilityPolicy', () {
    test('orbit overview keeps ceiling open for inspection', () {
      expect(
        ZamerCeilingVisibilityPolicy.visible(
          walkMode: false,
          photoPreview: false,
        ),
        isFalse,
      );
    });

    test('walk mode keeps the finished ceiling visible', () {
      expect(
        ZamerCeilingVisibilityPolicy.visible(
          walkMode: true,
          photoPreview: false,
        ),
        isTrue,
      );
    });

    test('Photo preview and export keep the finished ceiling visible', () {
      expect(
        ZamerCeilingVisibilityPolicy.visible(
          walkMode: false,
          photoPreview: true,
        ),
        isTrue,
      );
    });
  });
}
