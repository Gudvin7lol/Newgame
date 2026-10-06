import 'package:flutter/material.dart';

import 'generated_material_ids.dart';

class VisualMaterialPreset {
  const VisualMaterialPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    this.pattern = 'solid',
    this.textureAsset,
    this.roughness,
  });

  final String id;
  final String name;
  final String category;
  final Color color;
  final String pattern;
  final String? textureAsset;
  final double? roughness;
}

class MaterialCatalog {
  static const runtimeV4 = <VisualMaterialPreset>[
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4WallBrickRed,
      name: 'Красный кирпич · Runtime v4',
      category: 'Стены',
      color: Color(0xFF9D5943),
      pattern: 'brick',
      textureAsset:
          'assets/textures/runtime_v4/Wall_Brick_Red_01_basecolor.webp',
      roughness: .78,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4WallGypsumPlaster,
      name: 'Гипсовая штукатурка · Runtime v4',
      category: 'Стены',
      color: Color(0xFFD2C7B6),
      pattern: 'concrete',
      textureAsset:
          'assets/textures/runtime_v4/Wall_GypsumPlaster_White_01_basecolor.webp',
      roughness: .88,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4WallPaintMatteWhite,
      name: 'Матовая краска · Runtime v4',
      category: 'Стены',
      color: Color(0xFFECE7DE),
      textureAsset:
          'assets/textures/runtime_v4/Wall_Paint_MatteWhite_01_basecolor.webp',
      roughness: .86,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4TileConcreteLight,
      name: 'Бетон светлый · Runtime v4',
      category: 'Плитка',
      color: Color(0xFFB8B9B7),
      pattern: 'tile',
      textureAsset:
          'assets/textures/runtime_v4/Tile_ConcreteLight_01_basecolor.webp',
      roughness: .55,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4TileMarbleLight,
      name: 'Мрамор светлый · Runtime v4',
      category: 'Плитка',
      color: Color(0xFFE9E6E0),
      pattern: 'tile',
      textureAsset:
          'assets/textures/runtime_v4/Tile_MarbleLight_01_basecolor.webp',
      roughness: .28,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4TileTerrazzoLight,
      name: 'Терраццо светлый · Runtime v4',
      category: 'Плитка',
      color: Color(0xFFD3D0C7),
      pattern: 'tile',
      textureAsset:
          'assets/textures/runtime_v4/Tile_TerrazzoLight_01_basecolor.webp',
      roughness: .43,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4LaminateOakLight,
      name: 'Светлый дуб · Runtime v4',
      category: 'Пол',
      color: Color(0xFFC7B79F),
      pattern: 'wood',
      textureAsset:
          'assets/textures/runtime_v4/Laminate_OakLight_01_basecolor.webp',
      roughness: .56,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4LaminateOakSmoked,
      name: 'Дымчатый дуб · Runtime v4',
      category: 'Пол',
      color: Color(0xFF5B4030),
      pattern: 'wood',
      textureAsset:
          'assets/textures/runtime_v4/Laminate_OakSmoked_01_basecolor.webp',
      roughness: .54,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeV4LaminateWalnutWarm,
      name: 'Тёплый орех · Runtime v4',
      category: 'Пол',
      color: Color(0xFF815A3D),
      pattern: 'wood',
      textureAsset:
          'assets/textures/runtime_v4/Laminate_WalnutWarm_01_basecolor.webp',
      roughness: .50,
    ),
  ];

  static const generatedV1 = <VisualMaterialPreset>[
    VisualMaterialPreset(
      id: GeneratedMaterialIds.darkOak,
      name: 'Дымчатый дуб · PBR',
      category: 'Пол',
      color: Color(0xFF5B4030),
      pattern: 'wood',
      textureAsset: 'assets/textures/generated_v1/dark_oak.jpg',
      roughness: .54,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.whiteOak,
      name: 'Светлый дуб · PBR',
      category: 'Пол',
      color: Color(0xFFC7B79F),
      pattern: 'wood',
      textureAsset: 'assets/textures/generated_v1/white_oak.jpg',
      roughness: .56,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.travertine,
      name: 'Травертин',
      category: 'Плитка',
      color: Color(0xFFCBB997),
      pattern: 'tile',
      textureAsset: 'assets/textures/generated_v1/travertine.jpg',
      roughness: .62,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.terrazzo,
      name: 'Терраццо светлый · PBR',
      category: 'Плитка',
      color: Color(0xFFD3D0C7),
      pattern: 'tile',
      textureAsset: 'assets/textures/generated_v1/terrazzo.jpg',
      roughness: .43,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.slate,
      name: 'Сланец',
      category: 'Плитка',
      color: Color(0xFF53575A),
      pattern: 'tile',
      textureAsset: 'assets/textures/generated_v1/slate.jpg',
      roughness: .72,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.terracotta,
      name: 'Терракота',
      category: 'Плитка',
      color: Color(0xFFA76646),
      pattern: 'tile',
      textureAsset: 'assets/textures/generated_v1/terracotta.jpg',
      roughness: .68,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallPaint,
      name: 'Матовая краска · PBR',
      category: 'Стены',
      color: Color(0xFFECE7DE),
      textureAsset: 'assets/textures/generated_v1/wall_paint.jpg',
      roughness: .86,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallLime,
      name: 'Известковая штукатурка · песочный',
      category: 'Стены',
      color: Color(0xFFC9B496),
      pattern: 'concrete',
      textureAsset: 'assets/textures/generated_v1/wall_lime.jpg',
      roughness: .88,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallMicrocement,
      name: 'Микроцемент · тёплый серый',
      category: 'Стены',
      color: Color(0xFF9C958A),
      pattern: 'concrete',
      textureAsset: 'assets/textures/generated_v1/wall_microcement.jpg',
      roughness: .82,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallRedClay,
      name: 'Красный кирпич · PBR',
      category: 'Стены',
      color: Color(0xFF9D5943),
      pattern: 'brick',
      textureAsset: 'assets/textures/generated_v1/wall_red_clay.jpg',
      roughness: .78,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallWhiteClay,
      name: 'Белёный кирпич',
      category: 'Стены',
      color: Color(0xFFD8D2C7),
      pattern: 'brick',
      textureAsset: 'assets/textures/generated_v1/wall_white_clay.jpg',
      roughness: .82,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallLinen,
      name: 'Льняные обои · натуральный бежевый',
      category: 'Стены',
      color: Color(0xFFBBA98D),
      textureAsset: 'assets/textures/generated_v1/wall_linen.jpg',
      roughness: .92,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.oakNaturalPbr,
      name: 'Дуб натуральный · PBR',
      category: 'Пол',
      color: Color(0xFFD0AD7D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_natural.png',
      roughness: .52,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.walnutPbr,
      name: 'Тёплый орех · PBR',
      category: 'Пол',
      color: Color(0xFF815A3D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_walnut.png',
      roughness: .50,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.marbleBiancoPbr,
      name: 'Мрамор светлый · PBR',
      category: 'Плитка',
      color: Color(0xFFE9E6E0),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_marble.png',
      roughness: .28,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.concreteWarmPbr,
      name: 'Бетон тёплый · PBR',
      category: 'Стены',
      color: Color(0xFFB9B2A8),
      pattern: 'concrete',
      textureAsset: 'assets/textures/concrete_soft.png',
      roughness: .86,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.plasterMineralPbr,
      name: 'Гипсовая штукатурка · PBR',
      category: 'Стены',
      color: Color(0xFFD2C7B6),
      pattern: 'concrete',
      textureAsset: 'assets/textures/plaster_warm.png',
      roughness: .88,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.graphiteTilePbr,
      name: 'Керамогранит графит · PBR',
      category: 'Плитка',
      color: Color(0xFF696D70),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_graphite.png',
      roughness: .43,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.runtimeTileConcreteLight,
      name: 'Бетон светлый · PBR',
      category: 'Плитка',
      color: Color(0xFFB8B9B7),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_concrete.png',
      roughness: .55,
    ),
  ];

  static const presets = <VisualMaterialPreset>[
    ...runtimeV4,
    ...generatedV1,
    VisualMaterialPreset(
      id: 'oak-natural',
      name: 'Дуб натуральный',
      category: 'Пол',
      color: Color(0xFFD0AD7D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_natural.png',
      roughness: .52,
    ),
    VisualMaterialPreset(
      id: 'oak-smoked',
      name: 'Дуб дымчатый',
      category: 'Пол',
      color: Color(0xFF947152),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_smoked.png',
      roughness: .56,
    ),
    VisualMaterialPreset(
      id: 'walnut',
      name: 'Орех',
      category: 'Пол',
      color: Color(0xFF815A3D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_walnut.png',
      roughness: .50,
    ),
    VisualMaterialPreset(
      id: 'spc-grey',
      name: 'SPC серый дуб',
      category: 'Пол',
      color: Color(0xFFAAA49B),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_spc_grey.png',
      roughness: .58,
    ),
    VisualMaterialPreset(
      id: 'oak-light',
      name: 'Дуб белёный',
      category: 'Пол',
      color: Color(0xFFE1D2BA),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_light.png',
      roughness: .58,
    ),
    VisualMaterialPreset(
      id: 'oak-honey',
      name: 'Дуб медовый',
      category: 'Пол',
      color: Color(0xFFC8904F),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_honey.png',
      roughness: .50,
    ),
    VisualMaterialPreset(
      id: 'ash-natural',
      name: 'Ясень натуральный',
      category: 'Пол',
      color: Color(0xFFD5C3A4),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_ash_natural.png',
      roughness: .60,
    ),
    VisualMaterialPreset(
      id: 'laminate-wenge',
      name: 'Венге',
      category: 'Пол',
      color: Color(0xFF574034),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_wenge.png',
      roughness: .54,
    ),
    VisualMaterialPreset(
      id: 'tile-light-stone',
      name: 'Керамогранит светлый камень',
      category: 'Плитка',
      color: Color(0xFFDADDD8),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_light_stone.png',
      roughness: .39,
    ),
    VisualMaterialPreset(
      id: 'tile-concrete',
      name: 'Керамогранит бетон',
      category: 'Плитка',
      color: Color(0xFFB8B9B7),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_concrete.png',
      roughness: .55,
    ),
    VisualMaterialPreset(
      id: 'tile-marble',
      name: 'Керамогранит мрамор',
      category: 'Плитка',
      color: Color(0xFFE9E6E0),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_marble.png',
      roughness: .28,
    ),
    VisualMaterialPreset(
      id: 'tile-dark',
      name: 'Керамогранит графит',
      category: 'Плитка',
      color: Color(0xFF696D70),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_graphite.png',
      roughness: .43,
    ),
    VisualMaterialPreset(
      id: 'tile-travertine',
      name: 'Травертин',
      category: 'Плитка',
      color: Color(0xFFD2C0A2),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_travertine.png',
      roughness: .56,
    ),
    VisualMaterialPreset(
      id: 'tile-terrazzo',
      name: 'Терраццо',
      category: 'Плитка',
      color: Color(0xFFD1CEC5),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_terrazzo.png',
      roughness: .48,
    ),
    VisualMaterialPreset(
      id: 'tile-sand',
      name: 'Керамогранит песочный',
      category: 'Плитка',
      color: Color(0xFFD6C1A2),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_sand.png',
      roughness: .50,
    ),
    VisualMaterialPreset(
      id: 'tile-emerald',
      name: 'Плитка зелёная',
      category: 'Плитка',
      color: Color(0xFF507268),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_emerald.png',
      roughness: .35,
    ),
    VisualMaterialPreset(
      id: 'paint-warm-white',
      name: 'Краска тёплый белый',
      category: 'Стены',
      color: Color(0xFFF2EFE8),
    ),
    VisualMaterialPreset(
      id: 'paint-cool-white',
      name: 'Краска холодный белый',
      category: 'Стены',
      color: Color(0xFFF2F5F7),
    ),
    VisualMaterialPreset(
      id: 'paint-sage',
      name: 'Краска шалфей',
      category: 'Стены',
      color: Color(0xFFC9D2C6),
    ),
    VisualMaterialPreset(
      id: 'paint-greige',
      name: 'Краска грейдж',
      category: 'Стены',
      color: Color(0xFFD4CCC0),
    ),
    VisualMaterialPreset(
      id: 'paint-olive',
      name: 'Краска оливковая',
      category: 'Стены',
      color: Color(0xFFB5BBA6),
    ),
    VisualMaterialPreset(
      id: 'paint-clay',
      name: 'Краска терракота',
      category: 'Стены',
      color: Color(0xFFD1A38F),
    ),
    VisualMaterialPreset(
      id: 'paint-blue',
      name: 'Краска пыльно-голубая',
      category: 'Стены',
      color: Color(0xFFB4C5CB),
    ),
    VisualMaterialPreset(
      id: 'paint-graphite',
      name: 'Краска графит',
      category: 'Стены',
      color: Color(0xFF555B5E),
    ),
    VisualMaterialPreset(
      id: 'paint-sand',
      name: 'Краска песочная',
      category: 'Стены',
      color: Color(0xFFD8C8AF),
    ),
    VisualMaterialPreset(
      id: 'plaster-sand',
      name: 'Декоративная штукатурка',
      category: 'Стены',
      color: Color(0xFFD2C7B6),
      pattern: 'concrete',
      textureAsset: 'assets/textures/plaster_warm.png',
      roughness: .88,
    ),
    VisualMaterialPreset(
      id: 'concrete-raw',
      name: 'Бетон',
      category: 'Стены',
      color: Color(0xFFC4C6C7),
      pattern: 'concrete',
      textureAsset: 'assets/textures/concrete_soft.png',
      roughness: .90,
    ),
    VisualMaterialPreset(
      id: 'brick-red',
      name: 'Кирпич',
      category: 'Стены',
      color: Color(0xFFC98672),
      pattern: 'brick',
      textureAsset: 'assets/textures/brick_red.png',
      roughness: .90,
    ),
  ];

  static VisualMaterialPreset byId(String id) =>
      presets.firstWhere((e) => e.id == id, orElse: () => generatedV1.first);

  static List<VisualMaterialPreset> forCategory(String category) =>
      presets.where((e) => e.category == category).toList(growable: false);

  static List<VisualMaterialPreset> get floorFinishes => presets
      .where((e) => e.category == 'Пол' || e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get wallFinishes => presets
      .where((e) => e.category == 'Стены' || e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get tileFinishes =>
      presets.where((e) => e.category == 'Плитка').toList(growable: false);

  static List<VisualMaterialPreset> get paintFinishes => presets
      .where(
        (e) =>
            e.id.startsWith('paint-') || e.id == GeneratedMaterialIds.wallPaint,
      )
      .toList(growable: false);

  /// Curated catalog shown by the new phone Materials page.
  ///
  /// Legacy presets stay available through [byId] so old projects keep
  /// rendering, but users no longer have to wade through near-identical
  /// duplicate finishes that only differ by baked-in color.
  static const masterUiIds = <String>[
    GeneratedMaterialIds.runtimeV4WallPaintMatteWhite,
    GeneratedMaterialIds.wallMicrocement,
    GeneratedMaterialIds.runtimeV4WallGypsumPlaster,
    GeneratedMaterialIds.concreteWarmPbr,
    GeneratedMaterialIds.runtimeV4TileMarbleLight,
    GeneratedMaterialIds.runtimeV4TileTerrazzoLight,
    GeneratedMaterialIds.runtimeV4LaminateOakSmoked,
    GeneratedMaterialIds.runtimeV4LaminateOakLight,
  ];

  static List<VisualMaterialPreset> get masterUiPresets => masterUiIds
      .map(byId)
      .toList(growable: false);

  static List<VisualMaterialPreset> get masterWallFinishes => masterUiPresets
      .where((e) => e.category == 'Стены' || e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get masterFloorFinishes => masterUiPresets
      .where((e) => e.category == 'Пол' || e.category == 'Плитка')
      .toList(growable: false);
}
