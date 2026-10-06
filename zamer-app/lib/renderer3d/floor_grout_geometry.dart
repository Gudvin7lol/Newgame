import 'dart:math' as math;

import '../services/herringbone_layout.dart';

/// Vertical placement for the rendered floor finish and its grout overlay.
///
/// The grout is intentionally kept 2 mm above the zero-thickness floor mesh.
/// A sub-millimetre separation was prone to depth-buffer fighting on mobile
/// GPUs at shallow viewing angles and across long rooms.
const double zamerFloorSurfaceYM = 0.006;
const double zamerFloorGroutYM = 0.008;
const double zamerFloorGroutSeparationM =
    zamerFloorGroutYM - zamerFloorSurfaceYM;

class FloorGroutQuad {
  const FloorGroutQuad(this.pointsMm);

  final List<math.Point<double>> pointsMm;
}

/// Builds real-width floor tile grout strips in plan millimetres.
///
/// The layout uses the same anchor, angle, tile size and offsets as the 2D
/// layout editor. The returned quads can be rendered a fraction above the base
/// floor, so a configured 2 mm joint is actually 2 mm wide in the 3D scene.
List<FloorGroutQuad> buildFloorTileGroutQuads({
  required List<math.Point<double>> polygonMm,
  required double anchorXMm,
  required double anchorYMm,
  required double directionDeg,
  required double tileWidthMm,
  required double tileHeightMm,
  required double offsetXMm,
  required double offsetYMm,
  required double groutMm,
  String pattern = 'straight',
}) {
  if (polygonMm.length < 3 ||
      tileWidthMm < 20 ||
      tileHeightMm < 20 ||
      groutMm <= 0) {
    return const <FloorGroutQuad>[];
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

  final polygon = polygonMm.map(toLocal).toList(growable: false);
  final minX = polygon.map((p) => p.x).reduce(math.min);
  final maxX = polygon.map((p) => p.x).reduce(math.max);
  final minY = polygon.map((p) => p.y).reduce(math.min);
  final maxY = polygon.map((p) => p.y).reduce(math.max);
  final joint = groutMm.clamp(0.2, math.min(tileWidthMm, tileHeightMm) * .25);
  final half = joint / 2;
  final result = <FloorGroutQuad>[];

  List<(double, double)> verticalIntervals(double x) {
    final hits = <double>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.x <= x && b.x > x) || (b.x <= x && a.x > x)) {
        final t = (x - a.x) / (b.x - a.x);
        hits.add(a.y + (b.y - a.y) * t);
      }
    }
    hits.sort();
    final intervals = <(double, double)>[];
    for (var i = 0; i + 1 < hits.length; i += 2) {
      if (hits[i + 1] - hits[i] > .01) intervals.add((hits[i], hits[i + 1]));
    }
    return intervals;
  }

  List<(double, double)> horizontalIntervals(double y) {
    final hits = <double>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.y <= y && b.y > y) || (b.y <= y && a.y > y)) {
        final t = (y - a.y) / (b.y - a.y);
        hits.add(a.x + (b.x - a.x) * t);
      }
    }
    hits.sort();
    final intervals = <(double, double)>[];
    for (var i = 0; i + 1 < hits.length; i += 2) {
      if (hits[i + 1] - hits[i] > .01) intervals.add((hits[i], hits[i + 1]));
    }
    return intervals;
  }

  void addVertical(double x, double y0, double y1) {
    if (y1 - y0 <= .01) return;
    result.add(
      FloorGroutQuad([
        toWorld(math.Point(x - half, y0)),
        toWorld(math.Point(x + half, y0)),
        toWorld(math.Point(x + half, y1)),
        toWorld(math.Point(x - half, y1)),
      ]),
    );
  }

  void addHorizontal(double y, double x0, double x1) {
    if (x1 - x0 <= .01) return;
    result.add(
      FloorGroutQuad([
        toWorld(math.Point(x0, y - half)),
        toWorld(math.Point(x1, y - half)),
        toWorld(math.Point(x1, y + half)),
        toWorld(math.Point(x0, y + half)),
      ]),
    );
  }

  final firstY =
      ((minY - offsetYMm) / tileHeightMm).floor() * tileHeightMm + offsetYMm;
  for (var y = firstY; y <= maxY + .01; y += tileHeightMm) {
    for (final interval in horizontalIntervals(y)) {
      addHorizontal(y, interval.$1, interval.$2);
    }
  }

  if (pattern == 'half' || pattern == 'third') {
    var row = ((minY - offsetYMm) / tileHeightMm).floor();
    for (
      var y0 = row * tileHeightMm + offsetYMm;
      y0 < maxY;
      y0 += tileHeightMm, row++
    ) {
      final y1 = y0 + tileHeightMm;
      final shift = pattern == 'half'
          ? (row.isOdd ? tileWidthMm / 2 : 0.0)
          : (row % 3) * tileWidthMm / 3;
      final firstX =
          ((minX - offsetXMm - shift) / tileWidthMm).floor() * tileWidthMm +
          offsetXMm +
          shift;
      for (var x = firstX; x <= maxX + .01; x += tileWidthMm) {
        for (final interval in verticalIntervals(x)) {
          final a = math.max(interval.$1, y0);
          final b = math.min(interval.$2, y1);
          addVertical(x, a, b);
        }
      }
    }
  } else {
    final firstX =
        ((minX - offsetXMm) / tileWidthMm).floor() * tileWidthMm + offsetXMm;
    for (var x = firstX; x <= maxX + .01; x += tileWidthMm) {
      for (final interval in verticalIntervals(x)) {
        addVertical(x, interval.$1, interval.$2);
      }
    }
  }

  return result;
}


