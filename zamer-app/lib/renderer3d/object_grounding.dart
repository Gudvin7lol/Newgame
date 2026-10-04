/// Vertical placement helpers shared by 3D object render paths.
///
/// Imported GLB models are rebased to their local minimum Y before the object
/// root elevation is applied. Primitive fallback cuboids, however, are centred
/// around their local origin, so they need an additional half-height lift or
/// they sink halfway through the floor.
double zamerFallbackObjectCenterYM({
  required double heightMm,
  required double elevationMm,
}) {
  final safeHeightMm = heightMm < 50 ? 50.0 : heightMm;
  return elevationMm / 1000 + safeHeightMm / 2000;
}
