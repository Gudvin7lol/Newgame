import 'dart:math' as math;

import '../models/models.dart';

/// A narrowly scoped, predictable CAD edit for orthogonal room outlines.
///
/// Moves one entire axis-aligned wall parallel to itself. Its two adjacent
/// perpendicular walls are stretched/shortened, not rotated. Junctions with
/// more than two walls and curves are deliberately rejected: propagating such
/// moves across several rooms requires a full constraint graph.
class OrthogonalWallMoveResult {
  const OrthogonalWallMoveResult._(this.isValid, this.message);

  final bool isValid;
  final String message;

  static const success = OrthogonalWallMoveResult._(true, '');
  static OrthogonalWallMoveResult reject(String message) =>
      OrthogonalWallMoveResult._(false, message);
}

class OrthogonalWallEditService {
  static const double _axisToleranceMm = 0.5;
  static const double _minimumWallMm = 100;
  static const double _intersectionEpsilon = 0.01;

  static bool _same(double a, double b) =>
      (a - b).abs() <= _axisToleranceMm;

  static math.Point<double> _point(PlanNode n) =>
      math.Point<double>(n.xMm, n.yMm);

  static double _distance(math.Point<double> a, math.Point<double> b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  /// Positive offset is to the right for a vertical wall, and downward for
  /// a horizontal wall (the plan's Y axis grows down the screen).
  static OrthogonalWallMoveResult preview(
    FloorPlan floor, {
    required String wallId,
    required double offsetMm,
  }) => _calculate(floor, wallId, offsetMm).result;

  static OrthogonalWallMoveResult move(
    FloorPlan floor, {
    required String wallId,
    required double offsetMm,
  }) {
    final planned = _calculate(floor, wallId, offsetMm);
    if (!planned.result.isValid) return planned.result;
    if (offsetMm == 0) return OrthogonalWallMoveResult.success;

    for (final node in floor.nodes) {
      final target = planned.positions[node.id];
      if (target == null) continue;
      node.xMm = target.x;
      node.yMm = target.y;
    }
    for (final entry in planned.openingOffsets.entries) {
      entry.key.offsetFromStartMm = entry.value;
    }
    return OrthogonalWallMoveResult.success;
  }

  static _WallMovePlan _calculate(
    FloorPlan floor,
    String wallId,
    double delta,
  ) {
    _WallMovePlan reject(String reason) =>
        _WallMovePlan(OrthogonalWallMoveResult.reject(reason));
    if (!delta.isFinite || delta.abs() > 100000) {
      return reject('Смещение должно быть конечным числом в пределах 100 м.');
    }
    final target = floor.wallById(wallId);
    if (target == null) return reject('Стена не найдена.');
    if (target.isCurved) return reject('Дуговые стены пока не поддерживаются.');
    final a = floor.nodeById(target.startNodeId);
    final b = floor.nodeById(target.endNodeId);
    if (a == null || b == null || a.id == b.id) {
      return reject('У стены повреждены крайние узлы.');
    }
    final vertical = _same(a.xMm, b.xMm);
    final horizontal = _same(a.yMm, b.yMm);
    if (vertical == horizontal || floor.wallLengthMm(target) < _minimumWallMm) {
      return reject('Требуется прямая горизонтальная или вертикальная стена.');
    }

    // Both corners must have exactly one perpendicular neighbour.
    for (final n in <PlanNode>[a, b]) {
      final attached = floor.walls
          .where((w) => w.startNodeId == n.id || w.endNodeId == n.id)
          .toList();
      if (attached.length != 2) {
        return reject('На конце стены есть сложный узел или ответвление.');
      }
      final other = attached.firstWhere((w) => w.id != wallId);
      if (other.isCurved) {
        return reject('Примыкающая стена является дуговой.');
      }
      final next = floor.nodeById(
        other.startNodeId == n.id ? other.endNodeId : other.startNodeId,
      );
      if (next == null || floor.wallLengthMm(other) < _minimumWallMm) {
        return reject('Примыкающая стена не имеет корректной геометрии.');
      }
      if (vertical ? !_same(n.yMm, next.yMm) : !_same(n.xMm, next.xMm)) {
        return reject('Примыкающие стены должны быть перпендикулярны.');
      }
    }

    final shift = vertical
        ? math.Point<double>(delta, 0)
        : math.Point<double>(0, delta);
    final positions = <String, math.Point<double>>{
      a.id: _point(a) + shift,
      b.id: _point(b) + shift,
    };
    math.Point<double>? newPosition(String id) =>
        positions[id] ??
        (floor.nodeById(id) == null ? null : _point(floor.nodeById(id)!));

    final openingOffsets = <WallOpening, double>{};
    final movedWalls = <String>{};

    for (final wall in floor.walls) {
      final startNode = floor.nodeById(wall.startNodeId);
      final endNode = floor.nodeById(wall.endNodeId);
      final s1 = newPosition(wall.startNodeId);
      final e1 = newPosition(wall.endNodeId);
      if (startNode == null || endNode == null || s1 == null || e1 == null) {
        return reject('В плане обнаружена стена с потерянным узлом.');
      }
      final s0 = _point(startNode);
      final e0 = _point(endNode);
      final originalLength = _distance(s0, e0);
      final nextLength = _distance(s1, e1);
      final affected = positions.containsKey(startNode.id) ||
          positions.containsKey(endNode.id);
      if (affected) {
        movedWalls.add(wall.id);
        if (originalLength < _minimumWallMm ||
            nextLength < _minimumWallMm) {
          return reject('Сдвиг оставит стену короче 100 мм.');
        }
        // Prevent flipping a rectangle inside out by moving a wall beyond
        // the opposite side. Every resized wall must retain its direction.
        final oldX = e0.x - s0.x;
        final oldY = e0.y - s0.y;
        final newX = e1.x - s1.x;
        final newY = e1.y - s1.y;
        if (oldX * newX + oldY * newY <= 0) {
          return reject('Сдвиг перевернёт или схлопнет контур помещения.');
        }
      }

      // Offsets are measured from the wall's start. Moving that endpoint
      // changes the offset of a physically fixed opening on a side wall.
      final unitX = originalLength == 0 ? 0.0 : (e0.x - s0.x) / originalLength;
      final unitY = originalLength == 0 ? 0.0 : (e0.y - s0.y) / originalLength;
      final movedStart = s1 - s0;
      for (final opening in wall.openings) {
        final nextOffset = opening.offsetFromStartMm -
            movedStart.x * unitX - movedStart.y * unitY;
        if (!nextOffset.isFinite ||
            nextOffset < -_intersectionEpsilon ||
            opening.widthMm <= 0 ||
            nextOffset + opening.widthMm > nextLength + _intersectionEpsilon) {
          return reject('После сдвига дверь или окно выйдет за пределы стены.');
        }
        if (affected) openingOffsets[opening] = nextOffset;
      }
    }

    // Check new collisions only for edges whose positions changed. Existing
    // unrelated irregularities are left untouched, never silently repaired.
    for (var i = 0; i < floor.walls.length; i++) {
      final first = floor.walls[i];
      for (var j = i + 1; j < floor.walls.length; j++) {
        final second = floor.walls[j];
        if (!movedWalls.contains(first.id) &&
            !movedWalls.contains(second.id)) {
          continue;
        }
        final a1 = newPosition(first.startNodeId)!;
        final b1 = newPosition(first.endNodeId)!;
        final a2 = newPosition(second.startNodeId)!;
        final b2 = newPosition(second.endNodeId)!;
        if (_conflict(a1, b1, a2, b2)) {
          return reject('При сдвиге возникнет пересечение или наложение стен.');
        }
      }
    }
    return _WallMovePlan(
      OrthogonalWallMoveResult.success,
      positions: positions,
      openingOffsets: openingOffsets,
    );
  }

  static double _cross(
    math.Point<double> a,
    math.Point<double> b,
    math.Point<double> c,
  ) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  static bool _insideSegment(
    math.Point<double> p,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    if (_cross(a, b, p).abs() >
        _intersectionEpsilon * math.max(1, _distance(a, b))) {
      return false;
    }
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < _intersectionEpsilon) return false;
    final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;
    final edgeFraction = _intersectionEpsilon / math.sqrt(lengthSquared);
    return t > edgeFraction && t < 1 - edgeFraction;
  }

