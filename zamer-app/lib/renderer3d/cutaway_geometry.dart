import 'dart:math' as math;

/// Returns whether a wall centre-line segment lies in the camera-side cutaway
/// corridor between [target] and [camera].
///
/// The corridor is perspective-shaped rather than a constant-width strip. It
/// keeps a small focus zone around the orbit target, then widens towards the
/// camera. This avoids hiding unrelated side walls while still cutting walls
/// that genuinely enter the user's line of sight.
bool zamerWallSegmentOccludesCutaway({
  required math.Point<double> start,
  required math.Point<double> end,
  required math.Point<double> target,
  required math.Point<double> camera,
  required double corridorHalfWidth,
  double targetClearance = 0.08,
  double cameraFraction = 0.92,
  double lateralMargin = 0.25,
  double wallHalfThickness = 0.0,
}) {
  final cameraDx = camera.x - target.x;
  final cameraDy = camera.y - target.y;
  final cameraDistance = math.sqrt(cameraDx * cameraDx + cameraDy * cameraDy);
  if (cameraDistance < 0.0001) return false;

  final dirX = cameraDx / cameraDistance;
  final dirY = cameraDy / cameraDistance;

  (double, double) project(math.Point<double> point) {
    final rx = point.x - target.x;
    final ry = point.y - target.y;
    final axial = rx * dirX + ry * dirY;
    final lateral = rx * dirY - ry * dirX;
    return (axial, lateral);
  }

  final a = project(start);
  final b = project(end);
  final minAxial = math.max(0.0, targetClearance);
  final maxAxial = cameraDistance * cameraFraction.clamp(0.0, 1.0);
  if (maxAxial <= minAxial) return false;

  var tMin = 0.0;
  var tMax = 1.0;
  final axialDelta = b.$1 - a.$1;
  if (axialDelta.abs() < 1e-9) {
    if (a.$1 <= minAxial || a.$1 >= maxAxial) return false;
  } else {
    final tAtMin = (minAxial - a.$1) / axialDelta;
    final tAtMax = (maxAxial - a.$1) / axialDelta;
    final intervalMin = math.min(tAtMin, tAtMax);
    final intervalMax = math.max(tAtMin, tAtMax);
    tMin = math.max(tMin, intervalMin);
    tMax = math.min(tMax, intervalMax);
    if (tMin > tMax) return false;
  }

  final lateralDelta = b.$2 - a.$2;
  double axialAt(double t) => a.$1 + axialDelta * t;
  double lateralAt(double t) => a.$2 + lateralDelta * t;

  bool insidePerspectiveCorridor(double t) {
    final axial = axialAt(t);
    if (axial <= minAxial || axial >= maxAxial) return false;

    final depthFraction = (axial / cameraDistance).clamp(0.0, 1.0).toDouble();
    final cameraSideHalfWidth = math.max(0.08, corridorHalfWidth);
    final focusHalfWidth = math.min(math.max(0.0, corridorHalfWidth), 0.24);
    final perspectiveHalfWidth = math.max(
      focusHalfWidth,
      cameraSideHalfWidth * depthFraction,
    );
    final allowedLateral =
        perspectiveHalfWidth +
        math.max(0.0, lateralMargin) +
        math.max(0.0, wallHalfThickness);
    return lateralAt(t).abs() < allowedLateral;
  }

  // |lateral| is piecewise linear. Check both clipped ends and an axis crossing.
  // This is deterministic, so rotating the camera cannot make visibility depend
  // on an arbitrary sampling step.
  if (insidePerspectiveCorridor(tMin) || insidePerspectiveCorridor(tMax)) {
    return true;
  }
  if (lateralDelta.abs() >= 1e-9) {
    final zeroT = -a.$2 / lateralDelta;
    if (zeroT >= tMin && zeroT <= tMax && insidePerspectiveCorridor(zeroT)) {
      return true;
    }
  }
  return false;
}
