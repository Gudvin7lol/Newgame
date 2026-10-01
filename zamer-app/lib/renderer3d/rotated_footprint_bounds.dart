import 'dart:math' as math;

/// Half extents of a rotated plan-object footprint in millimetres.
///
/// The plan stores [widthMm]/[depthMm] in the object's local axes. Camera and
/// scene bounds need the axis-aligned world footprint after [rotationDeg] is
/// applied, otherwise long furniture can fall outside the calculated scene
/// frame when rotated.
({double halfX, double halfY}) zamerRotatedFootprintHalfExtentsMm({
  required double widthMm,
  required double depthMm,
  required double rotationDeg,
}) {
  final halfWidth = math.max(0.0, widthMm.abs()) / 2;
  final halfDepth = math.max(0.0, depthMm.abs()) / 2;
  final angle = rotationDeg * math.pi / 180;
  final c = math.cos(angle).abs();
  final s = math.sin(angle).abs();
  return (
    halfX: halfWidth * c + halfDepth * s,
    halfY: halfWidth * s + halfDepth * c,
  );
}
