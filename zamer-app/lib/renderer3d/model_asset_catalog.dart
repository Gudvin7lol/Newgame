import '../services/object_catalog.dart';

class ZamerModelAsset {
  const ZamerModelAsset({
    required this.catalogId,
    required this.assetPath,
    required this.nativeWidthMm,
    required this.nativeDepthMm,
    required this.nativeHeightMm,
  });
  final String catalogId;
  final String assetPath;
  final double nativeWidthMm, nativeDepthMm, nativeHeightMm;

  /// Invalid catalogue dimensions can turn the GLB scale into NaN/infinity and
  /// make an otherwise healthy GPU scene disappear. Treat such entries as
  /// unavailable so the renderer can use its safe fallback object instead.
  bool get hasRenderableDimensions =>
      nativeWidthMm.isFinite &&
      nativeDepthMm.isFinite &&
      nativeHeightMm.isFinite &&
      nativeWidthMm > 0 &&
      nativeDepthMm > 0 &&
      nativeHeightMm > 0;
}

/// Maps plan catalog IDs to bundled GLB models. The GLBs are authored in metres
/// with +Y up, so scene placement is deterministic and does not depend on a
/// vendor model's arbitrary coordinate system.
class ZamerModelAssetCatalog {
  static ZamerModelAsset? byId(String id) {
    if (id.isEmpty) return null;
    final matches = ObjectCatalog.items.where((e) => e.id == id);
    if (matches.isEmpty) return null;
    final item = matches.first;
    final asset = ZamerModelAsset(
      catalogId: id,
      assetPath: 'assets/models/zamer_catalog/$id.glb',
      nativeWidthMm: item.widthMm,
      nativeDepthMm: item.depthMm,
      nativeHeightMm: item.heightMm,
    );
    return asset.hasRenderableDimensions ? asset : null;
  }
}
