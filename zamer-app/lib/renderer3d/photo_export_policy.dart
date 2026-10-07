class ZamerPhotoExportPolicy {
  const ZamerPhotoExportPolicy._();

  static const String gpuUnavailableMessage =
      'Photo Render недоступен: GPU-сцена не готова';

  /// Compatibility rendering is acceptable for interactive/non-photo capture,
  /// but a final Photo Render must never masquerade as a GPU 4K export.
  static bool mayUseCompatibilityFallback({required bool photoQuality}) =>
      !photoQuality;

  static bool requiresGpu({required bool photoQuality}) => photoQuality;
}
