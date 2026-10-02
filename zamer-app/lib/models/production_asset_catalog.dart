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

/// Canonical bridge between the approved 2D furnishing catalogue and the GLBs
/// used by the live 3D renderer. Production models with authored LOD chains are
/// all registered here so catalogue, room renderer and tests share one source
/// of truth instead of relying on a second implicit filename convention.
abstract final class ZamerProductionCatalog {
  static const assets = <ZamerCatalogAsset>[
    ZamerCatalogAsset(
      id: 'SOFA_STRAIGHT_01',
      title: 'Диван 3-местный',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(2200, 950, 850),
      planCatalogId: 'sofa-3',
      model3d: 'assets/models/zamer_catalog/sofa-3.glb',
    ),
    ZamerCatalogAsset(
      id: 'SOFA_STRAIGHT_02',
      title: 'Диван 2-местный',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(1700, 900, 850),
      planCatalogId: 'sofa-2',
      model3d: 'assets/models/zamer_catalog/sofa-2.glb',
    ),
    ZamerCatalogAsset(
      id: 'SOFA_CORNER_01',
      title: 'Диван угловой',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(2600, 1700, 850),
      planCatalogId: 'sofa-corner',
      model3d: 'assets/models/zamer_catalog/sofa-corner.glb',
    ),
    ZamerCatalogAsset(
      id: 'SOFA_MODULAR_01',
      title: 'Диван модульный 2800',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(2800, 1000, 850),
      planCatalogId: 'sofa-modular',
      model3d: 'assets/models/zamer_catalog/sofa-modular.glb',
    ),
    ZamerCatalogAsset(
      id: 'ARMCHAIR_01',
      title: 'Кресло',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(920, 900, 860),
      planCatalogId: 'armchair',
      model3d: 'assets/models/zamer_catalog/armchair.glb',
    ),
    ZamerCatalogAsset(
      id: 'BED_DOUBLE_1600_01',
      title: 'Кровать 160×200',
      category: ZamerAssetCategory.beds,
      sizeMm: ZamerAssetSizeMm(1700, 2100, 950),
      planCatalogId: 'bed-160',
      model3d: 'assets/models/zamer_catalog/bed-160.glb',
    ),
    ZamerCatalogAsset(
      id: 'BED_DOUBLE_1800_01',
      title: 'Кровать 180×200',
      category: ZamerAssetCategory.beds,
      sizeMm: ZamerAssetSizeMm(1800, 2200, 1130),
      planCatalogId: 'bed-180',
      model3d: 'assets/models/zamer_catalog/bed-180.glb',
    ),
    ZamerCatalogAsset(
      id: 'TABLE_COFFEE_01',
      title: 'Журнальный стол круглый 900',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(900, 900, 420),
      planCatalogId: 'coffee-table',
      model3d: 'assets/models/zamer_catalog/coffee-table.glb',
    ),
    ZamerCatalogAsset(
      id: 'TABLE_DINING_01',
      title: 'Обеденный стол 1800',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(1800, 900, 760),
      planCatalogId: 'dining-table-1800',
      model3d: 'assets/models/zamer_catalog/dining-table-1800.glb',
    ),
    ZamerCatalogAsset(
      id: 'TABLE_ROUND_01',
      title: 'Стол круглый',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(1000, 1000, 750),
      planCatalogId: 'table-round',
      model3d: 'assets/models/zamer_catalog/table-round.glb',
    ),
    ZamerCatalogAsset(
      id: 'DINING_CHAIR_UPHOLSTERED_01',
      title: 'Стул мягкий',
      category: ZamerAssetCategory.seating,
      sizeMm: ZamerAssetSizeMm(500, 560, 880),
      planCatalogId: 'dining-chair-upholstered',
      model3d: 'assets/models/zamer_catalog/dining-chair-upholstered.glb',
    ),
    ZamerCatalogAsset(
      id: 'DRESSER_1200_01',
      title: 'Комод 1200',
      category: ZamerAssetCategory.storage,
      sizeMm: ZamerAssetSizeMm(1200, 450, 850),
      planCatalogId: 'dresser-1200',
      model3d: 'assets/models/zamer_catalog/dresser-1200.glb',
    ),
    ZamerCatalogAsset(
      id: 'NIGHTSTAND_01',
      title: 'Прикроватная тумба',
      category: ZamerAssetCategory.storage,
      sizeMm: ZamerAssetSizeMm(500, 450, 550),
      planCatalogId: 'nightstand',
      model3d: 'assets/models/zamer_catalog/nightstand.glb',
    ),
    ZamerCatalogAsset(
      id: 'TV_CONSOLE_1600_01',
      title: 'ТВ-тумба 1600',
      category: ZamerAssetCategory.storage,
      sizeMm: ZamerAssetSizeMm(1600, 400, 500),
      planCatalogId: 'tv-console-1600',
      model3d: 'assets/models/zamer_catalog/tv-console-1600.glb',
    ),
    ZamerCatalogAsset(
      id: 'WARDROBE_SLIDING_2000_01',
      title: 'Шкаф-купе 2000',
      category: ZamerAssetCategory.storage,
      sizeMm: ZamerAssetSizeMm(2000, 650, 2400),
      planCatalogId: 'wardrobe-sliding-2000',
      model3d: 'assets/models/zamer_catalog/wardrobe-sliding-2000.glb',
    ),
    ZamerCatalogAsset(
      id: 'OFFICE_DESK_1400_01',
      title: 'Офисный стол 1400',
      category: ZamerAssetCategory.tables,
      sizeMm: ZamerAssetSizeMm(1400, 700, 750),
      planCatalogId: 'office-desk-1400',
      model3d: 'assets/models/zamer_catalog/office-desk-1400.glb',
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
      id: 'WASHER_600_01',
      title: 'Стиральная машина',
      category: ZamerAssetCategory.appliances,
      sizeMm: ZamerAssetSizeMm(600, 600, 850),
      planCatalogId: 'washer',
      model3d: 'assets/models/zamer_catalog/washer.glb',
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
      title: 'Радиатор 600',
      category: ZamerAssetCategory.heating,
      sizeMm: ZamerAssetSizeMm(600, 120, 600),
      planCatalogId: 'radiator-600',
      model3d: 'assets/models/zamer_catalog/radiator-600.glb',
    ),
    ZamerCatalogAsset(
      id: 'CHANDELIER_RING_01',
      title: 'Люстра-кольцо',
      category: ZamerAssetCategory.lighting,
      sizeMm: ZamerAssetSizeMm(900, 900, 350),
      planCatalogId: 'chandelier-ring',
      model3d: 'assets/models/zamer_catalog/chandelier-ring.glb',
    ),
    ZamerCatalogAsset(
      id: 'WALL_SCONCE_UPDOWN_01',
      title: 'Бра вверх/вниз',
      category: ZamerAssetCategory.lighting,
      sizeMm: ZamerAssetSizeMm(180, 150, 300),
      planCatalogId: 'wall-sconce-updown',
      model3d: 'assets/models/zamer_catalog/wall-sconce-updown.glb',
    ),
    ZamerCatalogAsset(
      id: 'RUG_2000_1400_01',
      title: 'Ковёр 2000×1400',
      category: ZamerAssetCategory.decor,
      sizeMm: ZamerAssetSizeMm(2000, 1400, 35),
      planCatalogId: 'rug-2000x1400',
      model3d: 'assets/models/zamer_catalog/rug-2000x1400.glb',
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
