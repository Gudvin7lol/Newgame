import 'dart:math' as math;

import '../models/models.dart';

/// Doorway floor boundary in real-world millimetres. The dividing line is
/// 20 mm beyond the finished-side wall face in the room the door opens into.
/// Room membership is sampled from actual interior polygons, not wall IDs.
class DoorwayFloorService {
  const DoorwayFloorService._();

  static const double jointInsetMm = 20;

  static bool opensToPositiveSide(DoorSwing swing) =>
      swing == DoorSwing.leftIn || swing == DoorSwing.rightIn;

  static double jointFromWallAxisMm(PlanWall wall, WallOpening opening) {
    final sign = opensToPositiveSide(opening.doorSwing) ? 1.0 : -1.0;
    return sign * (wall.thicknessMm / 2 + jointInsetMm);
  }

  static bool _inside(math.Point<double> p, List<math.Point<double>> points) {
    if (points.length < 3) return false;
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i], b = points[j];
      if ((a.y > p.y) != (b.y > p.y)) {
        final x = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
        if (p.x < x) inside = !inside;
      }
    }
    return inside;
  }

  static RoomFace? _faceAt(List<RoomFace> faces, math.Point<double> point) {
    for (final face in faces) {
      if (_inside(point, face.innerPolygon)) return face;
    }
    return null;
  }

  static ({RoomFace? positive, RoomFace? negative}) roomsByDoor(
    FloorPlan floor,
    PlanWall wall,
    WallOpening opening,
    List<RoomFace> faces,
  ) {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return (positive: null, negative: null);
    final len = math.sqrt(math.pow(b.xMm - a.xMm, 2) +
        math.pow(b.yMm - a.yMm, 2));
    if (len < 1) return (positive: null, negative: null);
    final along = (opening.offsetFromStartMm + opening.widthMm / 2)
        .clamp(0.0, len).toDouble();
    final cx = a.xMm + (b.xMm - a.xMm) * along / len;
    final cy = a.yMm + (b.yMm - a.yMm) * along / len;
    final nx = -(b.yMm - a.yMm) / len;
    final ny = (b.xMm - a.xMm) / len;
    final distance = wall.thicknessMm / 2 + 80;
    return (
      positive: _faceAt(
        faces, math.Point(cx + nx * distance, cy + ny * distance)),
      negative: _faceAt(
        faces, math.Point(cx - nx * distance, cy - ny * distance)),
    );
  }

  /// Explicitly joined floor contours should not show a threshold seam.
  static bool continuous(
    FloorPlan floor,
    RoomFace? positive,
    RoomFace? negative,
  ) {
    if (positive == null || negative == null) return false;
    if (positive.key == negative.key) return true;
    RoomMeta? meta(RoomFace face) {
      for (final candidate in floor.roomMetas) {
        if (candidate.faceKey == face.key) return candidate;
      }
      return null;
    }
    final a = meta(positive), b = meta(negative);
    return a != null && b != null &&
        floor.carpetRoomIds.contains(a.id) &&
        floor.carpetRoomIds.contains(b.id) &&
        a.materials.floorMaterialId == b.materials.floorMaterialId;
  }
}
