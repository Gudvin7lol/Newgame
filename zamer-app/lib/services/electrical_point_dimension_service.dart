import 'dart:math' as math;

import '../models/electrical_mounting.dart';
import '../models/models.dart';
import 'electrical_frame_geometry.dart';
import 'electrical_mounting_service.dart';

/// Pure station edit. Coordinates are project millimetres, never screen pixels.
/// A proposal is validated before any project object is mutated.
class ElectricalPointDimensionService {
  const ElectricalPointDimensionService._();

  static ElectricalPoint prepare(
    FloorPlan floor, ElectricalPoint point, double stationMm,
  ) {
    if (!stationMm.isFinite || (stationMm - stationMm.round()).abs() > .0001) {
      throw const FormatException('Введите целое расстояние в миллиметрах.');
    }
    final wall = point.wallId == null
        ? null : floor.wallById(point.wallId!);
    if (wall == null || wall.isCurved || wall.demolition) {
      throw const FormatException('Точка должна быть на существующей прямой стене.');
    }
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    final length = floor.wallLengthMm(wall);
    if (start == null || end == null || !length.isFinite || length <= 0) {
      throw const FormatException('Геометрия стены недоступна.');
    }
    if (stationMm < 0 || stationMm > length) {
      throw FormatException(
          'Расстояние должно быть от 0 до ${length.round()} мм.');
    }
    final proposed = ElectricalPoint.fromJson(point.toJson());
    final currentMount = point.mounting;
    if (currentMount != null) {
      final currentProblem = ElectricalMountingService.problem(floor, point);
      if (currentProblem != null) {
        throw FormatException(
            'Сначала обновите монтажную базу: $currentProblem');
      }
      final fromStart = currentMount.datumNodeId == wall.startNodeId;
      final relativeMm = (fromStart
          ? stationMm : length - stationMm) - currentMount.datumInsetMm;
      if (relativeMm < 0) {
        throw const FormatException(
            'Новая точка оказывается за выбранной монтажной базой.');
      }
      final updated = ElectricalMounting(
        wallId: currentMount.wallId,
        datumNodeId: currentMount.datumNodeId,
        datumName: currentMount.datumName,
        datumInsetMm: currentMount.datumInsetMm,
        distanceMm: relativeMm,
        heightAboveFinishedFloorMm: currentMount.heightAboveFinishedFloorMm,
        wallSide: currentMount.wallSide,
        geometrySnapshot: currentMount.geometrySnapshot,
        source: currentMount.source,
        finishedFloorAboveSlabMm: currentMount.finishedFloorAboveSlabMm,
        measurementUncertaintyMm: currentMount.measurementUncertaintyMm,
      );
      ElectricalMountingService.apply(floor, proposed, updated);
    } else {
      final t = stationMm / length;
      proposed.wallOffsetMm = stationMm;
      proposed.xMm = start.xMm + (end.xMm - start.xMm) * t;
      proposed.yMm = start.yMm + (end.yMm - start.yMm) * t;
    }
    // Reject an electrical centre in a door/window opening at this Z.
    // Frames receive full-envelope checks below.
    for (final opening in wall.openings) {
      if (stationMm >= opening.offsetFromStartMm &&
          stationMm <= opening.offsetFromStartMm + opening.widthMm &&
          proposed.heightMm >= opening.sillHeightMm &&
          proposed.heightMm <=
              opening.sillHeightMm + opening.heightMm) {
        throw FormatException(
            'Точка попадает в проём ${opening.id}.');
      }
    }
    final issue = ElectricalFrameGeometry.placementIssue(
        floor, proposed) ??
        ElectricalFrameGeometry.conflictWithFrames(floor, proposed);
    if (issue != null) throw FormatException(issue);
    // A saved finished datum intentionally retains its original evidence.
    // After movement it becomes 'stale' until explicitly reconfirmed.
    assert(proposed.wallId == point.wallId);
    assert(proposed.wallSide == point.wallSide);
    assert((proposed.heightMm - point.heightMm).abs() < .001);
    assert(math.Point(proposed.xMm, proposed.yMm) !=
        const math.Point<double>(double.nan, double.nan));
    return proposed;
  }
}
