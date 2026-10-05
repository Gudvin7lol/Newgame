/// Vertical placement helpers shared by 3D object render paths.
///
/// Imported GLB models are rebased to their local minimum Y before the object
/// root elevation is applied. Primitive fallback cuboids, however, are centred
/// around their local origin, so they need an additional half-height lift or
/// they sink halfway through the floor.
double zamerFallbackObjectRenderedHeightM({required double heightMm}) {
  // Keep this contract identical to the fallback CuboidGeometry minimum size.
  // Invalid persisted dimensions must not propagate NaN/infinity into the GPU
  // transform, because one malformed catalogue object should never blank the
  // complete 3D scene.
  if (!heightMm.isFinite || heightMm < 50) return 0.05;
  return heightMm / 1000;
}

double zamerFallbackObjectLocalCenterYM({required double heightMm}) {
  return zamerFallbackObjectRenderedHeightM(heightMm: heightMm) / 2;
}

/// World-space centre used by compatibility renderers that do not keep object
/// elevation on a separate root node.
double zamerFallbackObjectCenterYM({
  required double heightMm,
  required double elevationMm,
}) {
  final safeElevationMm = elevationMm.isFinite ? elevationMm : 0.0;
  return safeElevationMm / 1000 +
      zamerFallbackObjectLocalCenterYM(heightMm: heightMm);
}
