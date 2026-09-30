import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';

enum MeasurementIssueKind {
  openContour,
  discrepancy,
  acuteAngle,
  intersection,
  missingOffset,
  missingHeight,
  missingDiagonal,
}

class MeasurementIssue {
  const MeasurementIssue(
    this.kind,
    this.description,
    this.position, {
    this.deltaMm,
  });
  final MeasurementIssueKind kind;
  final String description;
  final math.Point<double> position;
  final double? deltaMm;
}

class MeasurementReviewService {
  static double? _collinearSections(FloorPlan floor, PlanNode a, PlanNode b) {
    final length = GeometryService.distance(a, b);
    if (length < 1) return null;
    bool onLine(PlanNode n) {
      final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
      final cross =
          ((n.xMm - a.xMm) * dy - (n.yMm - a.yMm) * dx).abs() / length;
      final t =
          ((n.xMm - a.xMm) * dx + (n.yMm - a.yMm) * dy) / (length * length);
      return cross <= 30 && t >= -.01 && t <= 1.01;
    }

    final seen = <String>{a.id};
    final queue = <(String, double)>[(a.id, 0)];
    for (var i = 0; i < queue.length; i++) {
      final (id, distance) = queue[i];
      for (final wall in floor.walls) {
        if (wall.startNodeId != id && wall.endNodeId != id) continue;
        final nextId = wall.startNodeId == id
            ? wall.endNodeId
            : wall.startNodeId;
        final next = floor.nodeById(nextId);
        if (next == null || !onLine(next) || !seen.add(nextId)) continue;
        final sum = distance + floor.wallLengthMm(wall);
        if (nextId == b.id) return sum;
        queue.add((nextId, sum));
      }
    }
    return null;
  }

  static math.Point<double>? _strictIntersection(
    PlanNode a,
    PlanNode b,
    PlanNode c,
    PlanNode d,
  ) {
    final rx = b.xMm - a.xMm;
    final ry = b.yMm - a.yMm;
    final sx = d.xMm - c.xMm;
    final sy = d.yMm - c.yMm;
    final denominator = rx * sy - ry * sx;
    if (denominator.abs() < 1e-9) return null;

    final qpx = c.xMm - a.xMm;
    final qpy = c.yMm - a.yMm;
    final t = (qpx * sy - qpy * sx) / denominator;
    final u = (qpx * ry - qpy * rx) / denominator;

    // Endpoints are valid shared corners. Only an interior crossing is an issue.
    if (t <= .001 || t >= .999 || u <= .001 || u >= .999) return null;
    return math.Point<double>(a.xMm + rx * t, a.yMm + ry * t);
  }

  static void _addAcuteAngleIssues(
    FloorPlan floor,
    List<MeasurementIssue> issues,
  ) {
    const thresholdDegrees = 65.0;
    final active = floor.walls.where((wall) => !wall.demolition).toList();

    for (final node in floor.nodes) {
      final connected = active
          .where(
            (wall) =>
                wall.startNodeId == node.id || wall.endNodeId == node.id,
          )
          .toList();
      if (connected.length < 2) continue;

      for (var i = 0; i < connected.length - 1; i++) {
        for (var j = i + 1; j < connected.length; j++) {
          final wallA = connected[i];
          final wallB = connected[j];
          final otherA = floor.nodeById(
            wallA.startNodeId == node.id ? wallA.endNodeId : wallA.startNodeId,
          );
          final otherB = floor.nodeById(
            wallB.startNodeId == node.id ? wallB.endNodeId : wallB.startNodeId,
          );
          if (otherA == null || otherB == null) continue;

          final ax = otherA.xMm - node.xMm;
          final ay = otherA.yMm - node.yMm;
          final bx = otherB.xMm - node.xMm;
          final by = otherB.yMm - node.yMm;
          final lenA = math.sqrt(ax * ax + ay * ay);
          final lenB = math.sqrt(bx * bx + by * by);
          if (lenA < 1 || lenB < 1) continue;

          final cosine = ((ax * bx + ay * by) / (lenA * lenB))
              .clamp(-1.0, 1.0)
              .toDouble();
          final degrees = math.acos(cosine) * 180 / math.pi;
          if (degrees >= thresholdDegrees || degrees < .5) continue;

          issues.add(
            MeasurementIssue(
              MeasurementIssueKind.acuteAngle,
              'Острый угол ${degrees.toStringAsFixed(1)}° у узла ${node.id}; '
              'проверь геометрию и фактический угол на объекте',
              math.Point(node.xMm, node.yMm),
            ),
          );
        }
      }
    }
  }

