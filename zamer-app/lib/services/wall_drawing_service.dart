import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';

/// The same snap policy is used by touch-based and dimension-based drawing.
/// Geometric targets have priority over visual guides. An angle lock never
/// silently creates a diagonal wall just because a nearby wall was detected.
class WallDrawingTarget {
  const WallDrawingTarget({
    required this.point,
    required this.kind,
    this.targetNodeId,
    this.targetWallId,
    this.facePoint,
  });

  final math.Point<double> point;
  final NodeSnapKind kind;
  final String? targetNodeId;
  final String? targetWallId;
  /// If the user touched a wall's visible face, this records the physical
  /// face point while [point] remains the canonical host wall axis. The
  /// preview can show this conversion instead of silently creating a gap.
  final math.Point<double>? facePoint;

  String get label => facePoint == null
      ? kind.label
      : 'Грань → общая ось';
}

class WallDrawingService {
  static const double minimumLengthMm = 120;
  static const double maximumLengthMm = 100000;

  static double distance(math.Point<double> a, math.Point<double> b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  /// Finds an actual far corner on the current construction ray without
  /// snapping the free endpoint to it prematurely. The UI shows this as a
  /// passive alignment hint while the user is extending a wall.
  static math.Point<double>? alignedCornerAhead(
    FloorPlan floor, {
    required String startNodeId,
    required math.Point<double> currentPoint,
    double toleranceMm = 30,
  }) {
    final start = floor.nodeById(startNodeId);
    if (start == null) return null;
    final dx = currentPoint.x - start.xMm;
    final dy = currentPoint.y - start.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < minimumLengthMm) return null;
    final ux = dx / length, uy = dy / length;
    final junctionIds = <String, int>{};
    for (final wall in floor.walls) {
      junctionIds.update(wall.startNodeId, (v) => v + 1, ifAbsent: () => 1);
      junctionIds.update(wall.endNodeId, (v) => v + 1, ifAbsent: () => 1);
    }
    math.Point<double>? nearest;
    var nearestAlong = double.infinity;
    for (final node in floor.nodes) {
      if (node.id == startNodeId ||
          (junctionIds[node.id] ?? 0) < 2) continue;
      final vx = node.xMm - start.xMm, vy = node.yMm - start.yMm;
      final along = vx * ux + vy * uy;
      final lateral = (vx * uy - vy * ux).abs();
      if (along <= length + 50 || along >= nearestAlong ||
          lateral > toleranceMm) continue;
      nearestAlong = along;
      nearest = math.Point<double>(node.xMm, node.yMm);
    }
    return nearest;
  }

  static math.Point<double> lengthEndpoint({
    required math.Point<double> start,
    required double lengthMm,
    required double angleDegrees,
  }) {
    if (!lengthMm.isFinite ||
        lengthMm < minimumLengthMm ||
        lengthMm > maximumLengthMm ||
        !angleDegrees.isFinite) {
      throw ArgumentError('Недопустимые длина или угол стены');
    }
    final radians = angleDegrees * math.pi / 180;
    return math.Point<double>(
      start.x + math.cos(radians) * lengthMm,
      start.y + math.sin(radians) * lengthMm,
    );
  }

