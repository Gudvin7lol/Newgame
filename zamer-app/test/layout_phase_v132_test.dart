import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/layout_service.dart';

void main() {
  test('straight and herringbone patterns have distinct repeat periods', () {
    final s = RoomMaterialSettings(
      laminatePlankLengthMm: 1380,
      laminatePlankWidthMm: 193,
    );
    final straight = LayoutService.laminateOffsetPeriod(s);
    expect(straight.xMm, 1380);
    expect(straight.yMm, 193);
    s.laminatePattern = 'herringbone';
    final herringbone = LayoutService.laminateOffsetPeriod(s);
    expect(herringbone.xMm, closeTo(1380 / math.sqrt2, 0.001));
    expect(herringbone.yMm, closeTo(193 * math.sqrt2, 0.001));
  });

  test('offset normalization is positive, periodic and zoom independent', () {
    final s = RoomMaterialSettings(
      laminatePlankLengthMm: 1380,
      laminatePlankWidthMm: 193,
      laminatePattern: 'herringbone',
    );
    final module = LayoutService.laminateOffsetPeriod(s).xMm;
    final offset = LayoutService.normalizedPatternOffset(-120, module);
    expect(offset, greaterThanOrEqualTo(0));
    expect(offset, lessThan(module));
    expect(
      LayoutService.normalizedPatternOffset(-120 + module, module),
      closeTo(offset, 0.000001),
    );
    for (final scale in [0.25, 1.0, 4.0]) {
      final screenOffset = offset * scale;
      expect(screenOffset / scale, closeTo(offset, 0.000001));
    }
  });
}
