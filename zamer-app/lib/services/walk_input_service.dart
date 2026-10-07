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

    final rawMagnitude = math.sqrt(x * x + y * y);
    final zone = deadZoneRadius.isFinite
        ? deadZoneRadius.clamp(0.0, 0.95).toDouble()
        : deadZone;
    if (rawMagnitude <= zone || rawMagnitude <= 0.000001) {
      return (forward: 0.0, sideways: 0.0);
    }

    // Clamp only the requested strength. Direction must be normalized with the
    // real vector length, otherwise a full diagonal stick (1, 1) becomes a
    // sqrt(2) speed boost and Walk Mode moves faster diagonally than forward.
    final magnitude = rawMagnitude.clamp(0.0, 1.0).toDouble();
    final strength = ((magnitude - zone) / (1.0 - zone))
        .clamp(0.0, 1.0)
        .toDouble();
    final nx = x / rawMagnitude;
    final ny = y / rawMagnitude;
    return (forward: -ny * strength, sideways: nx * strength);
  }
}
