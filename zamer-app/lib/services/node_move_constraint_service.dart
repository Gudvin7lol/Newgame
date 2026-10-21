import 'dart:math' as math;

import '../models/models.dart';

/// Preview of a constrained 2D node move. Keeps originally horizontal and
/// vertical wall axes in their original orientation. It changes the entire
/// connected X/Y alignment chain, not merely the vertex under the finger.
class NodeMoveConstraintResult {
  const NodeMoveConstraintResult({
    required this.isValid,
    this.positions = const {},
    this.movedNodeIds = const {},
    this.message,
  });

  final bool isValid;
  final Map<String, math.Point<double>> positions;
  final Set<String> movedNodeIds;
  final String? message;
}

class NodeMoveConstraintService {
  const NodeMoveConstraintService._();

  static const double _epsilon = 0.5;
  static const double _minWallLengthMm = 120.0;

  static NodeMoveConstraintResult evaluate(
    FloorPlan before, {
    required String nodeId,
    required math.Point<double> destination,
  }) {
    final moved = before.nodeById(nodeId);
    if (moved == null || !destination.x.isFinite || !destination.y.isFinite) {
      return const NodeMoveConstraintResult(
        isValid: false, message: 'Некорректная точка',
      );
    }

    Set<String> linked({required bool sameX}) {
      final visited = <String>{nodeId};
      final pending = <String>[nodeId];
      while (pending.isNotEmpty) {
        final next = pending.removeLast();
        for (final wall in before.walls) {
          final a = before.nodeById(wall.startNodeId);
          final b = before.nodeById(wall.endNodeId);
          if (a == null || b == null) continue;
          if (wall.isCurved) continue;
          final locked = sameX
              ? (a.xMm - b.xMm).abs() <= _epsilon
              : (a.yMm - b.yMm).abs() <= _epsilon;
          if (!locked) continue;
          String? neighbor;
          if (wall.startNodeId == next) neighbor = wall.endNodeId;
          if (wall.endNodeId == next) neighbor = wall.startNodeId;
          if (neighbor != null && visited.add(neighbor)) pending.add(neighbor);
        }
      }
      return visited;
    }

    final xLinked = linked(sameX: true);
    final yLinked = linked(sameX: false);
    final dx = destination.x - moved.xMm;
    final dy = destination.y - moved.yMm;
    final coordinates = <String, math.Point<double>>{
      for (final node in before.nodes)
        node.id: math.Point<double>(
          node.xMm + (xLinked.contains(node.id) ? dx : 0),
          node.yMm + (yLinked.contains(node.id) ? dy : 0),
        ),
    };
    final changed = before.nodes.where((n) {
      final p = coordinates[n.id]!;
      return (p.x - n.xMm).abs() > .01 || (p.y - n.yMm).abs() > .01;
    }).map((n) => n.id).toSet();

    for (final wall in before.walls) {
      final oldA = before.nodeById(wall.startNodeId);
      final oldB = before.nodeById(wall.endNodeId);
      if (oldA == null || oldB == null) continue;
      final a = coordinates[oldA.id]!, b = coordinates[oldB.id]!;
      final oldLength = before.wallLengthMm(wall);
      final distance = math.sqrt(
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y),
      );
      if (oldLength >= _minWallLengthMm &&
          distance < _minWallLengthMm - .01) {
        return const NodeMoveConstraintResult(
          isValid: false, message: 'Стена станет короче 120 мм',
        );
      }
      // A wall must not silently reverse its start/end direction: openings,
      // finished-side normals, and frame offsets all use that orientation.
      if ((oldB.xMm - oldA.xMm) * (b.x - a.x) +
          (oldB.yMm - oldA.yMm) * (b.y - a.y) <= 0) {
        return const NodeMoveConstraintResult(
          isValid: false, message: 'Нельзя переворачивать ось стены',
        );
      }
      for (final opening in wall.openings) {
        if (opening.offsetFromStartMm < 0 ||
            opening.offsetFromStartMm + opening.widthMm > distance + .01) {
          return const NodeMoveConstraintResult(
            isValid: false, message: 'Проём выйдет за границы стены',
          );
        }
      }
      final axisX = (oldA.xMm - oldB.xMm).abs() <= _epsilon;
      final axisY = (oldA.yMm - oldB.yMm).abs() <= _epsilon;
      if ((axisX && (a.x - b.x).abs() > _epsilon) ||
          (axisY && (a.y - b.y).abs() > _epsilon)) {
        return const NodeMoveConstraintResult(
          isValid: false, message: 'Нарушается прямой угол',
        );
      }
      if (!axisX && !axisY &&
          (changed.contains(oldA.id) || changed.contains(oldB.id))) {
        return const NodeMoveConstraintResult(
          isValid: false,
          message: 'Косые стены редактируйте в свободном режиме',
        );
      }
      if (wall.isCurved &&
          (changed.contains(oldA.id) || changed.contains(oldB.id))) {
        return const NodeMoveConstraintResult(
          isValid: false,
          message: 'Для изменения дуги нужен инструмент дуг',
        );
      }
    }

    // Reject a *new* proper crossing between segments without a shared node.
    // Existing crossing geometry is not silently rewritten during dragging.
    final walls = before.walls.where((w) => !w.isCurved).toList();
    for (var i = 0; i < walls.length; i++) {
      final a = walls[i];
      if (!changed.contains(a.startNodeId) &&
          !changed.contains(a.endNodeId)) continue;
      for (var j = 0; j < walls.length; j++) {
        if (i == j) continue;
        final b = walls[j];
        if (a.startNodeId == b.startNodeId ||
            a.startNodeId == b.endNodeId ||
            a.endNodeId == b.startNodeId ||
            a.endNodeId == b.endNodeId) continue;
        if (_crosses(
              coordinates[a.startNodeId]!, coordinates[a.endNodeId]!,
              coordinates[b.startNodeId]!, coordinates[b.endNodeId]!,
            ) &&
            !_crosses(
              _original(before, a.startNodeId),
              _original(before, a.endNodeId),
              _original(before, b.startNodeId),
              _original(before, b.endNodeId),
            )) {
          return const NodeMoveConstraintResult(
            isValid: false, message: 'Стены пересекаются',
          );
        }
      }
    }

    return NodeMoveConstraintResult(
      isValid: true, positions: coordinates, movedNodeIds: changed,
    );
  }

  static math.Point<double> _original(FloorPlan f, String id) {
    final n = f.nodeById(id)!;
    return math.Point<double>(n.xMm, n.yMm);
  }

  static bool _crosses(
    math.Point<double> a, math.Point<double> b,
    math.Point<double> c, math.Point<double> d,
  ) {
    double cross(math.Point<double> p, math.Point<double> q,
        math.Point<double> r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    final abc = cross(a, b, c), abd = cross(a, b, d);
    final cda = cross(c, d, a), cdb = cross(c, d, b);
    const tolerance = 1e-3;
    return ((abc > tolerance && abd < -tolerance) ||
            (abc < -tolerance && abd > tolerance)) &&
        ((cda > tolerance && cdb < -tolerance) ||
            (cda < -tolerance && cdb > tolerance));
  }

  /// Only the editor calls this on a valid preview. The saved FloorPlan
  /// remains the single authoritative model and contains no preview nodes.
  static void apply(FloorPlan floor, NodeMoveConstraintResult preview) {
    if (!preview.isValid) return;
    for (final node in floor.nodes) {
      final point = preview.positions[node.id];
      if (point == null) continue;
      node.xMm = point.x;
      node.yMm = point.y;
    }
  }
}
