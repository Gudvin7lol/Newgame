
import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';

typedef FloorPoint = math.Point<double>;

/// Surface-only geometry. Polygon vertices use project millimetres.
/// Concave polygons are triangulated before intersection, so a drawn
/// zone cannot be counted outside the actual (possibly L-shaped) room.
class WorkFloorPolygonService {
  static const minAreaM2 = .01;

  static double _cross(FloorPoint a, FloorPoint b, FloorPoint c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  static double signedDoubleArea(List<FloorPoint> points) {
    var value = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      value += a.x * b.y - a.y * b.x;
    }
    return value;
  }

  static double area(List<FloorPoint> points) =>
      points.length < 3 ? 0 : signedDoubleArea(points).abs() / 2000000;

  static bool _properSegmentsIntersect(
      FloorPoint a, FloorPoint b, FloorPoint c, FloorPoint d) {
    const tolerance = 1e-5;
    final p = _cross(a, b, c);
    final q = _cross(a, b, d);
    final r = _cross(c, d, a);
    final s = _cross(c, d, b);
    return ((p > tolerance && q < -tolerance) ||
            (p < -tolerance && q > tolerance)) &&
        ((r > tolerance && s < -tolerance) ||
            (r < -tolerance && s > tolerance));
  }

  static bool isSimple(List<FloorPoint> polygon) {
    if (polygon.length < 3 || polygon.length > 100 ||
        polygon.any((p) => !p.x.isFinite || !p.y.isFinite) ||
        area(polygon) < minAreaM2) return false;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.x - b.x).abs() + (a.y - b.y).abs() < .01) return false;
      for (var j = i + 1; j < polygon.length; j++) {
        if (j == i + 1 || (i == 0 && j == polygon.length - 1)) {
          continue;
        }
        final c = polygon[j];
        final d = polygon[(j + 1) % polygon.length];
        if (_properSegmentsIntersect(a, b, c, d)) return false;
      }
    }
    try {
      triangulate(polygon);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Ear clipping for a simple polygon with either winding. Every triangle
  /// is returned counter-clockwise for deterministic convex clipping.
  static List<List<FloorPoint>> triangulate(List<FloorPoint> polygon) {
    if (polygon.length < 3 || polygon.length > 100) {
      throw ArgumentError('Контур должен иметь от 3 до 100 вершин.');
    }
    final vertices = signedDoubleArea(polygon) >= 0
        ? List<FloorPoint>.of(polygon)
        : polygon.reversed.toList();
    final result = <List<FloorPoint>>[];
    var guards = 0;
    while (vertices.length > 3) {
      if (guards++ > polygon.length * polygon.length) {
        throw ArgumentError('Не удалось построить треугольники контура.');
      }
      var clipped = false;
      for (var i = 0; i < vertices.length; i++) {
        final before = vertices[(i - 1 + vertices.length) % vertices.length];
        final vertex = vertices[i];
        final after = vertices[(i + 1) % vertices.length];
        if (_cross(before, vertex, after) <= 1e-6) continue;
        var containsOther = false;
        for (var j = 0; j < vertices.length; j++) {
          if (j == i || j == (i - 1 + vertices.length) % vertices.length ||
              j == (i + 1) % vertices.length) continue;
          final p = vertices[j];
          if (_cross(before, vertex, p) >= -1e-6 &&
              _cross(vertex, after, p) >= -1e-6 &&
              _cross(after, before, p) >= -1e-6) {
            containsOther = true;
            break;
          }
        }
        if (containsOther) continue;
        result.add([before, vertex, after]);
        vertices.removeAt(i);
        clipped = true;
        break;
      }
      if (!clipped) {
        // A collinear vertex adds no area; drop it before retrying.
        for (var i = 0; i < vertices.length; i++) {
          if (_cross(vertices[(i - 1 + vertices.length) % vertices.length],
              vertices[i], vertices[(i + 1) % vertices.length]).abs()
              < 1e-6) {
            vertices.removeAt(i);
            clipped = true;
            break;
          }
        }
        if (!clipped) {
          throw ArgumentError('Контур самопересекается или вырожден.');
        }
      }
    }
    if (vertices.length != 3 || _cross(vertices[0], vertices[1],
        vertices[2]) <= 1e-6) {
      throw ArgumentError('Контур вырожден.');
    }
    result.add(List.of(vertices));
    return result;
  }

  static List<FloorPoint> _clipConvex(
      List<FloorPoint> polygon, List<FloorPoint> triangle) {
    var output = List<FloorPoint>.of(polygon);
    for (var i = 0; i < triangle.length && output.isNotEmpty; i++) {
      final a = triangle[i], b = triangle[(i + 1) % triangle.length];
      final input = output;
      output = [];
      for (var j = 0; j < input.length; j++) {
        final p = input[j], q = input[(j + 1) % input.length];
        final cp = _cross(a, b, p), cq = _cross(a, b, q);
        final pin = cp >= -1e-6, qin = cq >= -1e-6;
        FloorPoint intersection() {
          final denom = cp - cq;
          if (denom.abs() < 1e-12) return p;
          final t = (cp / denom).clamp(0.0, 1.0).toDouble();
          return FloorPoint(
            p.x + (q.x - p.x) * t,
            p.y + (q.y - p.y) * t,
          );
        }
        if (pin && qin) {
          output.add(q);
        } else if (pin && !qin) {
          output.add(intersection());
        } else if (!pin && qin) {
          output..add(intersection())..add(q);
        }
      }
    }
    return output;
  }

  static double intersectionArea(
      List<FloorPoint> first, List<FloorPoint> second) {
    if (first.length < 3 || second.length < 3) return 0;
    final a = triangulate(first), b = triangulate(second);
    var sum = 0.0;
    for (final ta in a) {
      for (final tb in b) {
        sum += area(_clipConvex(ta, tb));
      }
    }
    return sum;
  }

  static List<WorkFloorFinishZone> roomZones(
      WorkBoard board, FloorPlan floor, RoomFace face) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return [];
    return board.floorZones.where((z) =>
      z.floorId == floor.id && z.roomId == room.id).toList();
  }

  /// Strict scope validation prevents overlap and any area outside a room,
  /// including across concave notches and adjacent rooms.
  static void validate(RoomFace face, FloorPlan floor,
      List<WorkFloorFinishZone> zones) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) throw ArgumentError('Помещение не найдено.');
    if (zones.length > 30) {
      throw ArgumentError('Для комнаты допускается не более 30 зон.');
    }
    final names = <String>{};
    for (var i = 0; i < zones.length; i++) {
      final zone = zones[i];
      if (zone.floorId != floor.id || zone.roomId != room.id ||
          zone.id.isEmpty || !names.add(zone.id) ||
          !{'tile', 'laminate'}.contains(zone.material)) {
        throw ArgumentError('Некорректная зона покрытия пола.');
      }
      if (!isSimple(zone.polygon)) {
        throw ArgumentError('Зона имеет самопересечение или слишком мала.');
      }
      final covered = intersectionArea(face.innerPolygon, zone.polygon);
      if ((covered - area(zone.polygon)).abs() > .0001) {
        throw ArgumentError('Зона выходит за контур помещения.');
      }
      for (var j = 0; j < i; j++) {
        if (intersectionArea(zones[j].polygon, zone.polygon) > .0001) {
          throw ArgumentError('Зоны покрытий пересекаются.');
        }
      }
    }
  }

  /// Non-overlapping polygons cover part of the room. Unassigned remainder
  /// retains the room's existing base floor mode, never a second coating.
  static ({double tileM2, double laminateM2}) areas(
      FloorPlan floor, RoomFace face,
      List<WorkFloorFinishZone> zones) {
    validate(face, floor, zones);
    final room = floor.roomMetaByKey(face.key)!;
    final tileBase = room.materials.floorMode == 'tile' ||
        room.materials.floorTile;
    var tile = tileBase ? face.areaM2 : 0.0;
    for (final zone in zones) {
      final square = area(zone.polygon);
      if (tileBase && zone.material == 'laminate') {
        tile -= square;
      } else if (!tileBase && zone.material == 'tile') {
        tile += square;
      }
    }
    tile = tile.clamp(0.0, face.areaM2).toDouble();
    return (tileM2: tile, laminateM2: face.areaM2 - tile);
  }

  /// Save a complete room snapshot. A polygon layout replaces the legacy
  /// straight-line split, but never changes previously accepted work.
  static void save(WorkBoard board, FloorPlan floor, RoomFace face,
      List<WorkFloorFinishZone> zones) {
    validate(face, floor, zones);
    final room = floor.roomMetaByKey(face.key)!;
    board.floorZones.removeWhere((z) =>
        z.floorId == floor.id && z.roomId == room.id);
    board.floorZones.addAll(zones);
    // The explicit polygon editor owns the floor allocation from now on.
    board.floorFinishes.removeWhere((s) =>
        s.floorId == floor.id && s.roomId == room.id);
  }
}
