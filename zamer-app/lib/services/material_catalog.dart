import 'package:flutter/material.dart';

class VisualMaterialPreset {
  const VisualMaterialPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    this.pattern = 'solid',
    this.textureAsset,
    this.textureAssetMobile,
    this.textureAssetPhoto,
    this.normalAsset,
    this.normalAssetMobile,
    this.normalAssetPhoto,
    this.metallicRoughnessAsset,
    this.metallicRoughnessAssetMobile,
    this.metallicRoughnessAssetPhoto,
    this.occlusionAsset,
    this.occlusionAssetMobile,
    this.occlusionAssetPhoto,
    this.roughness,
    this.normalScale = 1.0,
    this.occlusionStrength = 1.0,
    this.physicalWidthMm = 1000,
    this.physicalHeightMm = 1000,
  });

  final String id;
  final String name;
  final String category;
  final Color color;
  final String pattern;
  final String? textureAsset;
  final String? textureAssetMobile;
  final String? textureAssetPhoto;
  final String? normalAsset;
  final String? normalAssetMobile;
  final String? normalAssetPhoto;
  final String? metallicRoughnessAsset;
  final String? metallicRoughnessAssetMobile;
  final String? metallicRoughnessAssetPhoto;
  final String? occlusionAsset;
  final String? occlusionAssetMobile;
  final String? occlusionAssetPhoto;
  final double? roughness;

  String? textureFor({required bool mobile, bool photo = false}) => photo
      ? (textureAssetPhoto ?? textureAsset)
      : (mobile ? (textureAssetMobile ?? textureAsset) : textureAsset);
  String? normalFor({required bool mobile, bool photo = false}) => photo
      ? (normalAssetPhoto ?? normalAsset)
      : (mobile ? (normalAssetMobile ?? normalAsset) : normalAsset);
  String? metallicRoughnessFor({required bool mobile, bool photo = false}) =>
      photo
          ? (metallicRoughnessAssetPhoto ?? metallicRoughnessAsset)
          : (mobile
              ? (metallicRoughnessAssetMobile ?? metallicRoughnessAsset)
              : metallicRoughnessAsset);
  String? occlusionFor({required bool mobile, bool photo = false}) => photo
      ? (occlusionAssetPhoto ?? occlusionAsset)
      : (mobile ? (occlusionAssetMobile ?? occlusionAsset) : occlusionAsset);
  final double normalScale;
  final double occlusionStrength;
  final double physicalWidthMm;
  final double physicalHeightMm;
}

