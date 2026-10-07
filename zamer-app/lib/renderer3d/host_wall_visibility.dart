class ZamerHostWallSegment {
  const ZamerHostWallSegment({
    required this.wallId,
    required this.startX,
    required this.startZ,
    required this.endX,
    required this.endZ,
    required this.visible,
  });

  final String wallId;
  final double startX;
  final double startZ;
  final double endX;
  final double endZ;
  final bool visible;
}

/// Returns the cutaway visibility for an object hosted by a wall.
///
/// A wall may be split into multiple render pieces around doors/windows. The
/// hosted object follows the nearest piece of its own logical wall rather than
/// any arbitrary piece with the same wall id. Unhosted or unresolved objects
/// stay visible so incomplete legacy data never makes content disappear.
bool zamerHostedWallVisualVisible({
  required String? wallId,
  required double x,
  required double z,
  required Iterable<ZamerHostWallSegment> segments,
}) {
  if (wallId == null || wallId.isEmpty) return true;

  ZamerHostWallSegment? nearest;
  var bestDistanceSquared = double.infinity;
  for (final segment in segments) {
    if (segment.wallId != wallId) continue;
    final distanceSquared = _pointSegmentDistanceSquared(
      x: x,
      z: z,
      ax: segment.startX,
      az: segment.startZ,
      bx: segment.endX,
      bz: segment.endZ,
    );
    if (distanceSquared < bestDistanceSquared) {
      bestDistanceSquared = distanceSquared;
      nearest = segment;
    }
  }
  return nearest?.visible ?? true;
}

double _pointSegmentDistanceSquared({
  required double x,
  required double z,
  required double ax,
  required double az,
  required double bx,
  required double bz,
}) {
  final dx = bx - ax;
  final dz = bz - az;
  final lengthSquared = dx * dx + dz * dz;
  if (lengthSquared <= 1e-12) {
    final px = x - ax;
    final pz = z - az;
    return px * px + pz * pz;
  }
  final t = (((x - ax) * dx + (z - az) * dz) / lengthSquared)
      .clamp(0.0, 1.0)
      .toDouble();
  final closestX = ax + dx * t;
  final closestZ = az + dz * t;
  final px = x - closestX;
  final pz = z - closestZ;
  return px * px + pz * pz;
}
