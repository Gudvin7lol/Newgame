enum ZamerRenderQuality { performance, quality, photo4k }

/// Three graphics tiers used by the 3D renderer.
///
/// Performance and Quality are realtime profiles. Photo 4K is intentionally
/// reserved for the final render path so we do not turn mid-range phones into
/// hand warmers just because somebody opened a bedroom scene.
extension ZamerRenderQualitySpec on ZamerRenderQuality {
  bool get isRealtime => this != ZamerRenderQuality.photo4k;

  int get width => switch (this) {
    ZamerRenderQuality.performance => 0,
    ZamerRenderQuality.quality => 0,
    ZamerRenderQuality.photo4k => 3840,
  };

  int get height => switch (this) {
    ZamerRenderQuality.performance => 0,
    ZamerRenderQuality.quality => 0,
    ZamerRenderQuality.photo4k => 2160,
  };

  String get label => switch (this) {
    ZamerRenderQuality.performance => 'Performance',
    ZamerRenderQuality.quality => 'Quality',
    ZamerRenderQuality.photo4k => 'Photo 4K',
  };

  int get shadowMapResolution => switch (this) {
    ZamerRenderQuality.performance => 512,
    ZamerRenderQuality.quality => 1024,
    ZamerRenderQuality.photo4k => 2048,
  };

  bool get ambientOcclusionEnabled => switch (this) {
    ZamerRenderQuality.performance => false,
    ZamerRenderQuality.quality => true,
    ZamerRenderQuality.photo4k => true,
  };

  int get ambientOcclusionSamples => switch (this) {
    ZamerRenderQuality.performance => 2,
    ZamerRenderQuality.quality => 4,
    ZamerRenderQuality.photo4k => 12,
  };

  bool get reflectionsEnabled => switch (this) {
    ZamerRenderQuality.performance => false,
    ZamerRenderQuality.quality => true,
    ZamerRenderQuality.photo4k => true,
  };

  double get reflectionsResolutionScale => switch (this) {
    ZamerRenderQuality.performance => 0.5,
    ZamerRenderQuality.quality => 0.65,
    ZamerRenderQuality.photo4k => 1.0,
  };

  bool get bloomEnabled => switch (this) {
    ZamerRenderQuality.performance => false,
    ZamerRenderQuality.quality => true,
    ZamerRenderQuality.photo4k => true,
  };
}
