import 'dart:math' as math;

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

  if (pattern == 'half') {
    var row = ((minY - offsetYMm) / tileHeightMm).floor();
    for (
      var y0 = row * tileHeightMm + offsetYMm;
      y0 < maxY;
      y0 += tileHeightMm, row++
    ) {
      final y1 = y0 + tileHeightMm;
      final shift = row.isOdd ? tileWidthMm / 2 : 0.0;
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
