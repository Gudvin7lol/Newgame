import '../models/electrical_datum_assignment.dart';
import '../models/models.dart';
import 'electrical_wall_datum_service.dart';

/// An assignment is a stored dimension label, NOT an auto-positioning or
/// approval operation. The legacy mounting base and XYZ remain untouched.
class ElectricalDatumAssignmentService {
  const ElectricalDatumAssignmentService._();

  static ElectricalPoint _point(FloorPlan floor, String pointId) {
    final points = floor.electricalPoints.where((p) => p.id == pointId).toList();
    if (points.length != 1) {
      throw const FormatException(
          'Электроточка не найдена или её идентификатор не уникален.');
    }
    return points.single;
  }

  /// Compute, validate and return a detached object. This never writes.
  static ElectricalDatumAssignment prepare(
      FloorPlan floor, String pointId, String wallId, int wallSide,
      String datumId) {
    final point = _point(floor, pointId);
    if (point.wallId != wallId || point.wallSide != wallSide) {
      throw const FormatException(
          'Электроточка не закреплена на выбранной стороне стены.');
    }
    final catalog = ElectricalWallDatumService.catalog(
        floor, wallId, wallSide);
    final candidates = catalog.datums.where((d) => d.id == datumId).toList();
    if (candidates.length != 1) {
      throw const FormatException(
          'Монтажная база больше не существует или неоднозначна.');
    }
    final datum = candidates.single;
    if (!datum.finishedReference) {
      throw const FormatException(
          'Черновая грань проёма не подходит для сохранения '
          'чистовой монтажной привязки.');
    }
    final dimensions = ElectricalWallDatumService.dimensions(
        floor, catalog, datum)
        .where((d) => d.pointId == pointId).toList();
    if (dimensions.length != 1) {
      throw const FormatException(
          'Центр электроточки вне стены или координаты некорректны.');
    }
    final d = dimensions.single;
    if (!d.uMm.isFinite || !d.heightMm.isFinite ||
        !d.fromDatumMm.isFinite || !datum.uMm.isFinite ||
        d.heightMm < 0) {
      throw const FormatException('Невозможно рассчитать точный размер.');
    }
    return ElectricalDatumAssignment(
      wallId: wallId, wallSide: wallSide,
      datumId: datum.id,
      datumTitle: datum.title,
      datumUMm: datum.uMm,
      pointUMm: d.uMm,
      pointHeightMm: d.heightMm,
      fromDatumMm: d.fromDatumMm,
      geometrySnapshot: catalog.geometrySnapshot,
    );
  }

  /// Null means the saved calculated reference matches project geometry
  /// and point coordinates. NOT verified for drilling, installation or code.
  static String? problem(FloorPlan floor, ElectricalPoint point) {
    final stored = point.datumAssignment;
    if (stored == null) return 'Монтажная база не закреплена.';
    try {
      final current = prepare(floor, point.id, stored.wallId,
          stored.wallSide, stored.datumId);
      if (current.geometrySnapshot != stored.geometrySnapshot ||
          current.datumTitle != stored.datumTitle ||
          (current.datumUMm - stored.datumUMm).abs() > .001 ||
          (current.pointUMm - stored.pointUMm).abs() > .001 ||
          (current.pointHeightMm - stored.pointHeightMm).abs() > .001 ||
          (current.fromDatumMm - stored.fromDatumMm).abs() > .001) {
        return 'Привязка устарела после изменения плана или точки. '
            'Пересчитайте и подтвердите заново.';
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  /// Parent owns _pushUndo and persistence; validate again before mutation.
  static void apply(FloorPlan floor, String pointId,
      ElectricalDatumAssignment? assignment) {
    final point = _point(floor, pointId);
    if (assignment != null) {
      final checked = prepare(floor, pointId,
          assignment.wallId, assignment.wallSide, assignment.datumId);
      if (checked.geometrySnapshot != assignment.geometrySnapshot ||
          (checked.fromDatumMm - assignment.fromDatumMm).abs() > .001 ||
          (checked.pointHeightMm - assignment.pointHeightMm).abs() > .001 ||
          (checked.pointUMm - assignment.pointUMm).abs() > .001) {
        throw const FormatException(
            'Между выбором и сохранением изменились размеры. '
            'Выберите базу заново.');
      }
      point.datumAssignment = checked;
    } else {
      point.datumAssignment = null;
    }
  }
}
