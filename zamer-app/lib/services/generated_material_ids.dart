/// IDs for the generated ZAMER material packs bundled with the app.
abstract final class GeneratedMaterialIds {
  static const darkOak = 'zamer-dark-oak';
  static const whiteOak = 'zamer-white-oak';
  static const travertine = 'zamer-travertine';
  static const terrazzo = 'zamer-terrazzo';
  static const slate = 'zamer-slate';
  static const terracotta = 'zamer-terracotta';
  static const wallPaint = 'zamer-wall-paint';
  static const wallLime = 'zamer-wall-lime';
  static const wallMicrocement = 'zamer-wall-microcement';
  static const wallRedClay = 'zamer-wall-red-clay';
  static const wallWhiteClay = 'zamer-wall-white-clay';
  static const wallLinen = 'zamer-wall-linen';
  static const oakNaturalPbr = 'zamer-oak-natural-pbr';
  static const walnutPbr = 'zamer-walnut-pbr';
  static const marbleBiancoPbr = 'zamer-marble-bianco-pbr';
  static const concreteWarmPbr = 'zamer-concrete-warm-pbr';
  static const plasterMineralPbr = 'zamer-plaster-mineral-pbr';
  static const graphiteTilePbr = 'zamer-graphite-tile-pbr';

  /// Runtime 2K material introduced by the optimized v2 material pack. It is
  /// intentionally separate from wallMicrocement so existing wall finishes do
  /// not inherit the porcelain-tile normal/roughness response.
  static const runtimeTileConcreteLight = 'zamer-runtime-tile-concrete-light';

  static const runtimeV4WallBrickRed = 'Wall_Brick_Red_01';
  static const runtimeV4WallGypsumPlaster = 'Wall_GypsumPlaster_White_01';
  static const runtimeV4WallPaintMatteWhite = 'Wall_Paint_MatteWhite_01';
  static const runtimeV4TileConcreteLight = 'Tile_ConcreteLight_01';
  static const runtimeV4TileMarbleLight = 'Tile_MarbleLight_01';
  static const runtimeV4TileTerrazzoLight = 'Tile_TerrazzoLight_01';
  static const runtimeV4LaminateOakLight = 'Laminate_OakLight_01';
  static const runtimeV4LaminateOakSmoked = 'Laminate_OakSmoked_01';
  static const runtimeV4LaminateWalnutWarm = 'Laminate_WalnutWarm_01';

  static const runtimeV4 = <String>{
    runtimeV4WallBrickRed,
    runtimeV4WallGypsumPlaster,
    runtimeV4WallPaintMatteWhite,
    runtimeV4TileConcreteLight,
    runtimeV4TileMarbleLight,
    runtimeV4TileTerrazzoLight,
    runtimeV4LaminateOakLight,
    runtimeV4LaminateOakSmoked,
    runtimeV4LaminateWalnutWarm,
  };

  static const all = <String>{
    darkOak,
    whiteOak,
    travertine,
    terrazzo,
    slate,
    terracotta,
    wallPaint,
    wallLime,
    wallMicrocement,
    wallRedClay,
    wallWhiteClay,
    wallLinen,
    oakNaturalPbr,
    walnutPbr,
    marbleBiancoPbr,
    concreteWarmPbr,
    plasterMineralPbr,
    graphiteTilePbr,
    runtimeTileConcreteLight,
    ...runtimeV4,
  };
}
