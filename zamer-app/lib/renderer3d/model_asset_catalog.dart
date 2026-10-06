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
    if (item.procedural) return null;
    return ZamerModelAsset(
      catalogId: id,
      assetPath: 'assets/models/zamer_catalog/$id.glb',
      nativeWidthMm: item.widthMm,
      nativeDepthMm: item.depthMm,
      nativeHeightMm: item.heightMm,
    );
  }
}
