import 'dart:math' as math;

/// Renderer-only dimensions for doors and windows.
///
/// Measured opening data remains in millimetres. This policy converts it once
/// to metres and keeps frame/casing/leaf proportions consistent in every GPU
/// scene instead of scattering visual magic numbers through the viewport.
class ZamerOpeningRenderMetrics {
  const ZamerOpeningRenderMetrics({
    required this.widthM,
    required this.heightM,
    required this.frameDepthM,
    required this.frameBarM,
    required this.casingWidthM,
    required this.casingDepthM,
    required this.sillBoardDepthM,
    required this.sillBoardThicknessM,
    required this.mullionWidthM,
    required this.leafWidthM,
    required this.leafHeightM,
    required this.leafThicknessM,
  });

  final double widthM;
  final double heightM;
  final double frameDepthM;
  final double frameBarM;
  final double casingWidthM;
  final double casingDepthM;
  final double sillBoardDepthM;
  final double sillBoardThicknessM;
  final double mullionWidthM;
  final double leafWidthM;
  final double leafHeightM;
  final double leafThicknessM;

  factory ZamerOpeningRenderMetrics.fromMillimetres({
    required double widthMm,
    required double heightMm,
    required double wallThicknessMm,
  }) {
    final widthM = math.max(0.20, widthMm / 1000);
    final heightM = math.max(0.20, heightMm / 1000);
    final safeWallM = math.max(0.06, wallThicknessMm / 1000);
    final frameBarM = (math.min(widthM, heightM) * 0.055)
        .clamp(0.035, 0.055)
        .toDouble();
    final frameDepthM = math.max(0.080, safeWallM + 0.018);
    final casingWidthM = (frameBarM * 1.45).clamp(0.055, 0.080).toDouble();

    return ZamerOpeningRenderMetrics(
      widthM: widthM,
      heightM: heightM,
      frameDepthM: frameDepthM,
      frameBarM: frameBarM,
      casingWidthM: casingWidthM,
      casingDepthM: 0.014,
      sillBoardDepthM: math.max(0.16, safeWallM + 0.075),
      sillBoardThicknessM: 0.028,
      mullionWidthM: (frameBarM * 0.70).clamp(0.026, 0.038).toDouble(),
      leafWidthM: math.max(0.12, widthM - frameBarM * 1.55),
      leafHeightM: math.max(0.18, heightM - frameBarM),
      leafThicknessM: 0.042,
    );
  }
}
