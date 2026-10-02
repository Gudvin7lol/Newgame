import 'dart:math' as math;

import '../models/production_asset_catalog.dart';
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
  final double yawCorrectionRad;

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

  String pathForLod(ZamerModelLod lod) => switch (lod) {
    ZamerModelLod.lod0 => assetPath,
    ZamerModelLod.lod1 => lod1AssetPath ?? assetPath,
    ZamerModelLod.lod2 => lod2AssetPath ?? lod1AssetPath ?? assetPath,
  };
}

class ZamerModelAssetCatalog {
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
    'washer',
    'toilet',
    'chandelier-ring',
    'rug-2000x1400',
    'wall-sconce-updown',
  };

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

  static const _productionNativeDimensionsMm =
      <String, (double width, double depth, double height)>{
        // Featured models.
        'armchair': (920, 900, 860),
        'bed-180': (1800, 2200, 1130),
        'coffee-table': (900, 900, 420),
        'sofa-3': (2200, 950, 850),

        // HQ kitchen +107. Native bounds include handles/faucet; the renderer
        // scales them back to the exact catalogue footprint instead of letting
        // protruding details distort placement and camera collision.
        'kitchen-drawers-600': (600, 660, 904.5),
        'kitchen-sink-600-pro': (600, 660, 1185.8),
        'kitchen-cooktop-600': (600, 660, 912.6),
        'kitchen-corner-900': (900, 1015, 904.5),
        'kitchen-pantry-600': (600, 649.5, 2199),
        'fridge-built-in-610': (610, 649.5, 2199),

        // Existing production library.
        'bed-160': (1800, 2150, 1050),
        'dining-chair-upholstered': (500, 580, 860),
        'dining-table-1800': (1800, 900, 760),
        'dresser-1200': (1200, 500, 950),
        'nightstand': (550, 450, 620),
        'office-desk-1400': (1400, 700, 760),
        'sofa-2': (1750, 900, 860),
        'sofa-corner': (2800, 1900, 880),
        'sofa-modular': (2400, 1050, 780),
        'table-round': (1100, 1100, 760),
        'tv-console-1600': (1600, 450, 550),
        'wardrobe-sliding-2000': (2000, 650, 2400),
        'washer': (600, 620, 850),
        'toilet': (390, 700, 760),
        'chandelier-ring': (900, 900, 350),
        'rug-2000x1400': (2000, 1400, 35),
        'wall-sconce-updown': (180, 150, 300),
      };

  static ZamerModelAsset? byId(String id) {
    if (id.isEmpty) return null;
    final matches = ObjectCatalog.items.where((e) => e.id == id);
    if (matches.isEmpty) return null;
    final item = matches.first;

    final production = ZamerProductionCatalog.byPlanCatalogId(id);
    final legacyBasePath = 'assets/models/zamer_catalog/$id';
    final assetPath = production?.model3d ?? '$legacyBasePath.glb';
    final assetStem = assetPath.endsWith('.glb')
        ? assetPath.substring(0, assetPath.length - 4)
        : legacyBasePath;

    final hasProductionLods = productionLodIds.contains(id);
    final native = _productionNativeDimensionsMm[id];
    final asset = ZamerModelAsset(
      catalogId: id,
      assetPath: assetPath,
      lod1AssetPath: hasProductionLods ? '${assetStem}_lod1.glb' : null,
      lod2AssetPath: hasProductionLods ? '${assetStem}_lod2.glb' : null,
      nativeWidthMm: native?.$1 ?? item.widthMm,
      nativeDepthMm: native?.$2 ?? item.depthMm,
      nativeHeightMm: native?.$3 ?? item.heightMm,
      yawCorrectionRad: _reverseFacingProductionIds.contains(id) ? math.pi : 0,
    );
    return asset.hasRenderableDimensions ? asset : null;
  }
}
