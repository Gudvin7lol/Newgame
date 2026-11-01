import 'package:flutter/painting.dart';
import '../models/models.dart';
import 'electrical_datum_assignment_service.dart';
import 'electrical_mounting_service.dart';
import 'electrical_wall_face_service.dart';

/// A dimension is derived from saved references, never from screen pixels.
class ElectricalPlanDimension {
  const ElectricalPlanDimension({required this.base, required this.center,
    required this.distanceMm, required this.heightMm, required this.baseName,
    required this.finished, this.problem});
  final Offset base, center;
  final double distanceMm, heightMm;
  final String baseName;
  final bool finished;
  final String? problem;

  static ElectricalPlanDimension? resolve(FloorPlan floor, ElectricalPoint point) {
    final assignment = point.datumAssignment;
    final mounting = point.mounting;
    if (assignment == null && mounting == null) return null;
    final center = Offset(point.xMm, point.yMm);
    final issue = assignment != null
        ? ElectricalDatumAssignmentService.problem(floor, point)
        : ElectricalMountingService.problem(floor, point);
    if (issue != null) return ElectricalPlanDimension(base: center,
      center: center, distanceMm: 0, heightMm: point.heightMm,
      baseName: 'Привязка устарела', finished: assignment != null, problem: issue);
    if (assignment != null) {
      final wall = floor.wallById(assignment.wallId)!;
      final a = floor.nodeById(wall.startNodeId)!;
      final b = floor.nodeById(wall.endNodeId)!;
      final unit = Offset(b.xMm - a.xMm, b.yMm - a.yMm) /
          floor.wallLengthMm(wall);
      final finish = ElectricalWallFaceService.saved(wall, assignment.wallSide);
      final shift = Offset(-unit.dy, unit.dx) * assignment.wallSide.toDouble() *
          (wall.thicknessMm / 2 + (finish?.thicknessMm ?? 0));
      return ElectricalPlanDimension(
        base: Offset(a.xMm, a.yMm) + unit * assignment.datumUMm + shift,
        center: Offset(a.xMm, a.yMm) + unit * assignment.pointUMm + shift,
        distanceMm: assignment.fromDatumMm.abs(), heightMm: point.heightMm,
        baseName: assignment.datumTitle, finished: true);
    }
    final pos = ElectricalMountingService.resolve(floor, mounting!);
    return ElectricalPlanDimension(base: Offset(pos.datumXMm, pos.datumYMm),
      center: Offset(pos.xMm, pos.yMm), distanceMm: mounting.distanceMm,
      heightMm: point.heightMm, baseName: mounting.datumName, finished: false);
  }
}
