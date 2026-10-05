import 'dart:math' as math;

/// Texture-space transform for a wall fragment.
///
/// Wall geometry is split around doors and windows. Every fragment must keep
/// using coordinates from the original wall, otherwise the material restarts
/// above an opening and a visible seam appears.
class ZamerWallTextureTransform {
  const ZamerWallTextureTransform({
    required this.repeatU,
    required this.repeatV,
    required this.offsetU,
    required this.offsetV,
  });

  final double repeatU;
  final double repeatV;
  final double offsetU;
  final double offsetV;
}

ZamerWallTextureTransform zamerWallTextureTransform({
  required double textureStartMm,
  required double bottomMm,
  required double lengthMm,
  required double heightMm,
  required double realWorldTileMm,
}) {
  final tileMm = realWorldTileMm.isFinite
      ? math.max(50.0, realWorldTileMm.abs())
      : 1000.0;
  final start = textureStartMm.isFinite ? textureStartMm : 0.0;
  final bottom = bottomMm.isFinite ? bottomMm : 0.0;
  final length = lengthMm.isFinite ? math.max(0.0, lengthMm) : 0.0;
  final height = heightMm.isFinite ? math.max(0.0, heightMm) : 0.0;

  return ZamerWallTextureTransform(
    repeatU: math.max(0.001, length / tileMm),
    repeatV: math.max(0.001, height / tileMm),
    offsetU: start / tileMm,
    offsetV: bottom / tileMm,
  );
}
