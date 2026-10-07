/// Converts triangle indices produced from a counter-clockwise plan polygon
/// in XY into front-facing floor triangles in the renderer's XZ plane.
///
/// Zamer maps plan X -> GPU X and plan Y -> GPU +Z. That mapping reverses the
/// handedness of a polygon: a CCW triangle in plan space has a -Y geometric
/// normal after it is laid on XZ. Reversing each triangle restores +Y, so PBR
/// lighting, culling, shadows and texture shading all agree on the floor face.
List<int> floorFacingTriangleIndices(List<int> planarCcwIndices) {
  if (planarCcwIndices.length % 3 != 0) {
    throw ArgumentError.value(
      planarCcwIndices.length,
      'planarCcwIndices.length',
      'Triangle index lists must contain a multiple of three entries',
    );
  }
  final result = <int>[];
  for (var i = 0; i < planarCcwIndices.length; i += 3) {
    result.addAll(<int>[
      planarCcwIndices[i + 2],
      planarCcwIndices[i + 1],
      planarCcwIndices[i],
    ]);
  }
  return result;
}
