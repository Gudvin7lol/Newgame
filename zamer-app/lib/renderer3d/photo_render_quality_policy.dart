class ZamerPhotoRenderQualityPolicy {
  const ZamerPhotoRenderQualityPolicy._();

  /// Final Photo Render must not inherit realtime Performance shortcuts.
  static bool useLocalLights({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality || !performanceMode;

  static int glowSegments({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality ? 16 : (performanceMode ? 10 : 16);

  static int glowRings({
    required bool photoQuality,
    required bool performanceMode,
  }) => photoQuality ? 10 : (performanceMode ? 6 : 10);
}
