import 'generated_material_ids.dart';

/// Stable runtime IDs used by the user-supplied ZAMER SourcePack v3.
///
/// The uploaded package contains photorealistic source/reference sheets rather
/// than standalone 2K runtime maps. Each family therefore reuses the matching
/// validated production PBR ID already bundled with the app. Saved projects do
/// not need a migration when dedicated 2K exports replace those runtime maps.
abstract final class SourcePackV3MaterialIds {
  static const laminateOakLight = GeneratedMaterialIds.whiteOak;
  static const laminateWalnutWarm = GeneratedMaterialIds.walnutPbr;
  static const laminateOakSmoked = GeneratedMaterialIds.darkOak;
  static const tileConcreteLight = GeneratedMaterialIds.runtimeTileConcreteLight;
  static const tileMarbleLight = GeneratedMaterialIds.marbleBiancoPbr;
  static const tileTerrazzoLight = GeneratedMaterialIds.terrazzo;
  static const wallBrickRed = GeneratedMaterialIds.wallRedClay;
  static const wallGypsumPlasterWhite = GeneratedMaterialIds.plasterMineralPbr;
  static const wallPaintMatteWhite = GeneratedMaterialIds.wallPaint;

  static const all = <String>{
    laminateOakLight,
    laminateWalnutWarm,
    laminateOakSmoked,
    tileConcreteLight,
    tileMarbleLight,
    tileTerrazzoLight,
    wallBrickRed,
    wallGypsumPlasterWhite,
    wallPaintMatteWhite,
  };
}
