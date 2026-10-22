import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Filled planimetric bodies rather than independent square-capped strokes.
/// A thin wall terminating at the centre line of a thick wall merges cleanly
/// into its host. There is no second overlapping stroke cap or dark internal
/// shadow at a shared CAD node.
class CadWallJoinGeometry {
  static Map<ProjectLayer, Path> bodies({
    required FloorPlan floor,
    required double mmToPx,
    required Offset origin,
    required Set<ProjectLayer> visibleLayers,
  }) {
    final paths = <ProjectLayer, Path>{
      for (final layer in ProjectLayer.values) layer: Path(),
    };
    final attached = <String, List<PlanWall>>{};

    for (final wall in floor.walls) {
      final stage =
          wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
      if (!visibleLayers.contains(stage) || wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final polygon = wallPolygon(a, b, wall.thicknessMm, mmToPx, origin);
      if (polygon.isEmpty) continue;
      _unionPolygon(paths, stage, polygon);
      attached.putIfAbsent(a.id, () => []).add(wall);
      attached.putIfAbsent(b.id, () => []).add(wall);
    }

    // At a simple L joint the two square-ended strips leave a gap at the
    // outside corner. A small mitred polygon closes only that outer quadrant.
    // At a T junction the host wall fills the centre and NO mitre should be
    // added, even when the two wall thicknesses are different.
    for (final entry in attached.entries) {
      if (entry.value.length != 2) continue;
      final wallA = entry.value[0];
      final wallB = entry.value[1];
      final node = floor.nodeById(entry.key);
      if (node == null) continue;
      final otherA = floor.nodeById(wallA.startNodeId == node.id
          ? wallA.endNodeId : wallA.startNodeId);
      final otherB = floor.nodeById(wallB.startNodeId == node.id
          ? wallB.endNodeId : wallB.startNodeId);
      if (otherA == null || otherB == null) continue;
      final patch = cornerPatch(
        center: node,
        a: otherA,
        b: otherB,
        thicknessA: wallA.thicknessMm,
        thicknessB: wallB.thicknessMm,
        mmToPx: mmToPx,
        origin: origin,
      );
      if (patch.isEmpty) continue;
      // If both walls are the same stage, the join matches their solid.
      // Otherwise use the stage of the thicker member so no narrow
      // demolition/proposed edge paints over a wide existing wall.
      final fillStage = wallA.thicknessMm >= wallB.thicknessMm
          ? (wallA.demolition ? ProjectLayer.demolition : wallA.projectLayer)
          : (wallB.demolition ? ProjectLayer.demolition : wallB.projectLayer);
      _unionPolygon(paths, fillStage, patch);
    }
    return paths;
  }

  // Boolean union removes internal edges and is independent of polygon
  // winding. Appending contours alone can cancel the fill at a reversed
  // corner, and stroking those contours exposes seams through a solid wall.
  static void _unionPolygon(
    Map<ProjectLayer, Path> paths,
    ProjectLayer layer,
    List<Offset> polygon,
  ) {
    paths[layer] = Path.combine(
      PathOperation.union,
      paths[layer]!,
      Path()..addPolygon(polygon, true),
    );
  }

  static List<Offset> wallPolygon(
    PlanNode a,
    PlanNode b,
    double thicknessMm,
    double mmToPx,
    Offset origin,
  ) {
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < .001 || thicknessMm <= 0) return const [];
    final half = thicknessMm * mmToPx / 2;
    final nx = -dy / d * half;
    final ny = dx / d * half;
    final ax = origin.dx + a.xMm * mmToPx;
    final ay = origin.dy + a.yMm * mmToPx;
    final bx = origin.dx + b.xMm * mmToPx;
    final by = origin.dy + b.yMm * mmToPx;
    return [
      Offset(ax + nx, ay + ny),
      Offset(bx + nx, by + ny),
      Offset(bx - nx, by - ny),
      Offset(ax - nx, ay - ny),
    ];
  }

  static List<Offset> cornerPatch({
    required PlanNode center,
    required PlanNode a,
    required PlanNode b,
    required double thicknessA,
    required double thicknessB,
    required double mmToPx,
    required Offset origin,
  }) {
    final ax = a.xMm - center.xMm, ay = a.yMm - center.yMm;
    final bx = b.xMm - center.xMm, by = b.yMm - center.yMm;
    final la = math.sqrt(ax * ax + ay * ay);
    final lb = math.sqrt(bx * bx + by * by);
    if (la < 1 || lb < 1) return const [];
    final ua = math.Point<double>(ax / la, ay / la);
    final ub = math.Point<double>(bx / lb, by / lb);
    final cross = ua.x * ub.y - ua.y * ub.x;
    if (cross.abs() < .15) return const [];
    final sign = cross.sign;
    final wa = thicknessA / 2;
    final wb = thicknessB / 2;
    final normalA = math.Point<double>(ua.y * wa * sign,
        -ua.x * wa * sign);
    final normalB = math.Point<double>(-ub.y * wb * sign,
        ub.x * wb * sign);
    final p = math.Point<double>(
      center.xMm + normalA.x, center.yMm + normalA.y);
    final q = math.Point<double>(
      center.xMm + normalB.x, center.yMm + normalB.y);
    // Intersection of the two wall side lines.
    final qx = q.x - p.x, qy = q.y - p.y;
    final t = (qx * ub.y - qy * ub.x) / cross;
    final corner = math.Point<double>(
      p.x + ua.x * t, p.y + ua.y * t,
    );
    final reach = math.sqrt(math.pow(corner.x - center.xMm, 2) +
        math.pow(corner.y - center.yMm, 2));
    if (!reach.isFinite || reach > 4 * math.max(thicknessA, thicknessB)) {
      return const [];
    }
    Offset toCanvas(math.Point<double> pt) =>
      origin + Offset(pt.x * mmToPx, pt.y * mmToPx);
    return [
      toCanvas(p),
      toCanvas(corner),
      toCanvas(q),
      toCanvas(math.Point<double>(center.xMm, center.yMm)),
    ];
  }
}
