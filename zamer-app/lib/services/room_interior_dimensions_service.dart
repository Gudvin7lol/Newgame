import 'dart:math' as math;

import '../models/models.dart';

/// A true corner-to-corner measurement along the interior face of a room.
/// Coordinates are millimetres, measured between intersections of adjacent
/// room-side wall faces. They are never derived from the wall centreline.
class RoomInteriorDimension {
  const RoomInteriorDimension({
    required this.faceKey,
    required this.start,
    required this.end,
    required this.startEdgeIndex,
    required this.endEdgeIndex,
  });

  final String faceKey;
  final math.Point<double> start;
  final math.Point<double> end;
  final int startEdgeIndex;
  final int endEdgeIndex;

  double get lengthMm => math.sqrt(
        math.pow(end.x - start.x, 2) +
        math.pow(end.y - start.y, 2),
      );

  math.Point<double> get midpoint => math.Point<double>(
        (start.x + end.x) / 2,
        (start.y + end.y) / 2,
      );
}

/// Converts room-side offset polygons into uninterrupted dimensions.
/// A host wall split at a T-junction may have 2-3 different wall IDs but
/// its interior face is still one straight surface. Collinear face pieces
/// are combined, and dimension endpoints remain at *actual inside corners*.
///
/// This service only measures the room's wall-body inner faces. Additional
/// finishing layers (plaster, tile and panels) must be modelled as geometry
/// before labels can claim as-built finished dimensions.
class RoomInteriorDimensionsService {
  static const double minimumSegmentMm = 1;
  static const double straightToleranceMm = .05;

  static List<RoomInteriorDimension> forFace(RoomFace face) {
    final points = face.innerPolygon;
    final count = points.length;
    if (count < 3 || face.edges.length != count) return const [];

    // A polygon may start in the middle of a wall and may contain many
    // extra vertices from split host walls. Detect only actual direction
    // changes and iterate cyclically from one corner to the next.
    final corners = <int>[];
    for (var i = 0; i < count; i++) {
      final before = points[(i - 1 + count) % count];
      final at = points[i];
      final after = points[(i + 1) % count];
      if (!_straightContinuation(before, at, after)) {
        corners.add(i);
      }
    }
    if (corners.length < 3) return const [];

    final dimensions = <RoomInteriorDimension>[];
    for (var i = 0; i < corners.length; i++) {
      final startIndex = corners[i];
      final endIndex = corners[(i + 1) % corners.length];
      final start = points[startIndex];
      final end = points[endIndex];
      if (!_finite(start) || !_finite(end)) continue;
      final line = RoomInteriorDimension(
        faceKey: face.key,
        start: start,
        end: end,
        startEdgeIndex: startIndex,
        endEdgeIndex: endIndex,
      );
      if (line.lengthMm >= minimumSegmentMm) dimensions.add(line);
    }
    return dimensions;
  }

  static List<RoomInteriorDimension> forFloor(
    FloorPlan floor, {
    List<RoomFace>? faces,
  }) => [
    for (final face in faces ?? const <RoomFace>[])
      ...forFace(face),
  ];

  static bool _finite(math.Point<double> p) =>
      p.x.isFinite && p.y.isFinite;

  static bool _straightContinuation(
    math.Point<double> before,
    math.Point<double> current,
    math.Point<double> after,
  ) {
    final ux = current.x - before.x;
    final uy = current.y - before.y;
    final vx = after.x - current.x;
    final vy = after.y - current.y;
    final first = math.sqrt(ux * ux + uy * uy);
    final second = math.sqrt(vx * vx + vy * vy);
    if (first <= straightToleranceMm ||
        second <= straightToleranceMm) return true;
    final cross = (ux * vy - uy * vx).abs();
    // Offset of one endpoint from the extension of the preceding segment,
    // in real millimetres. Unlike an angle-only test, this preserves tiny
    // physical steps where walls of different thickness meet.
    final perpendicular = cross / first;
    final forward = ux * vx + uy * vy > 0;
    return forward && perpendicular <= straightToleranceMm;
  }
}
