import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';

class WarmFloorTakeoff {
  const WarmFloorTakeoff({
    required this.areaM2,
    required this.pipeM,
    required this.circuits,
    required this.spacingMm,
  });
  final double areaM2, pipeM, spacingMm;
  final int circuits;
}

class EngineeringService {
  /// Keeps a new route on perpendicular axes, adding the bend explicitly.
  static List<ServiceVertex> orthogonalStep(
    ServiceVertex previous,
    math.Point<double> target,
  ) {
    final dx = target.x - previous.xMm;
    final dy = target.y - previous.yMm;
    if (dx.abs() < 1 || dy.abs() < 1) {
      if (dx.abs() < 1 && dy.abs() < 1) return const [];
      return [ServiceVertex(target.x, target.y)];
    }
    final bend = dx.abs() >= dy.abs()
        ? ServiceVertex(target.x, previous.yMm)
        : ServiceVertex(previous.xMm, target.y);
    return [bend, ServiceVertex(target.x, target.y)];
  }

  static math.Point<double>? snapRoutePoint(
    FloorPlan floor,
    math.Point<double> point, {
    double thresholdMm = 150,
  }) {
    math.Point<double>? best;
    var bestDistance = thresholdMm;
    for (final object in floor.planObjects) {
      if (object.type != PlanObjectType.waterPoint &&
          object.type != PlanObjectType.drainPoint &&
          object.type != PlanObjectType.radiator)
        continue;
      final distance = math.sqrt(
        math.pow(point.x - object.xMm, 2) + math.pow(point.y - object.yMm, 2),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = math.Point(object.xMm, object.yMm);
      }
    }
    final node = GeometryService.nearestNode(
      floor,
      point,
      thresholdMm: bestDistance,
    );
    if (node != null) return math.Point(node.xMm, node.yMm);
    return best;
  }

  static int migrateLegacyCeilingZones(FloorPlan floor) {
    GeometryService.syncRoomMetadata(floor);
    final faces = GeometryService.roomFaces(floor);
    var moved = 0;
    for (final object in List<PlanObject>.of(floor.planObjects)) {
      if (object.type != PlanObjectType.ceilingZone) continue;
      for (final face in faces) {
        if (!_contains(face.innerPolygon, object.xMm, object.yMm)) continue;
        final meta = floor.roomMetaByKey(face.key);
        if (meta == null) break;
        meta.ceiling.zones.add(
          CeilingZone(
            id: object.id,
            xMm: object.xMm,
            yMm: object.yMm,
            widthMm: object.widthMm,
            depthMm: object.depthMm,
            extraDropMm:
                (GeometryService.roomHeightMm(floor, face) - object.elevationMm)
                    .clamp(0, 800)
                    .toDouble(),
          ),
        );
        floor.planObjects.remove(object);
        moved++;
        break;
      }
    }
    return moved;
  }

  static bool _contains(List<math.Point<double>> polygon, double x, double y) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.y > y) != (b.y > y) &&
          x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static WarmFloorTakeoff warmFloor(RoomFace face, HeatingSpec spec) {
    if (!spec.enabled) {
      return WarmFloorTakeoff(
        areaM2: 0,
        pipeM: 0,
        circuits: 0,
        spacingMm: spec.spacingMm,
      );
    }
    final coverage = spec.coveragePct.clamp(0.0, 100.0);
    final area = math.max(
      0.0,
      face.areaM2 * coverage / 100 - math.max(0.0, spec.excludedAreaM2),
    );
    final spacing = spec.spacingMm.clamp(75.0, 300.0);
    // Length of regular runs per square metre plus 10% for bends and feeds.
    final pipe = area / (spacing / 1000) * 1.10;
    final maxLength = math.max(20.0, spec.maxCircuitLengthM);
    return WarmFloorTakeoff(
      areaM2: area,
      pipeM: pipe,
      circuits: pipe == 0 ? 0 : (pipe / maxLength).ceil(),
      spacingMm: spacing,
    );
  }

  static double zoneAreaM2(RoomFace room, CeilingZone zone) {
    final left = zone.xMm - zone.widthMm / 2;
    final right = zone.xMm + zone.widthMm / 2;
    final top = zone.yMm - zone.depthMm / 2;
    final bottom = zone.yMm + zone.depthMm / 2;
    if (right <= left || bottom <= top) return 0;
    var polygon = List<math.Point<double>>.from(room.innerPolygon);
    List<math.Point<double>> clip(
      List<math.Point<double>> input,
      bool Function(math.Point<double>) inside,
      math.Point<double> Function(math.Point<double>, math.Point<double>) cross,
    ) {
      final output = <math.Point<double>>[];
      if (input.isEmpty) return output;
      var previous = input.last;
      for (final current in input) {
        if (inside(current)) {
          if (!inside(previous)) output.add(cross(previous, current));
          output.add(current);
        } else if (inside(previous)) {
          output.add(cross(previous, current));
        }
        previous = current;
      }
      return output;
    }

    math.Point<double> vertical(
      math.Point<double> a,
      math.Point<double> b,
      double x,
    ) {
      final t = (x - a.x) / (b.x - a.x);
      return math.Point(x, a.y + (b.y - a.y) * t);
    }

    math.Point<double> horizontal(
      math.Point<double> a,
      math.Point<double> b,
      double y,
    ) {
      final t = (y - a.y) / (b.y - a.y);
      return math.Point(a.x + (b.x - a.x) * t, y);
    }

    polygon = clip(polygon, (p) => p.x >= left, (a, b) => vertical(a, b, left));
    polygon = clip(
      polygon,
      (p) => p.x <= right,
      (a, b) => vertical(a, b, right),
    );
    polygon = clip(polygon, (p) => p.y >= top, (a, b) => horizontal(a, b, top));
    polygon = clip(
      polygon,
      (p) => p.y <= bottom,
      (a, b) => horizontal(a, b, bottom),
    );
    if (polygon.length < 3) return 0;
    var doubleArea = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      doubleArea += a.x * b.y - b.x * a.y;
    }
    return doubleArea.abs() / 2000000;
  }

  static Map<ServiceRunType, double> routeLengths(FloorPlan floor) {
    final totals = <ServiceRunType, double>{};
    for (final run in floor.serviceRuns) {
      if (run.points.length < 2) continue;
      totals[run.type] = (totals[run.type] ?? 0) + run.lengthM;
    }
    return totals;
  }
}
