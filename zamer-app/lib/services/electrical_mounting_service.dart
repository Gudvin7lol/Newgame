import 'dart:convert';
import 'dart:math' as math;

import '../models/models.dart';
import '../models/electrical_mounting.dart';

class MountingPosition {
  const MountingPosition(
    this.xMm,
    this.yMm,
    this.offsetMm,
    this.datumXMm,
    this.datumYMm,
  );
  final double xMm, yMm, offsetMm, datumXMm, datumYMm;
}

/// Coordinates remain in world millimetres; no camera or pixel conversion here.
/// This first slice dimensions the centre projection onto a straight wall axis.
class ElectricalMountingService {
  static String snapshot(FloorPlan floor, PlanWall wall) => jsonEncode({
    'wall': wall.toJson(),
    'start': floor.nodeById(wall.startNodeId)?.toJson(),
    'end': floor.nodeById(wall.endNodeId)?.toJson(),
    'height': floor.defaultHeightMm,
  });

  static MountingPosition resolve(FloorPlan floor, ElectricalMounting m) {
    final wall = floor.wallById(m.wallId);
    if (wall == null) {
      throw const FormatException('Стена удалена. Нужна новая привязка.');
    }
    if (wall.isCurved) {
      throw const FormatException(
        'Для дуговой стены точная привязка ещё не поддерживается.',
      );
    }
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null ||
        b == null ||
        ![a.xMm, a.yMm, b.xMm, b.yMm].every((v) => v.isFinite)) {
      throw const FormatException('Не определены координаты концов стены.');
    }
    final length = floor.wallLengthMm(wall);
    if (!length.isFinite || length <= 0) {
      throw const FormatException('Стена имеет нулевую длину.');
    }
    if (m.datumNodeId != a.id && m.datumNodeId != b.id) {
      throw const FormatException('База больше не принадлежит стене.');
    }
    if (m.wallSide != -1 && m.wallSide != 1) {
      throw const FormatException('Не указана сторона стены.');
    }
    if (m.datumName.trim().isEmpty) {
      throw const FormatException('Подпишите монтажную базу.');
    }
    final numbers = [
      m.datumInsetMm,
      m.distanceMm,
      m.heightAboveFinishedFloorMm,
      if (m.finishedFloorAboveSlabMm != null) m.finishedFloorAboveSlabMm!,
      if (m.measurementUncertaintyMm != null) m.measurementUncertaintyMm!,
    ];
    if (numbers.any((v) => !v.isFinite || v < 0)) {
      throw const FormatException(
        'Размеры должны быть конечными неотрицательными числами.',
      );
    }
    final along = m.datumInsetMm + m.distanceMm;
    if (along > length) {
      throw const FormatException(
        'Центр выходит за конец стены. Размер не сохранён.',
      );
    }
    final h = wall.heightOverrideMm ?? floor.defaultHeightMm;
    if (!h.isFinite || h <= 0 || m.heightAboveFinishedFloorMm > h) {
      throw const FormatException(
        'Центр выше стены. Проверьте высоту и её базу.',
      );
    }
    final fromStart = m.datumNodeId == a.id;
    final offset = fromStart ? along : length - along;
    for (final opening in wall.openings) {
      if (offset >= opening.offsetFromStartMm &&
          offset <= opening.offsetFromStartMm + opening.widthMm &&
          m.heightAboveFinishedFloorMm >= opening.sillHeightMm &&
          m.heightAboveFinishedFloorMm <=
              opening.sillHeightMm + opening.heightMm) {
        throw const FormatException(
          'Центр попадает в проём. Выберите другое положение.',
        );
      }
    }
    final datumOffset = fromStart ? m.datumInsetMm : length - m.datumInsetMm;
    final dx = (b.xMm - a.xMm) / length, dy = (b.yMm - a.yMm) / length;
    return MountingPosition(
      a.xMm + dx * offset,
      a.yMm + dy * offset,
      offset,
      a.xMm + dx * datumOffset,
      a.yMm + dy * datumOffset,
    );
  }

  /// Validate first; failed commands leave the entire point unchanged.
  static void apply(
    FloorPlan floor,
    ElectricalPoint point,
    ElectricalMounting m,
  ) {
    final pos = resolve(floor, m);
    final wall = floor.wallById(m.wallId)!;
    if (m.geometrySnapshot != snapshot(floor, wall)) {
      throw const FormatException(
        'Геометрия изменилась. Откройте привязку заново.',
      );
    }
    point.wallId = m.wallId;
    point.wallSide = m.wallSide;
    point.wallOffsetMm = pos.offsetMm;
    point.xMm = pos.xMm;
    point.yMm = pos.yMm;
    point.heightMm = m.heightAboveFinishedFloorMm;
    point.mounting = m;
  }

  /// Null means current geometric data, never electrical/safety approval.
  static String? problem(FloorPlan floor, ElectricalPoint point) {
    final m = point.mounting;
    if (m == null) return 'Монтажная база не задана';
    try {
      final pos = resolve(floor, m);
      final wall = floor.wallById(m.wallId)!;
      if (m.geometrySnapshot != snapshot(floor, wall) ||
          point.wallId != m.wallId ||
          point.wallSide != m.wallSide ||
          point.wallOffsetMm == null ||
          !point.wallOffsetMm!.isFinite ||
          !point.xMm.isFinite ||
          !point.yMm.isFinite ||
          !point.heightMm.isFinite ||
          (point.wallOffsetMm! - pos.offsetMm).abs() > .001 ||
          math.sqrt(
                math.pow(point.xMm - pos.xMm, 2) +
                    math.pow(point.yMm - pos.yMm, 2),
              ) >
              .001 ||
          (point.heightMm - m.heightAboveFinishedFloorMm).abs() > .001) {
        return 'Привязка изменилась — проверьте размеры';
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
