import 'dart:math' as math;

import '../models/models.dart';

/// Doorway surfaces joining rooms with one continuous floor pattern.
/// The opening is bounded by the two wall faces rather than the room polygons,
/// which stop at those faces and otherwise leave a bare strip in the threshold.
class FloorContinuityService {
  static List<List<math.Point<double>>> doorThresholds(
    FloorPlan floor,
    List<RoomFace> selected,
  ) {
    if (selected.length < 2) return const [];
    final selectedWallCounts = <String, int>{};
    for (final face in selected) {
      for (final id in face.edges.map((edge) => edge.wallId).toSet()) {
        selectedWallCounts[id] = (selectedWallCounts[id] ?? 0) + 1;
      }
    }
    final result = <List<math.Point<double>>>[];
    for (final wall in floor.walls) {
      if (selectedWallCounts[wall.id] != 2 ||
          wall.demolition ||
          wall.projectLayer == ProjectLayer.demolition) {
        continue;
      }
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final length = floor.wallLengthMm(wall);
      if (length < 1) continue;
      final ux = (b.xMm - a.xMm) / length;
      final uy = (b.yMm - a.yMm) / length;
      final halfWidth = wall.thicknessMm / 2 + 12;
      final nx = -uy * halfWidth;
      final ny = ux * halfWidth;
      for (final opening in wall.openings) {
        if (opening.type != OpeningType.door || opening.sillHeightMm > 35) {
          continue;
        }
        final start = opening.offsetFromStartMm.clamp(0, length).toDouble();
        final end = (opening.offsetFromStartMm + opening.widthMm)
            .clamp(0, length)
            .toDouble();
        if (end - start < 20) continue;
        final x0 = a.xMm + ux * start;
        final y0 = a.yMm + uy * start;
        final x1 = a.xMm + ux * end;
        final y1 = a.yMm + uy * end;
        result.add([
          math.Point(x0 + nx, y0 + ny),
          math.Point(x1 + nx, y1 + ny),
          math.Point(x1 - nx, y1 - ny),
          math.Point(x0 - nx, y0 - ny),
        ]);
      }
    }
    return result;
  }
}
