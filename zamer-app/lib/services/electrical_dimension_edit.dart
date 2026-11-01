import '../models/models.dart';
import '../models/electrical_mounting.dart';
import 'electrical_datum_assignment_service.dart';
import 'electrical_mounting_service.dart';
import 'electrical_wall_datum_service.dart';
import 'electrical_frame_geometry.dart';

/// Validate a detached floor before the editor records undo or persists.
class ElectricalDimensionEdit {
  static ElectricalPoint propose(FloorPlan floor, ElectricalPoint point,
      String datumId, double signedDistanceMm) {
    final assigned = point.datumAssignment;
    if (assigned == null) throw const FormatException('Чистовая база не задана.');
    if (!signedDistanceMm.isFinite) throw const FormatException('Введите число.');
    final copy = FloorPlan.fromJson(floor.toJson());
    final next = copy.electricalPoints.singleWhere((p) => p.id == point.id);
    final wall = copy.wallById(assigned.wallId);
    if (wall == null) throw const FormatException('Стена удалена.');
    final catalog = ElectricalWallDatumService.catalog(copy, wall.id, assigned.wallSide);
    final bases = catalog.datums.where((d) => d.id == datumId && d.finishedReference);
    if (bases.length != 1) throw const FormatException('Чистовая база больше не доступна.');
    final station = bases.single.uMm + signedDistanceMm;
    ElectricalMountingService.apply(copy, next, ElectricalMounting(
      wallId: wall.id, datumNodeId: wall.startNodeId, datumName: 'Узел A (ось стены)',
      datumInsetMm: 0, distanceMm: station,
      heightAboveFinishedFloorMm: point.heightMm, wallSide: assigned.wallSide,
      geometrySnapshot: ElectricalMountingService.snapshot(copy, wall),
      source: MountingSource.designed,
      finishedFloorAboveSlabMm: point.mounting?.finishedFloorAboveSlabMm,
    ));
    final issue = ElectricalFrameGeometry.placementIssue(copy, next) ??
        ElectricalFrameGeometry.conflictWithFrames(copy, next);
    if (issue != null) throw FormatException(issue);
    next.datumAssignment = ElectricalDatumAssignmentService.prepare(
      copy, next.id, wall.id, assigned.wallSide, datumId);
    return next;
  }
}
