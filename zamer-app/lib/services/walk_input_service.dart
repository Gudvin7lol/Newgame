import 'dart:math' as math;

/// Converts the normalized virtual-stick displacement into camera-relative
/// movement input. The stick already carries its own magnitude, so applying the
/// magnitude twice makes low-speed movement feel artificially sluggish.
class WalkInputService {
  const WalkInputService._();

  static const double deadZone = 0.08;

  static ({double forward, double sideways}) fromStick(
    double x,
    double y, {
    double deadZoneRadius = deadZone,
  }) {
    if (!x.isFinite || !y.isFinite) {
      return (forward: 0.0, sideways: 0.0);
    }
    final magnitude = math.sqrt(x * x + y * y).clamp(0.0, 1.0).toDouble();
    final zone = deadZoneRadius.clamp(0.0, 0.95).toDouble();
    if (magnitude <= zone || magnitude <= 0.000001) {
      return (forward: 0.0, sideways: 0.0);
    }

    // Remove the dead zone, then keep a linear response up to full travel.
    final strength = ((magnitude - zone) / (1.0 - zone))
        .clamp(0.0, 1.0)
        .toDouble();
    final nx = x / magnitude;
    final ny = y / magnitude;
    return (forward: -ny * strength, sideways: nx * strength);
  }
}
