import 'dart:math' as math;

import '../models/models.dart';
import 'zamer_scene_geometry.dart';

class ZamerDoorFloorBridgeSegment {
  const ZamerDoorFloorBridgeSegment({
    required this.surface,
    required this.pointsMm,
  });

  final ZamerFloorSurface surface;
  final List<math.Point<double>> pointsMm;
}

/// Builds the finished-floor patch that occupies the wall thickness at a door.
///
/// Room floor polygons stop at the finished wall faces, so without an explicit
/// threshold patch the GPU scene shows a bare strip through every doorway. The
/// bridge probes both sides of the wall. If the adjacent rooms use different
/// finishes, each finish owns half of the wall thickness instead of one room
/// arbitrarily painting the whole opening.
List<ZamerDoorFloorBridgeSegment> buildDoorFloorBridgeSegments({
  required ZamerOpeningPlacement opening,
  required List<ZamerFloorSurface> floors,
}) {
  if (opening.type != OpeningType.door || floors.isEmpty) {
    return const <ZamerDoorFloorBridgeSegment>[];
  }

  final widthMm = _safePositive(opening.widthMm, 800);
  final wallThicknessMm = _safePositive(opening.wallThicknessMm, 100);
  final halfWidth = math.max(20.0, widthMm / 2);
  final halfDepth = math.max(10.0, wallThicknessMm / 2);
  final angle = opening.rotationRad.isFinite ? opening.rotationRad : 0.0;
  final tx = math.cos(angle);
  final ty = math.sin(angle);
  final nx = -ty;
  final ny = tx;
  final probeDistance = halfDepth + 30.0;

  final positive = _surfaceForProbe(
    floors,
    math.Point<double>(
      opening.xMm + nx * probeDistance,
      opening.yMm + ny * probeDistance,
    ),
  );
  final negative = _surfaceForProbe(
    floors,
    math.Point<double>(
      opening.xMm - nx * probeDistance,
      opening.yMm - ny * probeDistance,
    ),
  );

  if (positive == null && negative == null) {
    return const <ZamerDoorFloorBridgeSegment>[];
  }

  List<math.Point<double>> quad(double nearNormalMm, double farNormalMm) {
    math.Point<double> point(double alongMm, double normalMm) {
      return math.Point<double>(
        opening.xMm + tx * alongMm + nx * normalMm,
        opening.yMm + ty * alongMm + ny * normalMm,
      );
    }

    return <math.Point<double>>[
      point(-halfWidth, nearNormalMm),
      point(halfWidth, nearNormalMm),
      point(halfWidth, farNormalMm),
      point(-halfWidth, farNormalMm),
    ];
  }

  if (positive == null) {
    return <ZamerDoorFloorBridgeSegment>[
      ZamerDoorFloorBridgeSegment(
        surface: negative!,
        pointsMm: quad(-halfDepth, halfDepth),
      ),
    ];
  }
  if (negative == null) {
    return <ZamerDoorFloorBridgeSegment>[
      ZamerDoorFloorBridgeSegment(
        surface: positive,
        pointsMm: quad(-halfDepth, halfDepth),
      ),
    ];
  }
  if (identical(positive, negative) || positive.roomKey == negative.roomKey) {
    return <ZamerDoorFloorBridgeSegment>[
      ZamerDoorFloorBridgeSegment(
        surface: positive,
        pointsMm: quad(-halfDepth, halfDepth),
      ),
    ];
  }

  return <ZamerDoorFloorBridgeSegment>[
    ZamerDoorFloorBridgeSegment(
      surface: negative,
      pointsMm: quad(-halfDepth, 0),
    ),
    ZamerDoorFloorBridgeSegment(
      surface: positive,
      pointsMm: quad(0, halfDepth),
    ),
  ];
}

ZamerFloorSurface? _surfaceForProbe(
  List<ZamerFloorSurface> floors,
  math.Point<double> probe,
) {
  for (final surface in floors) {
    if (_pointInPolygon(probe, surface.polygonMm)) return surface;
  }

  ZamerFloorSurface? nearest;
  var bestDistance2 = double.infinity;
  for (final surface in floors) {
    final polygon = surface.polygonMm;
    if (polygon.isEmpty) continue;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final distance2 = _pointSegmentDistance2(probe, a, b);
      if (distance2 < bestDistance2) {
        bestDistance2 = distance2;
        nearest = surface;
      }
    }
  }

  // The fallback only repairs small finish/rounding gaps around a wall face.
  // It must not steal flooring from a distant room across an exterior opening.
  return bestDistance2 <= 250 * 250 ? nearest : null;
}

bool _pointInPolygon(
  math.Point<double> point,
  List<math.Point<double>> polygon,
) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    final crosses =
        (a.y > point.y) != (b.y > point.y) &&
        point.x <
            (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
    if (crosses) inside = !inside;
  }
  return inside;
}

double _pointSegmentDistance2(
  math.Point<double> point,
  math.Point<double> a,
  math.Point<double> b,
) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final length2 = dx * dx + dy * dy;
  if (length2 <= 1e-9) {
    final px = point.x - a.x;
    final py = point.y - a.y;
    return px * px + py * py;
  }
  final t = (((point.x - a.x) * dx + (point.y - a.y) * dy) / length2)
      .clamp(0.0, 1.0)
      .toDouble();
  final qx = a.x + dx * t;
  final qy = a.y + dy * t;
  final px = point.x - qx;
  final py = point.y - qy;
  return px * px + py * py;
}

double _safePositive(double value, double fallback) =>
    value.isFinite && value > 0 ? value : fallback;
