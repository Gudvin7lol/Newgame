import 'dart:math' as math;

import '../services/herringbone_layout.dart';

class HerringboneSurfaceVertex {
  const HerringboneSurfaceVertex({
    required this.pointMm,
    required this.u,
    required this.v,
  });

  final math.Point<double> pointMm;
  final double u;
  final double v;
}

/// One clipped piece of a physical herringbone plank.
///
/// A board can cross a concave room's triangulation boundary, so one physical
/// board may produce several polygons. Every piece keeps the same local plank
/// UVs and atlas variant, which makes the split invisible in the material.
class HerringboneSurfacePolygon {
  const HerringboneSurfacePolygon({
    required this.vertices,
    required this.atlasVariant,
  });

  final List<HerringboneSurfaceVertex> vertices;

  /// Zero-based index inside the 4x4 Runtime v4 plank atlas.
  final int atlasVariant;
}

class _UvVertex {
  const _UvVertex(this.point, this.u, this.v);

  final math.Point<double> point;
  final double u;
  final double v;
}

/// Builds fully clipped physical plank surfaces for a 90-degree herringbone
/// layout. The room polygon may be concave.
///
/// The algorithm triangulates the room, clips each rectangular plank against
/// those convex triangles and interpolates plank-local UVs at every generated
/// intersection. That keeps BaseColor/Normal/Roughness aligned even on cut
/// boards along the room perimeter.
List<HerringboneSurfacePolygon> buildHerringboneSurfacePolygons({
  required List<math.Point<double>> polygonMm,
  required double anchorXMm,
  required double anchorYMm,
  required double directionDeg,
  required double plankLengthMm,
  required double plankWidthMm,
  required double offsetXMm,
  required double offsetYMm,
  int plankVariantCount = 16,
  int maxPolygons = 60000,
}) {
  if (polygonMm.length < 3 ||
      plankLengthMm < 100 ||
      plankWidthMm < 40 ||
      plankVariantCount <= 0 ||
      maxPolygons <= 0) {
    return const <HerringboneSurfacePolygon>[];
  }

  final angle = directionDeg * math.pi / 180;
  final ca = math.cos(angle);
  final sa = math.sin(angle);

  math.Point<double> toLocal(math.Point<double> p) {
    final dx = p.x - anchorXMm;
    final dy = p.y - anchorYMm;
    return math.Point<double>(dx * ca + dy * sa, -dx * sa + dy * ca);
  }

  math.Point<double> toWorld(math.Point<double> p) => math.Point<double>(
    anchorXMm + p.x * ca - p.y * sa,
    anchorYMm + p.x * sa + p.y * ca,
  );

  final room = polygonMm.map(toLocal).toList(growable: false);
  final roomTriangles = _triangulate(room);
  if (roomTriangles.isEmpty) {
    return const <HerringboneSurfacePolygon>[];
  }

  final minX = room.map((p) => p.x).reduce(math.min);
  final maxX = room.map((p) => p.x).reduce(math.max);
  final minY = room.map((p) => p.y).reduce(math.min);
  final maxY = room.map((p) => p.y).reduce(math.max);

  final boards = buildHerringboneBoards(
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    plankLength: plankLengthMm,
    plankWidth: plankWidthMm,
    offsetX: offsetXMm,
    offsetY: offsetYMm,
    maxBoards: maxPolygons,
  );

  final result = <HerringboneSurfacePolygon>[];
  for (final board in boards) {
    if (board.points.length != 4) continue;

    final subject = <_UvVertex>[
      _UvVertex(board.points[0], 0, 0),
      _UvVertex(board.points[1], 1, 0),
      _UvVertex(board.points[2], 1, 1),
      _UvVertex(board.points[3], 0, 1),
    ];
    final atlasVariant = _stableVariant(
      board,
      plankWidthMm: plankWidthMm,
      count: plankVariantCount,
    );

    for (var i = 0; i < roomTriangles.length; i += 3) {
      var a = room[roomTriangles[i]];
      var b = room[roomTriangles[i + 1]];
      var c = room[roomTriangles[i + 2]];
      if (_cross(a, b, c) < 0) {
        final swap = b;
        b = c;
        c = swap;
      }

      var clipped = subject;
      clipped = _clipAgainstEdge(clipped, a, b);
      if (clipped.length < 3) continue;
      clipped = _clipAgainstEdge(clipped, b, c);
      if (clipped.length < 3) continue;
      clipped = _clipAgainstEdge(clipped, c, a);
      if (clipped.length < 3) continue;
      if (_uvPolygonArea(clipped).abs() < 1e-3) continue;

      result.add(
        HerringboneSurfacePolygon(
          atlasVariant: atlasVariant,
          vertices: clipped
              .map(
                (v) => HerringboneSurfaceVertex(
                  pointMm: toWorld(v.point),
                  u: v.u.clamp(0.0, 1.0).toDouble(),
                  v: v.v.clamp(0.0, 1.0).toDouble(),
                ),
              )
              .toList(growable: false),
        ),
      );
      if (result.length >= maxPolygons) return result;
    }
  }
  return result;
}