  static bool _conflict(
    math.Point<double> a,
    math.Point<double> b,
    math.Point<double> c,
    math.Point<double> d,
  ) {
    final o1 = _cross(a, b, c);
    final o2 = _cross(a, b, d);
    final o3 = _cross(c, d, a);
    final o4 = _cross(c, d, b);
    final scale = math.max(_distance(a, b), _distance(c, d));
    final tolerance = _intersectionEpsilon * math.max(1, scale);
    if (o1.abs() <= tolerance &&
        o2.abs() <= tolerance &&
        o3.abs() <= tolerance &&
        o4.abs() <= tolerance) {
      // A shared endpoint is legal, a positive-length collinear overlap is not.
      final useX = (b.x - a.x).abs() >= (b.y - a.y).abs();
      final p = useX ? <double>[a.x, b.x, c.x, d.x]
                     : <double>[a.y, b.y, c.y, d.y];
      final overlap = math.min(math.max(p[0], p[1]), math.max(p[2], p[3])) -
          math.max(math.min(p[0], p[1]), math.min(p[2], p[3]));
      return overlap > _intersectionEpsilon;
    }
    if (o1 * o2 < 0 && o3 * o4 < 0) return true;
    return _insideSegment(a, c, d) || _insideSegment(b, c, d) ||
        _insideSegment(c, a, b) || _insideSegment(d, a, b);
  }
}

class _WallMovePlan {
  _WallMovePlan(
    this.result, {
    Map<String, math.Point<double>>? positions,
    Map<WallOpening, double>? openingOffsets,
  }) : positions = positions ?? const {},
       openingOffsets = openingOffsets ?? const {};

  final OrthogonalWallMoveResult result;
  final Map<String, math.Point<double>> positions;
  final Map<WallOpening, double> openingOffsets;
}