  static WallDrawingTarget snap(
    FloorPlan floor, {
    required String startNodeId,
    required math.Point<double> raw,
    bool enabled = true,
    int angleStepDegrees = 90,
    double nodeCaptureMm = 100,
    double wallCaptureMm = 70,
    bool allowWallFaces = true,
  }) {
    final start = floor.nodeById(startNodeId);
    if (start == null) {
      return WallDrawingTarget(point: raw, kind: NodeSnapKind.none);
    }
    if (!enabled) {
      return WallDrawingTarget(point: raw, kind: NodeSnapKind.none);
    }

    final source = math.Point<double>(start.xMm, start.yMm);
    final vx = raw.x - source.x;
    final vy = raw.y - source.y;
    final distanceRaw = math.sqrt(vx * vx + vy * vy);
    if (distanceRaw < 0.001) {
      return WallDrawingTarget(point: raw, kind: NodeSnapKind.none);
    }

    math.Point<double> candidate = raw;
    var ux = vx / distanceRaw;
    var uy = vy / distanceRaw;
    if (angleStepDegrees != 0) {
      final radians = angleStepDegrees * math.pi / 180;
      final angle = (math.atan2(vy, vx) / radians).round() * radians;
      ux = math.cos(angle);
      uy = math.sin(angle);
      // Project onto the locked axis; do not extend more than the touched
      // distance if a finger falls between 45/90-degree guides.
      final projected = math.max(0.0, vx * ux + vy * uy);
      candidate = math.Point<double>(
        source.x + ux * projected, source.y + uy * projected,
      );
    }

    bool onLockedRay(math.Point<double> point) {
      if (angleStepDegrees == 0) return true;
      final dx = point.x - source.x;
      final dy = point.y - source.y;
      final along = dx * ux + dy * uy;
      final lateral = (dx * uy - dy * ux).abs();
      return along > 0 && lateral <= .5;
    }

    // Prefer an actual shared node instead of generating nearly duplicate
    // junctions. But a node outside an angular guide cannot break the lock.
    PlanNode? nearest;
    var nearestDistance = nodeCaptureMm;
    for (final node in floor.nodes) {
      if (node.id == startNodeId) continue;
      final point = math.Point<double>(node.xMm, node.yMm);
      final d = distance(candidate, point);
      if (d < nearestDistance && onLockedRay(point)) {
        nearestDistance = d;
        nearest = node;
      }
    }
    if (nearest != null) {
      return WallDrawingTarget(
        point: math.Point<double>(nearest.xMm, nearest.yMm),
        kind: NodeSnapKind.node,
        targetNodeId: nearest.id,
      );
    }

    PlanWall? targetWall;
    math.Point<double>? targetPoint;
    NodeSnapKind targetKind = NodeSnapKind.wall;
    math.Point<double>? targetFacePoint;
    var bestDistance = wallCaptureMm;

    for (final wall in floor.walls) {
      if (wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final p = math.Point<double>(a.xMm, a.yMm);
      final q = math.Point<double>(b.xMm, b.yMm);
      final dx = q.x - p.x;
      final dy = q.y - p.y;
      final length2 = dx * dx + dy * dy;
      if (length2 < 1) continue;

      math.Point<double> projected;
      double t;
      if (angleStepDegrees != 0) {
        // Intersection between the orthogonal/45-degree construction ray
        // and a candidate target wall. This creates an *exact* T-junction
        // without silently bending the new segment off its locked angle.
        final denominator = ux * dy - uy * dx;
        if (denominator.abs() < 1e-9) continue;
        final ax = p.x - source.x;
        final ay = p.y - source.y;
        final along = (ax * dy - ay * dx) / denominator;
        t = (ax * uy - ay * ux) / denominator;
        if (along < 40 || t < 0.01 || t > 0.99) continue;
        projected = math.Point<double>(
          source.x + ux * along, source.y + uy * along,
        );
      } else {
        t = ((candidate.x - p.x) * dx +
                (candidate.y - p.y) * dy) / length2;
        if (t < 0.01 || t > 0.99) continue;
        projected = math.Point<double>(p.x + dx * t, p.y + dy * t);
      }

      final axisDistance = distance(candidate, projected);
      final half = wall.thicknessMm / 2;
      final faceDistance = allowWallFaces
          ? (axisDistance - half).abs() : double.infinity;
      final d = math.min(axisDistance, faceDistance);
      if (d < bestDistance) {
        bestDistance = d;
        targetWall = wall;
        targetPoint = projected;
        targetFacePoint = null;
        if (faceDistance < axisDistance && half > 0) {
          final normalX = -dy / math.sqrt(length2);
          final normalY = dx / math.sqrt(length2);
          final sign = (candidate.x - projected.x) * normalX +
                  (candidate.y - projected.y) * normalY >= 0 ? 1.0 : -1.0;
          targetFacePoint = math.Point<double>(
            projected.x + normalX * half * sign,
            projected.y + normalY * half * sign,
          );
        }
        final midpoint = math.Point<double>(
          (p.x + q.x) / 2, (p.y + q.y) / 2,
        );
        final atMiddle = distance(midpoint, projected) <=
            nodeCaptureMm * .25 &&
            distance(candidate, midpoint) < nodeCaptureMm * .25 &&
            onLockedRay(midpoint);
        targetKind = atMiddle
            ? NodeSnapKind.midpoint : NodeSnapKind.wall;
        if (atMiddle) {
          targetPoint = midpoint;
          targetFacePoint = null;
        }
      }
    }

    if (targetWall != null) {
      return WallDrawingTarget(
        point: targetPoint!,
        kind: targetKind,
        targetWallId: targetWall.id,
        facePoint: targetFacePoint,
      );
    }

    return WallDrawingTarget(
      point: candidate,
      kind: angleStepDegrees == 45
          ? NodeSnapKind.angle45
          : angleStepDegrees == 90
              ? NodeSnapKind.ortho
              : NodeSnapKind.none,
    );
  }
}
