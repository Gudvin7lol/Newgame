import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/opening_render_policy.dart';

void main() {
  test('door metrics preserve measured opening and wall depth', () {
    final metrics = ZamerOpeningRenderMetrics.fromMillimetres(
      widthMm: 900,
      heightMm: 2100,
      wallThicknessMm: 120,
    );

    expect(metrics.widthM, closeTo(0.9, 1e-9));
    expect(metrics.heightM, closeTo(2.1, 1e-9));
    expect(metrics.frameDepthM, greaterThan(0.12));
    expect(metrics.leafWidthM, lessThan(metrics.widthM));
    expect(metrics.leafHeightM, lessThan(metrics.heightM));
  });

  test('window sill projects beyond the wall instead of sitting flush', () {
    final metrics = ZamerOpeningRenderMetrics.fromMillimetres(
      widthMm: 1400,
      heightMm: 1400,
      wallThicknessMm: 180,
    );

    expect(metrics.sillBoardDepthM, greaterThan(0.18));
    expect(metrics.sillBoardThicknessM, greaterThan(0.02));
    expect(metrics.casingDepthM, greaterThan(0.01));
  });

  test('tiny legacy openings keep safe visible frame dimensions', () {
    final metrics = ZamerOpeningRenderMetrics.fromMillimetres(
      widthMm: 80,
      heightMm: 120,
      wallThicknessMm: 20,
    );

    expect(metrics.widthM, greaterThanOrEqualTo(0.20));
    expect(metrics.heightM, greaterThanOrEqualTo(0.20));
    expect(metrics.frameBarM, inInclusiveRange(0.035, 0.055));
    expect(metrics.frameDepthM, greaterThanOrEqualTo(0.080));
  });
}
