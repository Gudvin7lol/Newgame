import '../services/object_catalog.dart';

enum ZamerModelLod { lod0, lod1, lod2 }

class ZamerModelAsset {
  const ZamerModelAsset({
    required this.catalogId,
    required this.assetPath,
    required this.nativeWidthMm,
    required this.nativeDepthMm,
    required this.nativeHeightMm,
    this.lod1AssetPath,
    this.lod2AssetPath,
  });

  final String catalogId;
  final String assetPath;
  final String? lod1AssetPath;
  final String? lod2AssetPath;
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

  bool get hasLod1 => lod1AssetPath != null;
  bool get hasLod2 => lod2AssetPath != null;
  bool get hasCompleteLodChain => hasLod1 && hasLod2;

  /// Returns the closest available model for the requested detail level.
  /// Legacy catalogue entries transparently fall back to LOD0.
  String pathForLod(ZamerModelLod lod) => switch (lod) {
    ZamerModelLod.lod0 => assetPath,
    ZamerModelLod.lod1 => lod1AssetPath ?? assetPath,
    ZamerModelLod.lod2 => lod2AssetPath ?? lod1AssetPath ?? assetPath,
  };
}

/// Maps plan catalog IDs to bundled GLB models. The GLBs are authored in metres
/// with +Y up, so scene placement is deterministic and does not depend on a
/// vendor model's arbitrary coordinate system.
class ZamerModelAssetCatalog {
  /// Assets rebuilt by the production pipeline and guaranteed to have LOD0/1/2.
  static const productionLodIds = <String>{
    'armchair',
    'bed-160',
    'bed-180',
    'coffee-table',
    'dining-chair-upholstered',
    'dining-table-1800',
    'dresser-1200',
    'nightstand',
    'office-desk-1400',
    'sofa-2',
    'sofa-3',
    'sofa-corner',
    'sofa-modular',
    'table-round',
    'tv-console-1600',
    'wardrobe-sliding-2000',
  };

  static ZamerModelAsset? byId(String id) {
    if (id.isEmpty) return null;
    final matches = ObjectCatalog.items.where((e) => e.id == id);
    if (matches.isEmpty) return null;
    final item = matches.first;
    final basePath = 'assets/models/zamer_catalog/$id';
    final hasProductionLods = productionLodIds.contains(id);
    final asset = ZamerModelAsset(
      catalogId: id,
      assetPath: '$basePath.glb',
      lod1AssetPath: hasProductionLods ? '${basePath}_lod1.glb' : null,
      lod2AssetPath: hasProductionLods ? '${basePath}_lod2.glb' : null,
      nativeWidthMm: item.widthMm,
      nativeDepthMm: item.depthMm,
      nativeHeightMm: item.heightMm,
    );
    return asset.hasRenderableDimensions ? asset : null;
  }
}
