import '../services/object_catalog.dart';
import 'render_quality.dart';

class ZamerModelAsset {
  const ZamerModelAsset({
    required this.catalogId,
    required this.realtimeAssetPath,
    this.photoAssetPath,
    required this.nativeWidthMm,
    required this.nativeDepthMm,
    required this.nativeHeightMm,
  });

  final String catalogId;
  final String realtimeAssetPath;
  final String? photoAssetPath;
  final double nativeWidthMm, nativeDepthMm, nativeHeightMm;

  String assetPathFor(ZamerRenderQuality quality) =>
      quality == ZamerRenderQuality.photo4k
          ? (photoAssetPath ?? realtimeAssetPath)
          : realtimeAssetPath;
}

/// Maps plan catalog IDs to bundled GLB models.
///
/// Premium furniture keeps a mobile GLB for Performance/Quality and a denser
/// GLB for Photo 4K. Generic catalog items keep using the compact legacy model
/// set until each category gets a proper production asset.
class ZamerModelAssetCatalog {
  static const Map<String, ZamerModelAsset> _premium =
      <String, ZamerModelAsset>{
    'sofa-sand': ZamerModelAsset(
      catalogId: 'sofa-sand',
      realtimeAssetPath:
          'assets/models/zamer_premium/sofa_sand_mobile.glb',
      photoAssetPath: 'assets/models/zamer_premium/sofa_sand_high.glb',
      nativeWidthMm: 2400,
      nativeDepthMm: 950,
      nativeHeightMm: 860,
    ),
    'bed-sand': ZamerModelAsset(
      catalogId: 'bed-sand',
      realtimeAssetPath: 'assets/models/zamer_premium/bed_sand_mobile.glb',
      photoAssetPath: 'assets/models/zamer_premium/bed_sand_high.glb',
      nativeWidthMm: 1800,
      nativeDepthMm: 2200,
      nativeHeightMm: 1130,
    ),
    'armchair-sand': ZamerModelAsset(
      catalogId: 'armchair-sand',
      realtimeAssetPath:
          'assets/models/zamer_premium/armchair_sand_mobile.glb',
      photoAssetPath: 'assets/models/zamer_premium/armchair_sand_high.glb',
      nativeWidthMm: 920,
      nativeDepthMm: 900,
      nativeHeightMm: 860,
    ),
    'table-walnut': ZamerModelAsset(
      catalogId: 'table-walnut',
      realtimeAssetPath:
          'assets/models/zamer_premium/table_walnut_mobile.glb',
      photoAssetPath: 'assets/models/zamer_premium/table_walnut_high.glb',
      nativeWidthMm: 900,
      nativeDepthMm: 900,
      nativeHeightMm: 420,
    ),
    'wardrobe-oak': ZamerModelAsset(
      catalogId: 'wardrobe-oak',
      realtimeAssetPath: 'assets/models/zamer_premium/wardrobe.glb',
      nativeWidthMm: 1212,
      nativeDepthMm: 653,
      nativeHeightMm: 2510,
    ),
    'tv-console-oak': ZamerModelAsset(
      catalogId: 'tv-console-oak',
      realtimeAssetPath: 'assets/models/zamer_premium/tv_console.glb',
      nativeWidthMm: 1820,
      nativeDepthMm: 468,
      nativeHeightMm: 598,
    ),
  };

  static ZamerModelAsset? byId(String id) {
    if (id.isEmpty) return null;
    final premium = _premium[id];
    if (premium != null) return premium;

    final matches = ObjectCatalog.items.where((e) => e.id == id);
    if (matches.isEmpty) return null;
    final item = matches.first;
    if (item.procedural) return null;
    return ZamerModelAsset(
      catalogId: id,
      realtimeAssetPath: 'assets/models/zamer_catalog/$id.glb',
      nativeWidthMm: item.widthMm,
      nativeDepthMm: item.depthMm,
      nativeHeightMm: item.heightMm,
    );
  }
}
