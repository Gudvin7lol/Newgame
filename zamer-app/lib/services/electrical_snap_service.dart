import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';

/// Geometric capture in project millimetres. Capture radius is measured
/// on screen, so the same finger movement behaves consistently under zoom.
/// No wiring connectivity is inferred from snaps.
class ElectricalSnapResult {
  const ElectricalSnapResult(this.position, this.reason);
  final math.Point<double> position;
  final String reason;
}

class ElectricalSnapService {
  const ElectricalSnapService._();

  static double stepMm(double pixelsPerMm) =>
      pixelsPerMm >= .07 ? 10 : 50;

  static double captureMm(double pixelsPerMm, {double capturePx = 12}) {
    if (!pixelsPerMm.isFinite || pixelsPerMm <= 0) {
      throw const FormatException('Некорректный масштаб плана.');
    }
    return (capturePx / pixelsPerMm).clamp(10.0, 400.0).toDouble();
  }

  /// Along-wall dimension measured from the oriented start node.
  /// Prefers meaningful axes (opening edges, wall midpoint) within screen
  /// capture radius; otherwise uses a precise zoom-adaptive millimetre grid.
  static double wallOffset(
    FloorPlan floor, PlanWall wall, double rawOffsetMm,
    double pixelsPerMm,
  ) {
    final length = floor.wallLengthMm(wall);
    if (!length.isFinite || length <= 0 || !rawOffsetMm.isFinite) {
      throw const FormatException('Невозможно определить станцию на стене.');
    }
    final radius = captureMm(pixelsPerMm);
    final anchors = <double>[0, length, length / 2];
    for (final opening in wall.openings) {
      anchors.add(opening.offsetFromStartMm);
      anchors.add(opening.offsetFromStartMm + opening.widthMm);
    }
    double? closest;
    var bestDistance = radius;
    for (final anchor in anchors) {
      if (anchor < 0 || anchor > length) continue;
      final delta = (anchor - rawOffsetMm).abs();
      if (delta < bestDistance) {
        closest = anchor;
        bestDistance = delta;
      }
    }
    if (closest != null) return closest;
    final step = stepMm(pixelsPerMm);
    return ((rawOffsetMm / step).round() * step)
        .clamp(0.0, length).toDouble();
  }

  /// Light snapping honours room centroid, other light axes, then grid.
  /// Each axis is independent; one-axis capture does not pull the other.
  static ElectricalSnapResult light(
    FloorPlan floor, math.Point<double> raw, double pixelsPerMm, {
    String? movingPointId,
  }) {
    if (!raw.x.isFinite || !raw.y.isFinite) {
      throw const FormatException('Некорректное положение светильника.');
    }
    final step = stepMm(pixelsPerMm);
    final maxDistance = captureMm(pixelsPerMm);
    var x = (raw.x / step).round() * step.toDouble();
    var y = (raw.y / step).round() * step.toDouble();
    var reason = 'сетка ${step.toInt()} мм';
    // The centre of a room is a stronger, two-axis anchor.
    var closestRoom = maxDistance;
    for (final room in GeometryService.roomFaces(floor)) {
      final dx = room.centroid.x - raw.x;
      final dy = room.centroid.y - raw.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < closestRoom) {
        closestRoom = d;
        x = room.centroid.x;
        y = room.centroid.y;
        reason = 'центр помещения';
      }
    }
    if (closestRoom < maxDistance) {
      return ElectricalSnapResult(math.Point<double>(x, y), reason);
    }
    var bestX = maxDistance;
    var bestY = maxDistance;
    for (final point in floor.electricalPoints) {
      if (point.id == movingPointId ||
          point.type != ElectricalPointType.ceilingLight) continue;
      final dx = (point.xMm - raw.x).abs();
      final dy = (point.yMm - raw.y).abs();
      if (dx < bestX) { bestX = dx; x = point.xMm; reason = 'ось светильника'; }
      if (dy < bestY) { bestY = dy; y = point.yMm; reason = 'ось светильника'; }
    }
    return ElectricalSnapResult(math.Point<double>(x, y), reason);
  }
}
