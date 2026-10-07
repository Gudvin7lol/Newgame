class ZamerPbrUvTransformData {
  const ZamerPbrUvTransformData({
    required this.scaleX,
    required this.scaleY,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
}

/// Keeps normal/roughness detail at a stable real-world scale even when the
/// visible base texture is intentionally stretched to a plank or tile module.
///
/// Geometry UVs for floors are already expressed in repeats of the selected
/// plank/tile dimensions. PBR maps, however, describe a physical square sample
/// (for example 1200 x 1200 mm). Applying this transform converts those module
/// UVs back to physical-world UVs without changing the user's layout pattern.
abstract final class ZamerMaterialPbrUvPolicy {
  static ZamerPbrUvTransformData forFloor({
    required double geometryUvWidthMm,
    required double geometryUvHeightMm,
    required double realWorldTileMm,
  }) {
    final real = _safeRepeat(realWorldTileMm);
    return ZamerPbrUvTransformData(
      scaleX: _safeDimension(geometryUvWidthMm) / real,
      scaleY: _safeDimension(geometryUvHeightMm) / real,
    );
  }

  /// Wall primitive UVs run from 0..1 over the complete render piece, so the
  /// PBR channels need an explicit physical repeat count and phase. This is
  /// deliberately independent of the visible tile module transform.
  static ZamerPbrUvTransformData forWall({
    required double wallLengthMm,
    required double wallHeightMm,
    required double textureStartMm,
    required double bottomMm,
    required double realWorldTileMm,
  }) {
    final real = _safeRepeat(realWorldTileMm);
    return ZamerPbrUvTransformData(
      scaleX: _safeDimension(wallLengthMm) / real,
      scaleY: _safeDimension(wallHeightMm) / real,
      offsetX: textureStartMm.isFinite ? textureStartMm / real : 0,
      offsetY: bottomMm.isFinite ? bottomMm / real : 0,
    );
  }

  static double _safeRepeat(double value) =>
      value.isFinite && value >= 50 ? value : 1000;

  static double _safeDimension(double value) =>
      value.isFinite && value > 0 ? value : 1;
}
