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
    this.preview2d,
    this.model3d,
    this.materialIds = const [],
  });

  final String id;
  final String title;
  final ZamerAssetCategory category;
  final ZamerAssetSizeMm sizeMm;

  /// Orthographic top-view preview. It must describe the same object as [model3d].
  final String? preview2d;

  /// Production GLB. Null means that the matching model is still being prepared.
  final String? model3d;

  /// PBR material presets allowed for this asset.
  final List<String> materialIds;

  bool get hasLinked2d3d => preview2d != null && model3d != null;
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

/// +81 production registry. Asset paths are filled only after the corresponding
/// files have passed the 2D/3D visual-match and mobile-performance checks.
abstract final class ZamerProductionCatalog {
  static const assets = <ZamerCatalogAsset>[
    ZamerCatalogAsset(
      id: 'SOFA_STRAIGHT_01',
      title: 'Диван прямой',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(2200, 950, 850),
      model3d: 'assets/models/zamer_catalog/sofa-3.glb',
    ),
    ZamerCatalogAsset(
      id: 'ARMCHAIR_01',
      title: 'Кресло',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(900, 900, 900),
      model3d: 'assets/models/zamer_catalog/armchair.glb',
    ),
    ZamerCatalogAsset(
      id: 'BED_DOUBLE_1600_01',
      title: 'Кровать 1600',
      category: ZamerAssetCategory.beds,
      sizeMm: ZamerAssetSizeMm(1700, 2150, 1050),
      model3d: 'assets/models/zamer_catalog/bed-160.glb',
    ),
    ZamerCatalogAsset(
      id: 'TABLE_DINING_01',
      title: 'Стол обеденный',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(1600, 900, 760),
      model3d: 'assets/models/zamer_catalog/dining-table-1800.glb',
    ),
    ZamerCatalogAsset(
      id: 'KITCHEN_BASE_600_01',
      title: 'Кухонный модуль 600',
      category: ZamerAssetCategory.kitchen,
      sizeMm: ZamerAssetSizeMm(600, 600, 870),
      model3d: 'assets/models/zamer_catalog/kitchen-base.glb',
    ),
    ZamerCatalogAsset(
      id: 'KITCHEN_SINK_600_01',
      title: 'Модуль мойки 600',
      category: ZamerAssetCategory.kitchen,
      sizeMm: ZamerAssetSizeMm(600, 600, 870),
      model3d: 'assets/models/zamer_catalog/kitchen-sink.glb',
    ),
    ZamerCatalogAsset(
      id: 'FRIDGE_600_01',
      title: 'Холодильник',
      category: ZamerAssetCategory.appliances,
      sizeMm: ZamerAssetSizeMm(600, 650, 2000),
      model3d: 'assets/models/zamer_catalog/fridge.glb',
    ),
    ZamerCatalogAsset(
      id: 'DISHWASHER_600_01',
      title: 'Посудомоечная машина',
      category: ZamerAssetCategory.appliances,
      sizeMm: ZamerAssetSizeMm(600, 600, 850),
      model3d: 'assets/models/zamer_catalog/dishwasher.glb',
    ),
    ZamerCatalogAsset(
      id: 'BATHTUB_1700_01',
      title: 'Ванна 1700',
      category: ZamerAssetCategory.plumbing,
      sizeMm: ZamerAssetSizeMm(1700, 750, 600),
      model3d: 'assets/models/zamer_catalog/bath.glb',
    ),
    ZamerCatalogAsset(
      id: 'TOILET_01',
      title: 'Унитаз',
      category: ZamerAssetCategory.plumbing,
      sizeMm: ZamerAssetSizeMm(380, 650, 800),
      model3d: 'assets/models/zamer_catalog/toilet.glb',
    ),
    ZamerCatalogAsset(
      id: 'RADIATOR_600_01',
      title: 'Радиатор',
      category: ZamerAssetCategory.heating,
      sizeMm: ZamerAssetSizeMm(1000, 100, 600),
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
}
