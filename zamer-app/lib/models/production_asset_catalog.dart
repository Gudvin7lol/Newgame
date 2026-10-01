enum ZamerAssetCategory {
  seating,
  beds,
  tables,
  storage,
  kitchen,
  plumbing,
  appliances,
  openings,
  heating,
  lighting,
  decor,
}

class ZamerAssetSizeMm {
  const ZamerAssetSizeMm(this.width, this.depth, this.height);
  final double width;
  final double depth;
  final double height;
}

class ZamerCatalogAsset {
  const ZamerCatalogAsset({
    required this.id,
    required this.title,
    required this.category,
    required this.sizeMm,
    this.planCatalogId,
    this.preview2d,
    this.model3d,
    this.materialIds = const [],
  });

  final String id;
  final String title;
  final ZamerAssetCategory category;
  final ZamerAssetSizeMm sizeMm;

  /// Canonical id of the existing 2D object in ObjectCatalog. The 2D plan
  /// renderer already knows how to draw these objects, so we do not need a
  /// second raster preview just to connect the same item to its production GLB.
  final String? planCatalogId;

  /// Optional orthographic raster preview for assets that cannot yet be drawn
  /// by the live 2D plan renderer.
  final String? preview2d;

  /// Production GLB. Null means that the matching model is still being prepared.
  final String? model3d;

  /// PBR material presets allowed for this asset.
  final List<String> materialIds;

  bool get has2dSource => planCatalogId != null || preview2d != null;
  bool get hasLinked2d3d => has2dSource && model3d != null;
}

class ZamerPbrMaterial {
  const ZamerPbrMaterial({
    required this.id,
    required this.title,
    required this.realWorldTileMm,
    required this.baseColor,
    required this.normal,
    required this.roughness,
    this.height,
    this.ao,
    this.metallic,
  });

  final String id;
  final String title;

  /// Physical repeat size. Renderer must use this instead of stretching one
  /// texture over an entire wall or floor.
  final double realWorldTileMm;
  final String baseColor;
  final String normal;
  final String roughness;
  final String? height;
  final String? ao;
  final String? metallic;
}

/// +82 production registry. [planCatalogId] is the bridge between the approved
/// 2D library and the matching GLB used in 3D. The placement dimensions below
/// intentionally match ObjectCatalog so switching from 2D to 3D never changes
/// the object's footprint; authored GLB bounds are handled by the 3D catalog.
abstract final class ZamerProductionCatalog {
  static const assets = <ZamerCatalogAsset>[
    ZamerCatalogAsset(
      id: 'SOFA_STRAIGHT_01',
      title: 'Диван прямой',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(2200, 900, 850),
      planCatalogId: 'sofa-3',
      model3d: 'assets/models/zamer_catalog/sofa-3.glb',
    ),
    ZamerCatalogAsset(
      id: 'ARMCHAIR_01',
      title: 'Кресло',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(850, 850, 900),
      planCatalogId: 'armchair',
      model3d: 'assets/models/zamer_catalog/armchair.glb',
    ),
    ZamerCatalogAsset(
      id: 'BED_DOUBLE_1600_01',
      title: 'Кровать 1600',
      category: ZamerAssetCategory.beds,
      sizeMm: ZamerAssetSizeMm(1700, 2100, 950),
      planCatalogId: 'bed-160',
      model3d: 'assets/models/zamer_catalog/bed-160.glb',
    ),
    ZamerCatalogAsset(
      id: 'TABLE_DINING_01',
      title: 'Стол обеденный',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(1800, 900, 760),
      planCatalogId: 'dining-table-1800',
      model3d: 'assets/models/zamer_catalog/dining-table-1800.glb',
    ),
    ZamerCatalogAsset(
      id: 'KITCHEN_BASE_600_01',
      title: 'Кухонный модуль 600',
      category: ZamerAssetCategory.kitchen,
      sizeMm: ZamerAssetSizeMm(600, 600, 900),
      planCatalogId: 'kitchen-base',
      model3d: 'assets/models/zamer_catalog/kitchen-base.glb',
    ),
    ZamerCatalogAsset(
      id: 'KITCHEN_SINK_600_01',
      title: 'Модуль мойки 600',
      category: ZamerAssetCategory.kitchen,
      sizeMm: ZamerAssetSizeMm(600, 600, 900),
      planCatalogId: 'kitchen-sink',
      model3d: 'assets/models/zamer_catalog/kitchen-sink.glb',
    ),
    ZamerCatalogAsset(
      id: 'FRIDGE_600_01',
      title: 'Холодильник',
      category: ZamerAssetCategory.appliances,
      sizeMm: ZamerAssetSizeMm(600, 650, 1900),
      planCatalogId: 'fridge',
      model3d: 'assets/models/zamer_catalog/fridge.glb',
    ),
    ZamerCatalogAsset(
      id: 'DISHWASHER_600_01',
      title: 'Посудомоечная машина',
      category: ZamerAssetCategory.appliances,
      sizeMm: ZamerAssetSizeMm(600, 600, 850),
      planCatalogId: 'dishwasher',
      model3d: 'assets/models/zamer_catalog/dishwasher.glb',
    ),
    ZamerCatalogAsset(
      id: 'BATHTUB_1700_01',
      title: 'Ванна 1700',
      category: ZamerAssetCategory.plumbing,
      sizeMm: ZamerAssetSizeMm(1700, 750, 600),
      planCatalogId: 'bath',
      model3d: 'assets/models/zamer_catalog/bath.glb',
    ),
    ZamerCatalogAsset(
      id: 'TOILET_01',
      title: 'Унитаз',
      category: ZamerAssetCategory.plumbing,
      sizeMm: ZamerAssetSizeMm(390, 700, 760),
      planCatalogId: 'toilet',
      model3d: 'assets/models/zamer_catalog/toilet.glb',
    ),
    ZamerCatalogAsset(
      id: 'RADIATOR_600_01',
      title: 'Радиатор',
      category: ZamerAssetCategory.heating,
      sizeMm: ZamerAssetSizeMm(600, 120, 600),
      planCatalogId: 'radiator-600',
      model3d: 'assets/models/zamer_catalog/radiator-600.glb',
    ),
    ZamerCatalogAsset(
      id: 'DOOR_SINGLE_800_01',
      title: 'Дверь 800',
      category: ZamerAssetCategory.openings,
      sizeMm: ZamerAssetSizeMm(800, 100, 2050),
    ),
    ZamerCatalogAsset(
      id: 'WINDOW_1200_01',
      title: 'Окно 1200',
      category: ZamerAssetCategory.openings,
      sizeMm: ZamerAssetSizeMm(1200, 100, 1400),
    ),
  ];

  static const materials = <ZamerPbrMaterial>[];

  static ZamerCatalogAsset? byId(String id) {
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  static ZamerCatalogAsset? byPlanCatalogId(String catalogId) {
    if (catalogId.isEmpty) return null;
    for (final asset in assets) {
      if (asset.planCatalogId == catalogId) return asset;
    }
    return null;
  }

  static Iterable<ZamerCatalogAsset> get linked2d3d =>
      assets.where((asset) => asset.hasLinked2d3d);
}
