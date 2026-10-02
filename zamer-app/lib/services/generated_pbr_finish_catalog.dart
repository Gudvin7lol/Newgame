import 'generated_material_ids.dart';

class GeneratedPbrFinish {
  const GeneratedPbrFinish({
    required this.baseColorAsset,
    required this.normalAsset,
    required this.heightAsset,
    required this.metallicRoughnessAsset,
    required this.realWorldTileMm,
    required this.normalScale,
  });

  final String baseColorAsset;
  final String normalAsset;
  final String heightAsset;
  final String metallicRoughnessAsset;

  /// Physical width/height represented by one UV repeat. Keeping this value in
  /// millimetres lets the renderer preserve believable material scale instead
  /// of stretching one bitmap across a complete room surface.
  final double realWorldTileMm;

  /// Tangent-space normal strength consumed by flutter_scene.
  final double normalScale;
}

abstract final class GeneratedPbrFinishCatalog {
  static const _root = 'assets/textures/generated_v1';

  static const byMaterialId = <String, GeneratedPbrFinish>{
    GeneratedMaterialIds.darkOak: GeneratedPbrFinish(
      baseColorAsset: '$_root/dark_oak.jpg',
      normalAsset: '$_root/dark_oak_normal.png',
      heightAsset: '$_root/dark_oak_height.png',
      metallicRoughnessAsset: '$_root/dark_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.5,
    ),
    GeneratedMaterialIds.whiteOak: GeneratedPbrFinish(
      baseColorAsset: '$_root/white_oak.jpg',
      normalAsset: '$_root/white_oak_normal.png',
      heightAsset: '$_root/white_oak_height.png',
      metallicRoughnessAsset: '$_root/white_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.4,
    ),
    GeneratedMaterialIds.travertine: GeneratedPbrFinish(
      baseColorAsset: '$_root/travertine.jpg',
      normalAsset: '$_root/travertine_normal.png',
      heightAsset: '$_root/travertine_height.png',
      metallicRoughnessAsset: '$_root/travertine_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: 3.2,
    ),
    GeneratedMaterialIds.terrazzo: GeneratedPbrFinish(
      baseColorAsset: '$_root/terrazzo.jpg',
      normalAsset: '$_root/terrazzo_normal.png',
      heightAsset: '$_root/terrazzo_height.png',
      metallicRoughnessAsset: '$_root/terrazzo_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: 2.2,
    ),
    GeneratedMaterialIds.slate: GeneratedPbrFinish(
      baseColorAsset: '$_root/slate.jpg',
      normalAsset: '$_root/slate_normal.png',
      heightAsset: '$_root/slate_height.png',
      metallicRoughnessAsset: '$_root/slate_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: 4.0,
    ),
    GeneratedMaterialIds.terracotta: GeneratedPbrFinish(
      baseColorAsset: '$_root/terracotta.jpg',
      normalAsset: '$_root/terracotta_normal.png',
      heightAsset: '$_root/terracotta_height.png',
      metallicRoughnessAsset: '$_root/terracotta_metallic_roughness.png',
      realWorldTileMm: 300,
      normalScale: 3.4,
    ),
    GeneratedMaterialIds.wallPaint: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_paint.jpg',
      normalAsset: '$_root/wall_paint_normal.png',
      heightAsset: '$_root/wall_paint_height.png',
      metallicRoughnessAsset: '$_root/wall_paint_metallic_roughness.png',
      realWorldTileMm: 900,
      normalScale: 0.75,
    ),
    GeneratedMaterialIds.wallLime: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_lime.jpg',
      normalAsset: '$_root/wall_lime_normal.png',
      heightAsset: '$_root/wall_lime_height.png',
      metallicRoughnessAsset: '$_root/wall_lime_metallic_roughness.png',
      realWorldTileMm: 900,
      normalScale: 2.7,
    ),
    GeneratedMaterialIds.wallMicrocement: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_microcement.jpg',
      normalAsset: '$_root/wall_microcement_normal.png',
      heightAsset: '$_root/wall_microcement_height.png',
      metallicRoughnessAsset: '$_root/wall_microcement_metallic_roughness.png',
      realWorldTileMm: 1000,
      normalScale: 2.2,
    ),
    GeneratedMaterialIds.wallRedClay: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_red_clay.jpg',
      normalAsset: '$_root/wall_red_clay_normal.png',
      heightAsset: '$_root/wall_red_clay_height.png',
      metallicRoughnessAsset: '$_root/wall_red_clay_metallic_roughness.png',
      realWorldTileMm: 1000,
      normalScale: 4.4,
    ),
    GeneratedMaterialIds.wallWhiteClay: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_white_clay.jpg',
      normalAsset: '$_root/wall_white_clay_normal.png',
      heightAsset: '$_root/wall_white_clay_height.png',
      metallicRoughnessAsset: '$_root/wall_white_clay_metallic_roughness.png',
      realWorldTileMm: 1000,
      normalScale: 4.1,
    ),
    GeneratedMaterialIds.wallLinen: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_linen.jpg',
      normalAsset: '$_root/wall_linen_normal.png',
      heightAsset: '$_root/wall_linen_height.png',
      metallicRoughnessAsset: '$_root/wall_linen_metallic_roughness.png',
      realWorldTileMm: 700,
      normalScale: 3.2,
    ),
    GeneratedMaterialIds.oakNaturalPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/floor_oak_natural.png',
      normalAsset: '$_root/white_oak_normal.png',
      heightAsset: '$_root/white_oak_height.png',
      metallicRoughnessAsset: '$_root/white_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.1,
    ),
    GeneratedMaterialIds.walnutPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/floor_walnut.png',
      normalAsset: '$_root/dark_oak_normal.png',
      heightAsset: '$_root/dark_oak_height.png',
      metallicRoughnessAsset: '$_root/dark_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.0,
    ),
    GeneratedMaterialIds.marbleBiancoPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/tile_marble.png',
      normalAsset: '$_root/terrazzo_normal.png',
      heightAsset: '$_root/terrazzo_height.png',
      metallicRoughnessAsset: '$_root/terrazzo_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: .55,
    ),
    GeneratedMaterialIds.concreteWarmPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/concrete_soft.png',
      normalAsset: '$_root/wall_microcement_normal.png',
      heightAsset: '$_root/wall_microcement_height.png',
      metallicRoughnessAsset: '$_root/wall_microcement_metallic_roughness.png',
      realWorldTileMm: 1000,
      normalScale: 1.8,
    ),
    GeneratedMaterialIds.plasterMineralPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/plaster_warm.png',
      normalAsset: '$_root/wall_lime_normal.png',
      heightAsset: '$_root/wall_lime_height.png',
      metallicRoughnessAsset: '$_root/wall_lime_metallic_roughness.png',
      realWorldTileMm: 900,
      normalScale: 2.4,
    ),
    GeneratedMaterialIds.graphiteTilePbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/tile_graphite.png',
      normalAsset: '$_root/slate_normal.png',
      heightAsset: '$_root/slate_height.png',
      metallicRoughnessAsset: '$_root/slate_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: 2.4,
    ),
  };

  /// Older projects store the original material IDs. Reusing the same PBR
  /// channels for those IDs upgrades existing rooms in place instead of
  /// requiring the user to re-apply every finish after an app update.
  static const legacyAliases = <String, String>{
    'oak-natural': GeneratedMaterialIds.oakNaturalPbr,
    'oak-smoked': GeneratedMaterialIds.darkOak,
    'walnut': GeneratedMaterialIds.walnutPbr,
    'spc-grey': GeneratedMaterialIds.whiteOak,
    'oak-light': GeneratedMaterialIds.whiteOak,
    'oak-honey': GeneratedMaterialIds.whiteOak,
    'ash-natural': GeneratedMaterialIds.whiteOak,
    'laminate-wenge': GeneratedMaterialIds.darkOak,
    'tile-light-stone': GeneratedMaterialIds.travertine,
    'tile-concrete': GeneratedMaterialIds.wallMicrocement,
    'tile-marble': GeneratedMaterialIds.marbleBiancoPbr,
    'tile-dark': GeneratedMaterialIds.graphiteTilePbr,
    'tile-travertine': GeneratedMaterialIds.travertine,
    'tile-terrazzo': GeneratedMaterialIds.terrazzo,
    'tile-sand': GeneratedMaterialIds.terracotta,
    'tile-emerald': GeneratedMaterialIds.slate,
    'paint-warm-white': GeneratedMaterialIds.wallPaint,
    'paint-cool-white': GeneratedMaterialIds.wallPaint,
    'paint-sage': GeneratedMaterialIds.wallPaint,
    'paint-greige': GeneratedMaterialIds.wallPaint,
    'paint-olive': GeneratedMaterialIds.wallPaint,
    'paint-clay': GeneratedMaterialIds.wallPaint,
    'paint-blue': GeneratedMaterialIds.wallPaint,
    'paint-graphite': GeneratedMaterialIds.wallPaint,
    'paint-sand': GeneratedMaterialIds.wallPaint,
    'plaster-sand': GeneratedMaterialIds.plasterMineralPbr,
    'concrete-raw': GeneratedMaterialIds.concreteWarmPbr,
    'brick-red': GeneratedMaterialIds.wallRedClay,
  };

  static GeneratedPbrFinish? byId(String materialId) {
    final direct = byMaterialId[materialId];
    if (direct != null) return direct;
    final alias = legacyAliases[materialId];
    return alias == null ? null : byMaterialId[alias];
  }
}
