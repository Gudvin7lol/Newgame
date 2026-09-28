import 'package:flutter/material.dart';

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
  static const presets = <VisualMaterialPreset>[
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
      presets.firstWhere((e) => e.id == id, orElse: () => presets.first);

  static List<VisualMaterialPreset> forCategory(String category) =>
      presets.where((e) => e.category == category).toList(growable: false);

  static List<VisualMaterialPreset> get floorFinishes => presets
      .where((e) => e.category == 'Пол' || e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get wallFinishes => presets
      .where((e) => e.category == 'Стены' || e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get tileFinishes => presets
      .where((e) => e.category == 'Плитка')
      .toList(growable: false);

  static List<VisualMaterialPreset> get paintFinishes => presets
      .where((e) => e.id.startsWith('paint-'))
      .toList(growable: false);
}