/// Builds narrow seam strips for a 45-degree herringbone laminate layout.
///
/// The board grid intentionally mirrors Floor3DPainter's herringbone math, but
/// only emits the visible seams. Keeping the base floor as one textured mesh
/// avoids hundreds of scene nodes while the seam geometry makes the real plank
/// length, width, direction and offsets readable in GPU 3D and Photo Render.
List<FloorGroutQuad> buildFloorHerringboneSeamQuads({
  required List<math.Point<double>> polygonMm,
  required double anchorXMm,
  required double anchorYMm,
  required double directionDeg,
  required double plankLengthMm,
  required double plankWidthMm,
  required double offsetXMm,
  required double offsetYMm,
  double seamMm = 1.8,
}) {
  if (polygonMm.length < 3 || plankLengthMm < 100 || plankWidthMm < 40) {
    return const <FloorGroutQuad>[];
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

  final polygon = polygonMm.map(toLocal).toList(growable: false);
  final minX = polygon.map((p) => p.x).reduce(math.min);
  final maxX = polygon.map((p) => p.x).reduce(math.max);
  final minY = polygon.map((p) => p.y).reduce(math.min);
  final maxY = polygon.map((p) => p.y).reduce(math.max);

  bool pointInside(math.Point<double> p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses = (a.y > p.y) != (b.y > p.y);
      if (!crosses) continue;
      final hitX = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
      if (p.x < hitX) inside = !inside;
    }
    return inside;
  }

  List<(math.Point<double>, math.Point<double>)> clipSegment(
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final rx = b.x - a.x;
    final ry = b.y - a.y;
    final ts = <double>[0, 1];
    for (var i = 0; i < polygon.length; i++) {
      final c = polygon[i];
      final d = polygon[(i + 1) % polygon.length];
      final sx = d.x - c.x;
      final sy = d.y - c.y;
      final den = rx * sy - ry * sx;
      if (den.abs() < 1e-9) continue;
      final qx = c.x - a.x;
      final qy = c.y - a.y;
      final t = (qx * sy - qy * sx) / den;
      final u = (qx * ry - qy * rx) / den;
      if (t > 1e-7 && t < 1 - 1e-7 && u >= -1e-7 && u <= 1 + 1e-7) {
        ts.add(t);
      }
    }
    ts.sort();
    final unique = <double>[];
    for (final t in ts) {
      if (unique.isEmpty || (t - unique.last).abs() > 1e-7) unique.add(t);
    }
    final visible = <(math.Point<double>, math.Point<double>)>[];
    for (var i = 0; i + 1 < unique.length; i++) {
      final t0 = unique[i];
      final t1 = unique[i + 1];
      final tm = (t0 + t1) / 2;
      final mid = math.Point<double>(a.x + rx * tm, a.y + ry * tm);
      if (!pointInside(mid)) continue;
      visible.add((
        math.Point<double>(a.x + rx * t0, a.y + ry * t0),
        math.Point<double>(a.x + rx * t1, a.y + ry * t1),
      ));
    }
    return visible;
  }

  final half = seamMm.clamp(0.6, plankWidthMm * .12).toDouble() / 2;
  final result = <FloorGroutQuad>[];
  final seen = <String>{};

  String pointKey(math.Point<double> p) =>
      '${(p.x * 10).round()}:${(p.y * 10).round()}';

  void addSegment(math.Point<double> a, math.Point<double> b) {
    for (final clipped in clipSegment(a, b)) {
      final p0 = clipped.$1;
      final p1 = clipped.$2;
      final k0 = pointKey(p0);
      final k1 = pointKey(p1);
      final key = k0.compareTo(k1) <= 0 ? '$k0|$k1' : '$k1|$k0';
      if (!seen.add(key)) continue;
      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 0.5) continue;
      final nx = -dy / length * half;
      final ny = dx / length * half;
      result.add(
        FloorGroutQuad([
          toWorld(math.Point<double>(p0.x + nx, p0.y + ny)),
          toWorld(math.Point<double>(p1.x + nx, p1.y + ny)),
          toWorld(math.Point<double>(p1.x - nx, p1.y - ny)),
          toWorld(math.Point<double>(p0.x - nx, p0.y - ny)),
        ]),
      );
    }
  }

  final boards = buildHerringboneBoards(
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    plankLength: plankLengthMm,
    plankWidth: plankWidthMm,
    offsetX: offsetXMm,
    offsetY: offsetYMm,
  );
  for (final board in boards) {
    if (board.points.length != 4) continue;
    for (var edge = 0; edge < 4; edge++) {
      addSegment(board.points[edge], board.points[(edge + 1) % 4]);
    }
  }
  return result;
}
