import 'dart:math' as math;

/// Shared camera gesture convention for all ZAMER 3D surfaces.
///
/// Flutter reports a left swipe as a negative [deltaX]. In the renderer a
/// positive yaw turns the view to the left, so horizontal screen movement must
/// be inverted. Keeping this in one place prevents Walk, Orbit and Photo from
/// drifting back to opposite gesture directions.
abstract final class CameraGesturePolicy {
  /// A single bad pointer sample must not spin the camera by several turns.
  /// Normal Flutter gesture deltas are far below this limit, so regular swipes
  /// keep their full response while pathological spikes are contained.
  static const double maxDeltaPixels = 240.0;

  static double applyHorizontalSwipe({
    required double yaw,
    required double deltaX,
    required double sensitivity,
  }) {
    final safeYaw = yaw.isFinite ? yaw : 0.0;
    if (!deltaX.isFinite || !sensitivity.isFinite || sensitivity <= 0) {
      return _normalize(safeYaw);
    }

    final safeDelta = deltaX
        .clamp(-maxDeltaPixels, maxDeltaPixels)
        .toDouble();
    return _normalize(safeYaw - safeDelta * sensitivity);
  }

  static double _normalize(double angle) =>
      math.atan2(math.sin(angle), math.cos(angle));
}
