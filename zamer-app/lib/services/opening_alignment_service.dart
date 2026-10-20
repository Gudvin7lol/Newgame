import 'dart:math' as math;

import '../models/models.dart';

/// Geometric opening targets, measured from the HOST WALL AXIS. Snap applies
/// to the centre of a frame, not to a leaf tip or a rendered wall edge.
class OpeningAlignmentTarget {
  const OpeningAlignmentTarget(this.offsetMm, this.label);
  final double offsetMm;
  final String label;
}

class OpeningAlignmentService {
  const OpeningAlignmentService._();

  static OpeningAlignmentTarget? snap(
    FloorPlan floor, PlanWall host, {
    required double desiredOffsetMm,
    required double openingWidthMm,
    double toleranceMm = 130,
  }) {
    final a = floor.nodeById(host.startNodeId);
    final b = floor.nodeById(host.endNodeId);
    final hostLen = floor.wallLengthMm(host);
    if (a == null || b == null || hostLen <= openingWidthMm) return null;
    final ux = (b.xMm - a.xMm) / hostLen;
    final uy = (b.yMm - a.yMm) / hostLen;
    final requestedCenter = desiredOffsetMm + openingWidthMm / 2;
    final options = <OpeningAlignmentTarget>[];

    void candidate(double center, String label) {
      final offset = center - openingWidthMm / 2;
      if (offset < 80 || offset + openingWidthMm > hostLen - 80 ||
          (center - requestedCenter).abs() > toleranceMm) return;
      options.add(OpeningAlignmentTarget(offset, label));
    }

    // Parallel walls across the room. Door centres can align along the host
    // axis even when the two wall origins and directions differ.
    for (final wall in floor.walls) {
      if (wall.id == host.id || wall.isCurved) continue;
      final c = floor.nodeById(wall.startNodeId);
      final d = floor.nodeById(wall.endNodeId);
      final len = floor.wallLengthMm(wall);
      if (c == null || d == null || len < 1) continue;
      final vx = (d.xMm - c.xMm) / len;
      final vy = (d.yMm - c.yMm) / len;
      if ((ux * vy - uy * vx).abs() > .012) continue;
      final wallDistance = ((c.xMm - a.xMm) * uy -
          (c.yMm - a.yMm) * ux).abs();
      if (wallDistance < host.thicknessMm + wall.thicknessMm + 120) continue;
      for (final opening in wall.openings) {
        if (opening.type != OpeningType.door) continue;
        final cx = c.xMm + vx *
            (opening.offsetFromStartMm + opening.widthMm / 2);
        final cy = c.yMm + vy *
            (opening.offsetFromStartMm + opening.widthMm / 2);
        final projected = (cx - a.xMm) * ux + (cy - a.yMm) * uy;
        candidate(projected, 'По оси двери напротив');
      }
    }

    // Segment-centres between real wall junctions. Each node belonging to
    // another wall at the host axis forms a segment boundary.
    final stops = <double>[0, hostLen];
    for (final node in floor.nodes) {
      if (node.id == a.id || node.id == b.id ||
          floor.nodeDegree(node.id) < 2) continue;
      final x = node.xMm - a.xMm, y = node.yMm - a.yMm;
      final along = x * ux + y * uy;
      final lateral = (x * uy - y * ux).abs();
      if (along > 100 && along < hostLen - 100 && lateral < 25) {
        stops.add(along);
      }
    }
    stops.sort();
    for (var i = 1; i < stops.length; i++) {
      if (requestedCenter >= stops[i - 1] &&
          requestedCenter <= stops[i]) {
        candidate((stops[i - 1] + stops[i]) / 2, 'Центр участка стены');
      }
    }
    candidate(hostLen / 2, 'Центр стены');
    if (options.isEmpty) return null;
    // Opposite-door axis wins when several construction guides coincide.
    options.sort((a, b) {
      final pa = a.label == 'По оси двери напротив' ? 0 : 1;
      final pb = b.label == 'По оси двери напротив' ? 0 : 1;
      final primary = pa.compareTo(pb);
      if (primary != 0) return primary;
      return (a.offsetMm - desiredOffsetMm).abs()
          .compareTo((b.offsetMm - desiredOffsetMm).abs());
    });
    return options.first;
  }
}
