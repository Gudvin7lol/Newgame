import 'dart:math' as math;

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
    this.yawCorrectionRad = 0,
  });

  final String catalogId;
  final String assetPath;
  final String? lod1AssetPath;
  final String? lod2AssetPath;
  final double nativeWidthMm, nativeDepthMm, nativeHeightMm;

  /// Extra yaw applied after converting the plan angle into GPU coordinates.
  ///
  /// Plan icons use a semantic front/back direction. Some generated GLBs were
  /// authored with the same geometry facing the opposite glTF forward axis,
  /// which made a bed placed headboard-to-wall appear headboard-away in 3D.
  /// Keeping this correction on the asset avoids corrupting the stored plan
  /// angle and keeps wall/opening coordinate transforms untouched.
  final double yawCorrectionRad;

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

  /// Directional generated assets whose semantic rear side (headboard/back)
  /// currently arrives from the glTF importer opposite to the plan preview.
  /// Symmetric tables and storage items stay at zero correction.
  static const _reverseFacingProductionIds = <String>{
    'armchair',
    'bed-160',
    'bed-180',
    'dining-chair-upholstered',
    'sofa-2',
    'sofa-3',
    'sofa-corner',
    'sofa-modular',
  };

  /// Native GLB bounds in millimetres, in width/depth/height order. They are
  /// intentionally separate from ObjectCatalog dimensions: the latter describe
  /// the requested plan footprint, while these values describe the authored
  /// mesh that must be scaled into that footprint.
  static const _productionNativeDimensionsMm =
      <String, (double width, double depth, double height)>{
        'armchair': (900, 900, 900),
        'bed-160': (1800, 2150, 1050),
        'bed-180': (2000, 2180, 1080),
        'coffee-table': (1100, 620, 420),
        'dining-chair-upholstered': (500, 580, 860),
        'dining-table-1800': (1800, 900, 760),
        'dresser-1200': (1200, 500, 950),
        'nightstand': (550, 450, 620),
        'office-desk-1400': (1400, 700, 760),
        'sofa-2': (1750, 900, 860),
        'sofa-3': (2200, 900, 850),
        'sofa-corner': (2800, 1900, 880),
        'sofa-modular': (2400, 1050, 780),
        'table-round': (1100, 1100, 760),
        'tv-console-1600': (1600, 450, 550),
        'wardrobe-sliding-2000': (2000, 650, 2400),
      };

  static ZamerModelAsset? byId(String id) {
    if (id.isEmpty) return null;
    final matches = ObjectCatalog.items.where((e) => e.id == id);
    if (matches.isEmpty) return null;
    final item = matches.first;
    final basePath = 'assets/models/zamer_catalog/$id';
    final hasProductionLods = productionLodIds.contains(id);
    final native = _productionNativeDimensionsMm[id];
    final asset = ZamerModelAsset(
      catalogId: id,
      assetPath: '$basePath.glb',
      lod1AssetPath: hasProductionLods ? '${basePath}_lod1.glb' : null,
      lod2AssetPath: hasProductionLods ? '${basePath}_lod2.glb' : null,
      nativeWidthMm: native?.$1 ?? item.widthMm,
      nativeDepthMm: native?.$2 ?? item.depthMm,
      nativeHeightMm: native?.$3 ?? item.heightMm,
      yawCorrectionRad: _reverseFacingProductionIds.contains(id) ? math.pi : 0,
    );
    return asset.hasRenderableDimensions ? asset : null;
  }
}