int _stableVariant(
  HerringboneBoard board, {
  required double plankWidthMm,
  required int count,
}) {
  final p = board.points.first;
  final quantum = math.max(1.0, plankWidthMm / math.sqrt2);
  final ix = (p.x / quantum).round();
  final iy = (p.y / quantum).round();

  // Integer spatial hash. It depends on the physical board position rather
  // than list order, so changing the room boundary does not shuffle the wood
  // face of every untouched plank.
  final hash =
      (ix * 73856093) ^ (iy * 19349663) ^ (board.variant * 83492791);
  return (hash & 0x7fffffff) % count;
}

List<_UvVertex> _clipAgainstEdge(
  List<_UvVertex> input,
  math.Point<double> a,
  math.Point<double> b,
) {
  if (input.isEmpty) return const <_UvVertex>[];
  final output = <_UvVertex>[];

  bool inside(_UvVertex p) => _cross(a, b, p.point) >= -1e-7;

  var previous = input.last;
  var previousInside = inside(previous);
  for (final current in input) {
    final currentInside = inside(current);
    if (currentInside != previousInside) {
      output.add(_intersection(previous, current, a, b));
    }
    if (currentInside) output.add(current);
    previous = current;
    previousInside = currentInside;
  }
  return output;
}

_UvVertex _intersection(
  _UvVertex from,
  _UvVertex to,
  math.Point<double> a,
  math.Point<double> b,
) {
  final rx = to.point.x - from.point.x;
  final ry = to.point.y - from.point.y;
  final sx = b.x - a.x;
  final sy = b.y - a.y;
  final denominator = rx * sy - ry * sx;
  if (denominator.abs() < 1e-12) {
    return from;
  }
  final qx = a.x - from.point.x;
  final qy = a.y - from.point.y;
  final t = ((qx * sy - qy * sx) / denominator).clamp(0.0, 1.0).toDouble();
  return _UvVertex(
    math.Point<double>(
      from.point.x + rx * t,
      from.point.y + ry * t,
    ),
    from.u + (to.u - from.u) * t,
    from.v + (to.v - from.v) * t,
  );
}

double _uvPolygonArea(List<_UvVertex> vertices) {
  var area = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i].point;
    final b = vertices[(i + 1) % vertices.length].point;
    area += a.x * b.y - b.x * a.y;
  }
  return area / 2;
}

List<int> _triangulate(List<math.Point<double>> polygon) {
  if (polygon.length < 3) return const <int>[];
  final vertices = List<int>.generate(polygon.length, (i) => i);
  final result = <int>[];
  final ccw = _signedArea(polygon) > 0;
  var guard = polygon.length * polygon.length;

  while (vertices.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < vertices.length; i++) {
      final prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final cur = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      final a = polygon[prev];
      final b = polygon[cur];
      final c = polygon[next];
      final cross = _cross(a, b, c);
      if (ccw ? cross <= 1e-7 : cross >= -1e-7) continue;

      var contains = false;
      for (final candidate in vertices) {
        if (candidate == prev || candidate == cur || candidate == next) {
          continue;
        }
        if (_pointInTriangle(polygon[candidate], a, b, c)) {
          contains = true;
          break;
        }
      }
      if (contains) continue;

      result.addAll(ccw ? <int>[prev, cur, next] : <int>[next, cur, prev]);
      vertices.removeAt(i);
      clipped = true;
      break;
    }
    if (!clipped) break;
  }

  if (vertices.length == 3) {
    result.addAll(
      ccw
          ? vertices
          : <int>[vertices[2], vertices[1], vertices[0]],
    );
  }
  return result;
}

double _signedArea(List<math.Point<double>> polygon) {
  var area = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area / 2;
}

double _cross(
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

bool _pointInTriangle(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) {
  final c1 = _cross(a, b, p);
  final c2 = _cross(b, c, p);
  final c3 = _cross(c, a, p);
  final hasNeg = c1 < -1e-7 || c2 < -1e-7 || c3 < -1e-7;
  final hasPos = c1 > 1e-7 || c2 > 1e-7 || c3 > 1e-7;
  return !(hasNeg && hasPos);
}
