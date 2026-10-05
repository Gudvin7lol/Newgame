import 'dart:math' as math;

/// Chooses the camera-side corridor in which walls may be hidden by Cutaway.
///
/// The old implementation used almost the complete horizontal view cone. In a
/// large room that cone becomes several metres wide, so unrelated side walls
/// disappear even though they do not block the orbit target. Cutaway should
/// instead remove only the central obstruction between camera and target.
class ZamerCutawayCorridorPolicy {
  const ZamerCutawayCorridorPolicy._();

  static const double minHalfWidthM = 0.65;
  static const double maxHalfWidthM = 1.35;
  static const double fallbackHalfWidthM = 0.85;
  static const double viewConeFraction = 0.45;

  static double halfWidth({
    required double cameraDistanceM,
    required double fovDegrees,
  }) {
    if (!cameraDistanceM.isFinite ||
        cameraDistanceM <= 0 ||
        !fovDegrees.isFinite) {
      return fallbackHalfWidthM;
    }
    final safeFov = fovDegrees.clamp(18.0, 90.0).toDouble();
    final halfFov = safeFov * math.pi / 360;
    final projected =
        math.tan(halfFov) * cameraDistanceM * viewConeFraction;
    return projected.clamp(minHalfWidthM, maxHalfWidthM).toDouble();
  }
}
