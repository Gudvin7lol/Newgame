import 'dart:math' as math;

import '../models/models.dart';

/// A visible warning for nodes that *look* connected on a phone but still
/// belong to different wall endpoints/topological edges. Diagnostics never
/// modify user geometry or guess how a room should close.
enum WallTopologyGapKind { detachedNodes, detachedWallEnd }

class WallTopologyGap {
  const WallTopologyGap({
    required this.sourceNodeId,
    required this.target,
    required this.distanceMm,
    required this.kind,
    this.targetNodeId,
    this.targetWallId,
  });

  final String sourceNodeId;
  final math.Point<double> target;
  final double distanceMm;
  final WallTopologyGapKind kind;
  final String? targetNodeId;
  final String? targetWallId;
}

class WallTopologyDiagnostics {
  const WallTopologyDiagnostics._();

  static const double _epsilonMm = .5;

  /// Only endpoints of degree one participate: ordinary T/cross junctions
  /// and intentionally shared room vertices should never be called gaps.
  /// A zero-distance pair of *different* nodes is still a broken join.
  static List<WallTopologyGap> findGaps(
    FloorPlan floor, {
    double maxGapMm = 40,
    int maxResults = 24,
  }) {
    if (!maxGapMm.isFinite || maxGapMm <= 0 || maxResults <= 0) {
      return const [];
    }
    final endpoints = floor.nodes
        .where((n) => floor.nodeDegree(n.id) == 1).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final nodes = floor.nodes.where((n) => floor.nodeDegree(n.id) > 0).toList();
    final results = <WallTopologyGap>[];
    final emittedPairs = <String>{};

    for (final from in endpoints) {
      final here = math.Point<double>(from.xMm, from.yMm);
      if (!here.x.isFinite || !here.y.isFinite) continue;
      WallTopologyGap? closest;

      for (final other in nodes) {
        if (other.id == from.id) continue;
        if (!other.xMm.isFinite || !other.yMm.isFinite) continue;
        final d = _distance(here,
            math.Point<double>(other.xMm, other.yMm));
        if (d > maxGapMm || (closest != null && d >= closest.distanceMm)) {
          continue;
        }
        closest = WallTopologyGap(
          sourceNodeId: from.id,
          target: math.Point<double>(other.xMm, other.yMm),
          distanceMm: d,
          kind: WallTopologyGapKind.detachedNodes,
          targetNodeId: other.id,
        );
      }

      for (final wall in floor.walls) {
        if (wall.isCurved ||
            wall.startNodeId == from.id ||
            wall.endNodeId == from.id) continue;
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a == null || b == null) continue;
        final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
        final length2 = dx * dx + dy * dy;
        if (length2 <= _epsilonMm || !length2.isFinite) continue;
        final t = ((from.xMm - a.xMm) * dx +
                (from.yMm - a.yMm) * dy) / length2;
        // Endpoint-to-endpoint mismatches belong to the node-pair check.
        if (t <= .001 || t >= .999) continue;
        final projected = math.Point<double>(
            a.xMm + dx * t, a.yMm + dy * t);
        final d = _distance(here, projected);
        if (d > maxGapMm || (closest != null && d >= closest.distanceMm)) {
          continue;
        }
        closest = WallTopologyGap(
          sourceNodeId: from.id, target: projected,
          distanceMm: d,
          kind: WallTopologyGapKind.detachedWallEnd,
          targetWallId: wall.id,
        );
      }

      if (closest == null) continue;
      final otherId = closest.targetNodeId;
      if (otherId != null && floor.nodeDegree(otherId) == 1) {
        final ordered = [from.id, otherId]..sort();
        if (!emittedPairs.add('${ordered.first}|${ordered.last}')) continue;
      }
      results.add(closest);
      if (results.length >= maxResults) break;
    }
    return results;
  }

  static double _distance(math.Point<double> a, math.Point<double> b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
}