  static void _addIntersectionIssues(
    FloorPlan floor,
    List<MeasurementIssue> issues,
  ) {
    final active = floor.walls.where((wall) => !wall.demolition).toList();
    for (var i = 0; i < active.length - 1; i++) {
      final first = active[i];
      final a = floor.nodeById(first.startNodeId);
      final b = floor.nodeById(first.endNodeId);
      if (a == null || b == null) continue;

      for (var j = i + 1; j < active.length; j++) {
        final second = active[j];
        final sharesNode = first.startNodeId == second.startNodeId ||
            first.startNodeId == second.endNodeId ||
            first.endNodeId == second.startNodeId ||
            first.endNodeId == second.endNodeId;
        if (sharesNode) continue;

        final c = floor.nodeById(second.startNodeId);
        final d = floor.nodeById(second.endNodeId);
        if (c == null || d == null) continue;
        final point = _strictIntersection(a, b, c, d);
        if (point == null) continue;

        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.intersection,
            'Пересечение стен ${first.id} и ${second.id} без общего узла',
            point,
          ),
        );
      }
    }
  }

  static List<MeasurementIssue> review(FloorPlan floor) {
    final issues = <MeasurementIssue>[];
    final faces = GeometryService.roomFaces(floor);
    final roomWallIds = faces
        .expand((face) => face.edges.map((e) => e.wallId))
        .toSet();
    final exterior = floor.walls
        .where((w) => w.type == WallType.exterior && !w.demolition)
        .toList();
    final boundary = exterior.isNotEmpty
        ? exterior
        : floor.walls.where((w) => !w.demolition).toList();
    final degrees = <String, int>{};
    for (final wall in boundary) {
      degrees[wall.startNodeId] = (degrees[wall.startNodeId] ?? 0) + 1;
      degrees[wall.endNodeId] = (degrees[wall.endNodeId] ?? 0) + 1;
    }
    for (final entry in degrees.entries.where((e) => e.value == 1)) {
      final n = floor.nodeById(entry.key);
      final connected = boundary
          .where((w) => w.startNodeId == entry.key || w.endNodeId == entry.key)
          .toList();
      if (faces.isNotEmpty &&
          connected.isNotEmpty &&
          connected.every(
            (w) => w.type == WallType.partition && !roomWallIds.contains(w.id),
          )) {
        continue;
      }
      if (n != null) {
        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.openContour,
            'Незамкнутый контур у узла ${n.id}',
            math.Point(n.xMm, n.yMm),
          ),
        );
      }
    }

    _addAcuteAngleIssues(floor, issues);
    _addIntersectionIssues(floor, issues);

    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final midpoint = math.Point<double>(
        (a.xMm + b.xMm) / 2,
        (a.yMm + b.yMm) / 2,
      );
      final recorded = floor.dimensionRecords['wall:${wall.id}:length'];
      final difference = recorded == null
          ? 0.0
          : floor.wallLengthMm(wall) - recorded.valueMm;
      if (difference.abs() >= 5) {
        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.discrepancy,
            'Стена ${wall.id}: план ${floor.wallLengthMm(wall).round()} мм, '
            'замер ${recorded!.valueMm.round()} мм; расхождение ${difference.abs().round()} мм',
            midpoint,
            deltaMm: difference,
          ),
        );
      }
      for (final opening in wall.openings) {
        final t = floor.wallLengthMm(wall) <= 0
            ? 0.0
            : (opening.offsetFromStartMm + opening.widthMm / 2) /
                floor.wallLengthMm(wall);
        final place = math.Point<double>(
          a.xMm + (b.xMm - a.xMm) * t,
          a.yMm + (b.yMm - a.yMm) * t,
        );
        if (floor.dimensionRecords['opening:${opening.id}:offset']?.source ==
                null ||
            floor.dimensionRecords['opening:${opening.id}:offset']!.source ==
                DimensionSource.calculated) {
          issues.add(
            MeasurementIssue(
              MeasurementIssueKind.missingOffset,
              'Проём ${opening.id}: отступ от начала стены не подтверждён',
              place,
            ),
          );
        }
        if (floor.dimensionRecords['opening:${opening.id}:height']?.source ==
                null ||
            floor.dimensionRecords['opening:${opening.id}:height']!.source ==
                DimensionSource.calculated) {
          issues.add(
            MeasurementIssue(
              MeasurementIssueKind.missingHeight,
              'Проём ${opening.id}: высота не подтверждена',
              place,
            ),
          );
        }
      }
    }
    for (final measure in floor.measures) {
      final a = floor.nodeById(measure.startNodeId);
      final b = floor.nodeById(measure.endNodeId);
      if (a == null || b == null) continue;
      final sections = _collinearSections(floor, a, b);
      final derived = sections ?? GeometryService.distance(a, b);
      final delta = derived - measure.measuredMm;
      if (delta.abs() >= 5) {
        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.discrepancy,
            '${sections == null ? 'Диагональ/контроль' : 'Сумма участков'} '
            '${measure.label.isEmpty ? measure.id : measure.label}: '
            '${measure.measuredMm.round()} мм против ${derived.round()} мм на плане; '
            'расхождение ${delta.abs().round()} мм',
            math.Point((a.xMm + b.xMm) / 2, (a.yMm + b.yMm) / 2),
            deltaMm: delta,
          ),
        );
      }
    }
    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta?.ceilingHeightMm == null) {
        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.missingHeight,
            '${meta?.name ?? 'Помещение'}: высота не измерена, используется высота этажа',
            face.centroid,
          ),
        );
      }
      if (face.nodeIds.toSet().length >= 4 &&
          !floor.measures.any((m) {
            final a = floor.nodeById(m.startNodeId);
            final b = floor.nodeById(m.endNodeId);
            return face.nodeIds.contains(m.startNodeId) &&
                face.nodeIds.contains(m.endNodeId) &&
                a != null &&
                b != null &&
                (a.xMm - b.xMm).abs() > 150 &&
                (a.yMm - b.yMm).abs() > 150;
          })) {
        issues.add(
          MeasurementIssue(
            MeasurementIssueKind.missingDiagonal,
            '${meta?.name ?? 'Помещение'}: нет контрольной диагонали',
            face.centroid,
          ),
        );
      }
    }
    return issues;
  }
}
