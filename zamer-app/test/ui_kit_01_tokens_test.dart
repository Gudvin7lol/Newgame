import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';

void main() {
  group('MASTER CONCEPT production tokens', () {
    test('uses the approved graphite and warm sand palette', () {
      expect(ZamerColors.navy.toARGB32(), 0xFF0B0F12);
      expect(ZamerColors.graphite.toARGB32(), 0xFF11171B);
      expect(ZamerColors.darkGray.toARGB32(), 0xFF171D21);
      expect(ZamerColors.beige.toARGB32(), 0xFFFDD2A3);
      expect(ZamerColors.cream.toARGB32(), 0xFFFFE0B8);
      expect(ZamerColors.success.toARGB32(), 0xFF69D79B);
      expect(ZamerColors.warning.toARGB32(), 0xFFFFA629);
      expect(ZamerColors.danger.toARGB32(), 0xFFFF5C5C);
      expect(ZamerColors.info.toARGB32(), 0xFF6EA8FF);
    });

    test('keeps the approved reference phone dimensions', () {
      expect(ZamerSize.referenceWidth, 390);
      expect(ZamerSize.referenceHeight, 844);
      expect(ZamerSize.contentWidth, 358);
      expect(ZamerSize.topBar, 56);
      expect(ZamerSize.input, 48);
      expect(ZamerSize.button, 52);
      expect(ZamerSize.bottomNavigation, 72);
      expect(ZamerSize.cardSmall, 80);
      expect(ZamerSize.cardMedium, 120);
      expect(ZamerSize.minTouch, 44);
    });

    test('uses only the approved spacing and radius scales', () {
      expect(
        [
          ZamerSpace.xxs,
          ZamerSpace.xs,
          ZamerSpace.sm,
          ZamerSpace.md,
          ZamerSpace.lg,
          ZamerSpace.xl,
          ZamerSpace.xxl,
          ZamerSpace.xxxl,
          ZamerSpace.jumbo,
        ],
        [4, 8, 12, 16, 20, 24, 32, 40, 48],
      );
      expect(
        [
          ZamerRadius.xs,
          ZamerRadius.sm,
          ZamerRadius.md,
          ZamerRadius.lg,
          ZamerRadius.xl,
          ZamerRadius.xxl,
        ],
        [4, 8, 10, 12, 16, 20],
      );
    });
  });
}
