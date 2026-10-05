enum RuntimeMaterialV4Kind {
  seamlessSurface,
  proceduralTileSurface,
  plankCollection,
}

class RuntimeMaterialV4Descriptor {
  const RuntimeMaterialV4Descriptor({
    required this.id,
    required this.name,
    required this.category,
    required this.assetRoot,
    required this.kind,
    required this.widthPx,
    required this.heightPx,
    required this.physicalWidthMm,
    required this.physicalHeightMm,
    this.plankCount = 0,
    this.bevelMm = 0,
    this.groutWidthMm = 0,
    this.randomUvOffset = false,
    this.randomRotation = false,
  });

  final String id;
  final String name;
  final String category;
  final String assetRoot;
  final RuntimeMaterialV4Kind kind;
  final int widthPx;
  final int heightPx;
  final double physicalWidthMm;
  final double physicalHeightMm;
  final int plankCount;
  final double bevelMm;
  final double groutWidthMm;
  final bool randomUvOffset;
  final bool randomRotation;

  bool get isPlankCollection => kind == RuntimeMaterialV4Kind.plankCollection;
  bool get isTile => kind == RuntimeMaterialV4Kind.proceduralTileSurface;

  String mapAsset(String mapName) => '$assetRoot/$mapName';

  String plankMapAsset(int plankIndex, String mapName) {
    if (!isPlankCollection) {
      throw StateError('$id is not a plank collection');
    }
    if (plankIndex < 1 || plankIndex > plankCount) {
      throw RangeError.range(plankIndex, 1, plankCount, 'plankIndex');
    }
    final plank = plankIndex.toString().padLeft(2, '0');
    return '$assetRoot/planks/$plank/$mapName';
  }
}

/// Production material package supplied for ZAMER v4.
///
/// Runtime maps:
/// - walls/tiles: 2048x2048 BaseColor, Normal, Roughness, Height and AO;
/// - laminate: 16 separate 2048x286 planks per collection with the same maps;
/// - normals use OpenGL Y+;
/// - metallic is always zero;
/// - tile grout and plank seams are procedural and must not be baked into maps.
abstract final class RuntimeMaterialPackV4 {
  static const root = 'assets/textures/runtime_v4';
  static const metallic = 0.0;
  static const normalConvention = 'OpenGL_Y+';
  static const mapNames = <String>[
    'basecolor.webp',
    'normal.png',
    'roughness.png',
    'height.png',
    'ao.png',
  ];
  static const laminatePatterns = <String>[
    'random_stagger',
    'half',
    'third',
    'herringbone_90',
    'herringbone_45',
    'chevron',
  ];

  static const materials = <RuntimeMaterialV4Descriptor>[
    RuntimeMaterialV4Descriptor(
      id: 'Wall_Brick_Red_01',
      name: 'Красный кирпич',
      category: 'walls',
      assetRoot: '$root/walls/Wall_Brick_Red_01',
      kind: RuntimeMaterialV4Kind.seamlessSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Wall_GypsumPlaster_White_01',
      name: 'Гипсовая штукатурка',
      category: 'walls',
      assetRoot: '$root/walls/Wall_GypsumPlaster_White_01',
      kind: RuntimeMaterialV4Kind.seamlessSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Wall_Paint_MatteWhite_01',
      name: 'Матовая краска',
      category: 'walls',
      assetRoot: '$root/walls/Wall_Paint_MatteWhite_01',
      kind: RuntimeMaterialV4Kind.seamlessSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Tile_ConcreteLight_01',
      name: 'Бетон светлый',
      category: 'tiles',
      assetRoot: '$root/tiles/Tile_ConcreteLight_01',
      kind: RuntimeMaterialV4Kind.proceduralTileSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 600,
      physicalHeightMm: 600,
      groutWidthMm: 2,
      randomUvOffset: true,
      randomRotation: true,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Tile_MarbleLight_01',
      name: 'Мрамор светлый',
      category: 'tiles',
      assetRoot: '$root/tiles/Tile_MarbleLight_01',
      kind: RuntimeMaterialV4Kind.proceduralTileSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 600,
      physicalHeightMm: 600,
      groutWidthMm: 2,
      randomUvOffset: true,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Tile_TerrazzoLight_01',
      name: 'Терраццо светлый',
      category: 'tiles',
      assetRoot: '$root/tiles/Tile_TerrazzoLight_01',
      kind: RuntimeMaterialV4Kind.proceduralTileSurface,
      widthPx: 2048,
      heightPx: 2048,
      physicalWidthMm: 600,
      physicalHeightMm: 600,
      groutWidthMm: 2,
      randomUvOffset: true,
      randomRotation: true,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Laminate_OakLight_01',
      name: 'Светлый дуб',
      category: 'laminate',
      assetRoot: '$root/laminate/Laminate_OakLight_01',
      kind: RuntimeMaterialV4Kind.plankCollection,
      widthPx: 2048,
      heightPx: 286,
      physicalWidthMm: 1380,
      physicalHeightMm: 193,
      plankCount: 16,
      bevelMm: 1,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Laminate_OakSmoked_01',
      name: 'Дымчатый дуб',
      category: 'laminate',
      assetRoot: '$root/laminate/Laminate_OakSmoked_01',
      kind: RuntimeMaterialV4Kind.plankCollection,
      widthPx: 2048,
      heightPx: 286,
      physicalWidthMm: 1380,
      physicalHeightMm: 193,
      plankCount: 16,
      bevelMm: 1,
    ),
    RuntimeMaterialV4Descriptor(
      id: 'Laminate_WalnutWarm_01',
      name: 'Тёплый орех',
      category: 'laminate',
      assetRoot: '$root/laminate/Laminate_WalnutWarm_01',
      kind: RuntimeMaterialV4Kind.plankCollection,
      widthPx: 2048,
      heightPx: 286,
      physicalWidthMm: 1380,
      physicalHeightMm: 193,
      plankCount: 16,
      bevelMm: 1,
    ),
  ];

  static RuntimeMaterialV4Descriptor byId(String id) =>
      materials.firstWhere((material) => material.id == id);

  static List<RuntimeMaterialV4Descriptor> get walls =>
      materials.where((material) => material.category == 'walls').toList();

  static List<RuntimeMaterialV4Descriptor> get tiles =>
      materials.where((material) => material.category == 'tiles').toList();

  static List<RuntimeMaterialV4Descriptor> get laminate =>
      materials.where((material) => material.category == 'laminate').toList();
}
