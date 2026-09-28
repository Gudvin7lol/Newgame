import 'dart:math' as math;

import '../models/models.dart';
import 'floor_continuity_service.dart';
import 'geometry_service.dart';

/// Keeps the eye position inside rooms, away from solid walls and furniture.
class WalkNavigationService {
  static const eyeClearanceMm = 250.0;

  static bool _inside(List<math.Point<double>> polygon, math.Point<double> p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _wallDistance(
    FloorPlan floor,
    PlanWall wall,
    math.Point<double> p,
  ) {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return double.infinity;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final length2 = dx * dx + dy * dy;
    if (length2 < 1) return double.infinity;
    final t = (((p.x - a.xMm) * dx + (p.y - a.yMm) * dy) / length2).clamp(
      0.0,
      1.0,
    );
    final projectionX = a.xMm + dx * t;
    final projectionY = a.yMm + dy * t;
    final distance = math.sqrt(
      math.pow(p.x - projectionX, 2) + math.pow(p.y - projectionY, 2),
    );
    final length = math.sqrt(length2);
    final atOpening = wall.openings.any(
      (opening) =>
          opening.type == OpeningType.door &&
          opening.sillHeightMm <= 35 &&
          opening.heightMm >= 1900 &&
          t * length >= opening.offsetFromStartMm + eyeClearanceMm &&
          t * length <=
              opening.offsetFromStartMm + opening.widthMm - eyeClearanceMm,
    );
    return atOpening ? double.infinity : distance - wall.thicknessMm / 2;
  }

  static bool canStand(
    FloorPlan floor,
    math.Point<double> p, {
    List<RoomFace>? rooms,
  }) {
    final faces = rooms ?? GeometryService.roomFaces(floor);
    if (!faces.any((room) => _inside(room.innerPolygon, p)) &&
        !FloorContinuityService.doorThresholds(
          floor,
          faces,
        ).any((opening) => _inside(opening, p))) {
      return false;
    }
    for (final wall in floor.walls) {
      if (wall.demolition || wall.projectLayer == ProjectLayer.demolition) {
        continue;
      }
      if (_wallDistance(floor, wall, p) < eyeClearanceMm) return false;
    }
    for (final o in floor.planObjects) {
      if (o.layer == ProjectLayer.demolition ||
          o.elevationMm > 1700 ||
          o.elevationMm + o.heightMm < 250 ||
          !{
            PlanObjectType.furniture,
            PlanObjectType.sanitary,
            PlanObjectType.column,
            PlanObjectType.box,
          }.contains(o.type)) {
        continue;
      }
      final angle = o.rotationDeg * math.pi / 180;
      final dx = p.x - o.xMm, dy = p.y - o.yMm;
      final localX = dx * math.cos(angle) + dy * math.sin(angle);
      final localY = -dx * math.sin(angle) + dy * math.cos(angle);
      if (localX.abs() < o.widthMm / 2 + eyeClearanceMm &&
          localY.abs() < o.depthMm / 2 + eyeClearanceMm)
        return false;
    }
    return true;
  }

  static math.Point<double> startingPoint(FloorPlan floor) {
    final rooms = GeometryService.roomFaces(floor).toList()
      ..sort((a, b) => b.areaM2.compareTo(a.areaM2));
    if (rooms.isEmpty) return const math.Point(0, 0);
    for (final room in rooms) {
      final xs = room.innerPolygon.map((p) => p.x);
      final ys = room.innerPolygon.map((p) => p.y);
      final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
      final center = math.Point((minX + maxX) / 2, (minY + maxY) / 2);
      final candidates = [
        center,
        room.centroid,
        for (var iy = 1; iy <= 7; iy++)
          for (var ix = 1; ix <= 7; ix++)
            math.Point(
              minX + (maxX - minX) * ix / 8,
              minY + (maxY - minY) * iy / 8,
            ),
      ];
      for (final p in candidates) {
        if (canStand(floor, p, rooms: rooms)) return p;
      }
    }
    return rooms.first.centroid;
  }

  static double startingRotation(FloorPlan floor, math.Point<double> start) {
    final rooms = GeometryService.roomFaces(floor);
    var best = 0.0, bestReach = -1.0;
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      var reach = 0.0;
      for (var d = 100.0; d <= 3000; d += 100) {
        if (!canStand(
          floor,
          math.Point(
            start.x + math.cos(angle) * d,
            start.y + math.sin(angle) * d,
          ),
          rooms: rooms,
        ))
          break;
        reach = d;
      }
      if (reach > bestReach) {
        best = angle;
        bestReach = reach;
      }
    }
    return math.atan2(math.sin(best), math.cos(best));
  }

  static math.Point<double> advance(
    FloorPlan floor,
    math.Point<double> start,
    double rotation,
    double forward,
    double sideways, {
    bool ignoreCollisions = false,
  }) {
    final dx = forward * math.cos(rotation) - sideways * math.sin(rotation);
    final dy = forward * math.sin(rotation) + sideways * math.cos(rotation);

    // Noclip is intentional in survey work: it lets the user inspect cramped
    // corners, shafts and neighbouring rooms without fighting collision rules.
    if (ignoreCollisions) {
      return math.Point(start.x + dx, start.y + dy);
    }

    final steps = math.max(1, (math.sqrt(dx * dx + dy * dy) / 25).ceil());
    final rooms = GeometryService.roomFaces(floor);
    var current = start;
    for (var i = 1; i <= steps; i++) {
      final p = math.Point(start.x + dx * i / steps, start.y + dy * i / steps);
      if (!canStand(floor, p, rooms: rooms)) break;
      current = p;
    }
    return current;
  }
}
