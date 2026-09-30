import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';

void main() {
  group('UI KIT 01 production tokens', () {
    test('uses the approved color palette', () {
      expect(ZamerColors.navy.toARGB32(), 0xFF0B1F3B);
      expect(ZamerColors.graphite.toARGB32(), 0xFF1A2A3A);
      expect(ZamerColors.darkGray.toARGB32(), 0xFF2C3B4A);
      expect(ZamerColors.beige.toARGB32(), 0xFFDBC3A5);
      expect(ZamerColors.cream.toARGB32(), 0xFFF3E9D7);
      expect(ZamerColors.success.toARGB32(), 0xFF2EA043);
      expect(ZamerColors.warning.toARGB32(), 0xFFFFB020);
      expect(ZamerColors.danger.toARGB32(), 0xFFFF4444);
      expect(ZamerColors.info.toARGB32(), 0xFF3B82F6);
    });

    test('keeps the approved mobile dimensions', () {
      expect(ZamerSize.referenceWidth, 375);
      expect(ZamerSize.referenceHeight, 812);
      expect(ZamerSize.contentWidth, 343);
      expect(ZamerSize.topBar, 56);
      expect(ZamerSize.input, 56);
      expect(ZamerSize.button, 56);
      expect(ZamerSize.bottomNavigation, 72);
      expect(ZamerSize.cardSmall, 80);
      expect(ZamerSize.cardMedium, 120);
      expect(ZamerSize.minTouch, 48);
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
        [4, 8, 12, 16, 20, 24],
      );
    });
  });
}
