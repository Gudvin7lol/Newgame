import 'generated_material_ids.dart';

/// Stable app-facing IDs for SourcePack v3 materials. The uploaded package is
/// a reference pack, so these IDs resolve to existing runtime_v2 PBR profiles
/// instead of pretending the source sheets are production textures.
abstract final class NewMaterialAliasCatalog {
  static const runtimeBySourceId = <String, String>{
    'Wall_Brick_Red_01': GeneratedMaterialIds.wallRedClay,
    'Wall_GypsumPlaster_White_01': GeneratedMaterialIds.plasterMineralPbr,
    'Wall_Paint_MatteWhite_01': GeneratedMaterialIds.wallPaint,
    'Tile_ConcreteLight_01': GeneratedMaterialIds.runtimeTileConcreteLight,
    'Tile_MarbleLight_01': GeneratedMaterialIds.marbleBiancoPbr,
    'Tile_TerrazzoLight_01': GeneratedMaterialIds.terrazzo,
    'Laminate_OakLight_01': GeneratedMaterialIds.whiteOak,
    'Laminate_WalnutWarm_01': GeneratedMaterialIds.walnutPbr,
    'Laminate_OakSmoked_01': GeneratedMaterialIds.darkOak,
  };

  static String? runtimeIdFor(String sourceId) => runtimeBySourceId[sourceId];
}
