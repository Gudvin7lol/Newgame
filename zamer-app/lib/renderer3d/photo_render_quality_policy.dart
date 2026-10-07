class ZamerPhotoRenderQualityPolicy {
  const ZamerPhotoRenderQualityPolicy._();

  /// Final Photo Render must not inherit realtime Performance shortcuts.
  static bool useLocalLights({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality || !performanceMode;

  /// Photo Render is exported at true 4K, so small emissive fixture helpers need
  /// more geometry than the realtime viewport or they become visibly faceted.
  static int glowSegments({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality ? 24 : (performanceMode ? 10 : 16);

  static int glowRings({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality ? 14 : (performanceMode ? 6 : 10);
}
