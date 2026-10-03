import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';

void main() {
  group('Master UI production tokens', () {
    test('uses the approved warm color palette', () {
      expect(ZamerColors.background.toARGB32(), 0xFF0F1419);
      expect(ZamerColors.surface.toARGB32(), 0xFF1A222B);
      expect(ZamerColors.card.toARGB32(), 0xFF202A35);
      expect(ZamerColors.accent.toARGB32(), 0xFFE9C48F);
      expect(ZamerColors.success.toARGB32(), 0xFF22C55E);
      expect(ZamerColors.warning.toARGB32(), 0xFFF59E0B);
      expect(ZamerColors.danger.toARGB32(), 0xFFEF4444);
      expect(ZamerColors.info.toARGB32(), 0xFF3B82F6);
    });

    test('keeps the approved mobile dimensions', () {
      expect(ZamerSize.referenceWidth, 375);
      expect(ZamerSize.referenceHeight, 812);
      expect(ZamerSize.contentWidth, 343);
      expect(ZamerSize.topBar, 56);
      expect(ZamerSize.input, 48);
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

    test('uses the approved master typography scale', () {
      expect(ZamerTypography.h1.fontSize, 28);
      expect(ZamerTypography.h1.fontWeight, isNotNull);
      expect(ZamerTypography.h2.fontSize, 20);
      expect(ZamerTypography.h3.fontSize, 16);
      expect(ZamerTypography.body.fontSize, 14);
      expect(ZamerTypography.caption.fontSize, 12);
    });
  });
}
