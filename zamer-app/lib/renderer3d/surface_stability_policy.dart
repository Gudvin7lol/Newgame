import '../services/object_catalog.dart';
import 'floor_grout_geometry.dart';

/// Small, explicit separations that keep coplanar GPU surfaces from fighting.
///
/// Source geometry remains in real millimetres. These offsets exist only at
/// the renderer boundary, where mobile depth buffers need a little breathing
/// room between the wall core/finish and between the floor mesh and floor-
/// mounted GLBs.
class ZamerSurfaceStabilityPolicy {
  const ZamerSurfaceStabilityPolicy._();

  /// 0.5 mm was visibly unstable at shallow angles on several mobile GPUs.
  /// Two millimetres is still visually negligible but gives the depth buffer a
  /// reliable separation between the wall core and its decorative finish.
  static const double wallFinishGapM = 0.002;

  /// Keeps imported floor objects above both the zero-thickness finish mesh
  /// and the 2 mm grout/seam overlay. The object model is already rebased to
  /// its lowest local bound, so this is renderer-only anti-z-fighting space,
  /// not a change to measured height. Three millimetres leaves the lowest
  /// imported bound about 1 mm above the grout overlay on mobile depth buffers.
  static const double floorObjectClearanceM = 0.003;

  static double objectBaseYM({
    required CatalogMount mount,
    required double elevationMm,
  }) {
    final safeElevationM = elevationMm.isFinite && elevationMm > 0
        ? elevationMm / 1000
        : 0.0;
    if (mount != CatalogMount.floor) return safeElevationM;
    return zamerFloorSurfaceYM + floorObjectClearanceM + safeElevationM;
  }
}
