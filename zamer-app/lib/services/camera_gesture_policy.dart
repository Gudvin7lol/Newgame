import 'dart:math' as math;

/// Shared camera gesture convention for all ZAMER 3D surfaces.
///
/// Flutter reports a left swipe as a negative [deltaX]. In the renderer a
/// positive yaw turns the view to the left, so horizontal screen movement must
/// be inverted. Keeping this in one place prevents Walk, Orbit and Photo from
/// drifting back to opposite gesture directions.
abstract final class CameraGesturePolicy {
  static double applyHorizontalSwipe({
    required double yaw,
    required double deltaX,
    required double sensitivity,
  }) {
    final angle = yaw - deltaX * sensitivity;
    return math.atan2(math.sin(angle), math.cos(angle));
  }
}
