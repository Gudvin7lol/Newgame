/// Vertical placement helpers shared by 3D object render paths.
///
/// Imported GLB models are rebased to their local minimum Y before the object
/// root elevation is applied. Primitive fallback cuboids, however, are centred
/// around their local origin, so they need an additional half-height lift or
/// they sink halfway through the floor.
double zamerFallbackObjectDimensionM({required double dimensionMm}) {
  // Keep this contract identical to the fallback CuboidGeometry minimum size.
  // Invalid persisted dimensions must not propagate NaN/infinity into GPU
  // geometry because one malformed catalogue object must not blank the scene.
  if (!dimensionMm.isFinite || dimensionMm < 50) return 0.05;
  return dimensionMm / 1000;
}

double zamerFallbackObjectRenderedWidthM({required double widthMm}) {
  return zamerFallbackObjectDimensionM(dimensionMm: widthMm);
}

double zamerFallbackObjectRenderedHeightM({required double heightMm}) {
  return zamerFallbackObjectDimensionM(dimensionMm: heightMm);
}

double zamerFallbackObjectRenderedDepthM({required double depthMm}) {
  return zamerFallbackObjectDimensionM(dimensionMm: depthMm);
}

double zamerFallbackObjectLocalCenterYM({required double heightMm}) {
  return zamerFallbackObjectRenderedHeightM(heightMm: heightMm) / 2;
}

/// Sanitised root elevation for GPU object nodes.
///
/// Persisted projects can contain malformed numeric values from older builds.
/// Keeping this policy beside the grounding helpers prevents NaN/infinity from
/// entering a scene transform and making otherwise valid geometry disappear.
double zamerObjectElevationM({required double elevationMm}) {
  if (!elevationMm.isFinite) return 0.0;
  return elevationMm / 1000;
}

/// World-space centre used by compatibility renderers that do not keep object
/// elevation on a separate root node.
double zamerFallbackObjectCenterYM({
  required double heightMm,
  required double elevationMm,
}) {
  return zamerObjectElevationM(elevationMm: elevationMm) +
      zamerFallbackObjectLocalCenterYM(heightMm: heightMm);
}