class MaterialCatalog {
  static const presets = <VisualMaterialPreset>[
    VisualMaterialPreset(
      id: 'PAINT_01',
      name: 'Универсальная краска',
      category: 'Стены',
      color: Color(0xFFEFEDE8),
      pattern: 'paint',
      textureAsset: 'assets/textures/pbr12/PAINT_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/PAINT_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/PAINT_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/PAINT_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/PAINT_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/PAINT_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/PAINT_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/PAINT_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/PAINT_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/PAINT_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/PAINT_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/PAINT_01/photo/orm.png',
      roughness: .80,
      normalScale: .18,
      occlusionStrength: .52,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'PLASTER_01',
      name: 'Гипсовая штукатурка',
      category: 'Стены',
      color: Color(0xFFDED8CF),
      pattern: 'plaster',
      textureAsset: 'assets/textures/pbr12/PLASTER_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/PLASTER_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/PLASTER_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/PLASTER_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/PLASTER_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/PLASTER_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/PLASTER_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/PLASTER_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/PLASTER_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/PLASTER_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/PLASTER_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/PLASTER_01/photo/orm.png',
      roughness: .82,
      normalScale: .30,
      occlusionStrength: .72,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'BRICK_01',
      name: 'Красный кирпич',
      category: 'Стены',
      color: Color(0xFFB86849),
      pattern: 'brick',
      textureAsset: 'assets/textures/pbr12/BRICK_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/BRICK_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/BRICK_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/BRICK_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/BRICK_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/BRICK_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/BRICK_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/BRICK_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/BRICK_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/BRICK_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/BRICK_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/BRICK_01/photo/orm.png',
      roughness: .76,
      normalScale: .60,
      occlusionStrength: .88,
      physicalWidthMm: 1040,
      physicalHeightMm: 900,
    ),
    VisualMaterialPreset(
      id: 'TILE_01',
      name: 'Светлый камень',
      category: 'Плитка',
      color: Color(0xFFD9CCB8),
      pattern: 'tile',
      textureAsset: 'assets/textures/pbr12/TILE_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/TILE_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/TILE_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/TILE_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/TILE_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/TILE_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/TILE_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/TILE_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/TILE_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/TILE_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/TILE_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/TILE_01/photo/orm.png',
      roughness: .56,
      normalScale: .22,
      occlusionStrength: .80,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'TILE_02',
      name: 'Бетонная плитка',
      category: 'Плитка',
      color: Color(0xFFB5B3AE),
      pattern: 'tile',
      textureAsset: 'assets/textures/pbr12/TILE_02/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/TILE_02/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/TILE_02/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/TILE_02/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/TILE_02/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/TILE_02/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/TILE_02/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/TILE_02/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/TILE_02/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/TILE_02/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/TILE_02/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/TILE_02/photo/orm.png',
      roughness: .66,
      normalScale: .28,
      occlusionStrength: .82,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'TILE_03',
      name: 'Светлый мрамор',
      category: 'Плитка',
      color: Color(0xFFE7E3DE),
      pattern: 'tile',
      textureAsset: 'assets/textures/pbr12/TILE_03/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/TILE_03/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/TILE_03/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/TILE_03/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/TILE_03/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/TILE_03/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/TILE_03/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/TILE_03/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/TILE_03/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/TILE_03/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/TILE_03/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/TILE_03/photo/orm.png',
      roughness: .34,
      normalScale: .10,
      occlusionStrength: .72,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'LAM_01',
      name: 'Натуральный дуб',
      category: 'Пол',
      color: Color(0xFFA77A4F),
      pattern: 'wood',
      textureAsset: 'assets/textures/pbr12/LAM_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/LAM_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/LAM_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/LAM_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/LAM_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/LAM_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/LAM_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/LAM_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/LAM_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/LAM_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/LAM_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/LAM_01/photo/orm.png',
      roughness: .58,
      normalScale: .35,
      occlusionStrength: .78,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'LAM_02',
      name: 'Светлый дуб',
      category: 'Пол',
      color: Color(0xFFC6A37D),
      pattern: 'wood',
      textureAsset: 'assets/textures/pbr12/LAM_02/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/LAM_02/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/LAM_02/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/LAM_02/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/LAM_02/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/LAM_02/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/LAM_02/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/LAM_02/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/LAM_02/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/LAM_02/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/LAM_02/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/LAM_02/photo/orm.png',
      roughness: .62,
      normalScale: .35,
      occlusionStrength: .76,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'LAM_03',
      name: 'Дымчатый серо-бежевый дуб',
      category: 'Пол',
      color: Color(0xFF928477),
      pattern: 'wood',
      textureAsset: 'assets/textures/pbr12/LAM_03/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/LAM_03/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/LAM_03/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/LAM_03/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/LAM_03/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/LAM_03/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/LAM_03/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/LAM_03/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/LAM_03/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/LAM_03/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/LAM_03/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/LAM_03/photo/orm.png',
      roughness: .60,
      normalScale: .35,
      occlusionStrength: .80,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'CONCRETE_01',
      name: 'Архитектурный бетон',
      category: 'Стены',
      color: Color(0xFFB8B8B4),
      pattern: 'concrete',
      textureAsset: 'assets/textures/pbr12/CONCRETE_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/CONCRETE_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/CONCRETE_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/CONCRETE_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/CONCRETE_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/CONCRETE_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/CONCRETE_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/CONCRETE_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/CONCRETE_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/CONCRETE_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/CONCRETE_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/CONCRETE_01/photo/orm.png',
      roughness: .69,
      normalScale: .34,
      occlusionStrength: .82,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'MARBLE_01',
      name: 'Натуральный мрамор',
      category: 'Плитка',
      color: Color(0xFFE6E3DF),
      pattern: 'tile',
      textureAsset: 'assets/textures/pbr12/MARBLE_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/MARBLE_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/MARBLE_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/MARBLE_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/MARBLE_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/MARBLE_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/MARBLE_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/MARBLE_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/MARBLE_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/MARBLE_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/MARBLE_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/MARBLE_01/photo/orm.png',
      roughness: .30,
      normalScale: .08,
      occlusionStrength: .68,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),
    VisualMaterialPreset(
      id: 'TRAVERTINE_01',
      name: 'Травертин натуральный',
      category: 'Плитка',
      color: Color(0xFFC7AD8C),
      pattern: 'tile',
      textureAsset: 'assets/textures/pbr12/TRAVERTINE_01/quality/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr12/TRAVERTINE_01/performance/basecolor.png',
      textureAssetPhoto: 'assets/textures/pbr12/TRAVERTINE_01/photo/basecolor.png',
      normalAsset: 'assets/textures/pbr12/TRAVERTINE_01/quality/normal.png',
      normalAssetMobile:
          'assets/textures/pbr12/TRAVERTINE_01/performance/normal.png',
      normalAssetPhoto: 'assets/textures/pbr12/TRAVERTINE_01/photo/normal.png',
      metallicRoughnessAsset:
          'assets/textures/pbr12/TRAVERTINE_01/quality/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr12/TRAVERTINE_01/performance/orm.png',
      metallicRoughnessAssetPhoto:
          'assets/textures/pbr12/TRAVERTINE_01/photo/orm.png',
      occlusionAsset: 'assets/textures/pbr12/TRAVERTINE_01/quality/orm.png',
      occlusionAssetMobile:
          'assets/textures/pbr12/TRAVERTINE_01/performance/orm.png',
      occlusionAssetPhoto: 'assets/textures/pbr12/TRAVERTINE_01/photo/orm.png',
      roughness: .64,
      normalScale: .42,
      occlusionStrength: .84,
      physicalWidthMm: 1000,
      physicalHeightMm: 1000,
    ),

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
      textureAsset: 'assets/textures/pbr/dark_oak/basecolor.png',
      textureAssetMobile: 'assets/textures/pbr/dark_oak/basecolor_mobile.png',
      normalAsset: 'assets/textures/pbr/dark_oak/normal.png',
      normalAssetMobile: 'assets/textures/pbr/dark_oak/normal_mobile.png',
      metallicRoughnessAsset: 'assets/textures/pbr/dark_oak/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr/dark_oak/orm_mobile.png',
      occlusionAsset: 'assets/textures/pbr/dark_oak/orm.png',
      occlusionAssetMobile: 'assets/textures/pbr/dark_oak/orm_mobile.png',
      roughness: .54,
      normalScale: .58,
      occlusionStrength: .82,
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
      textureAsset: 'assets/textures/pbr/ivory_tile/basecolor.png',
      textureAssetMobile:
          'assets/textures/pbr/ivory_tile/basecolor_mobile.png',
      normalAsset: 'assets/textures/pbr/ivory_tile/normal.png',
      normalAssetMobile: 'assets/textures/pbr/ivory_tile/normal_mobile.png',
      metallicRoughnessAsset: 'assets/textures/pbr/ivory_tile/orm.png',
      metallicRoughnessAssetMobile:
          'assets/textures/pbr/ivory_tile/orm_mobile.png',
      occlusionAsset: 'assets/textures/pbr/ivory_tile/orm.png',
      occlusionAssetMobile: 'assets/textures/pbr/ivory_tile/orm_mobile.png',
      roughness: .42,
      normalScale: .66,
      occlusionStrength: .86,
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
      pattern: 'paint',
      textureAsset: 'assets/textures/pbr/paint/basecolor.png',
      textureAssetMobile: 'assets/textures/pbr/paint/basecolor_mobile.png',
      normalAsset: 'assets/textures/pbr/paint/normal.png',
      normalAssetMobile: 'assets/textures/pbr/paint/normal_mobile.png',
      metallicRoughnessAsset: 'assets/textures/pbr/paint/orm.png',
      metallicRoughnessAssetMobile: 'assets/textures/pbr/paint/orm_mobile.png',
      occlusionAsset: 'assets/textures/pbr/paint/orm.png',
      occlusionAssetMobile: 'assets/textures/pbr/paint/orm_mobile.png',
      roughness: .82,
      normalScale: .34,
      occlusionStrength: .62,
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
      .where((e) => e.pattern == 'paint')
      .toList(growable: false);
}
