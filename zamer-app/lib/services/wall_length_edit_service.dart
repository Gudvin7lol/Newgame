import 'dart:math' as math;

import '../models/models.dart';
import 'orthogonal_wall_edit_service.dart';

/// Resizes an already drawn axis-aligned wall while preserving its adjacent
/// rectangle by translating the perpendicular boundary wall. A single
/// transaction keeps doors, openings, and wall-mounted electrical points
/// consistent through OrthogonalWallEditService.
class WallLengthEditResult {
  const WallLengthEditResult._(this.isValid, this.message);

  final bool isValid;
  final String message;

  static const success = WallLengthEditResult._(true, '');
  static WallLengthEditResult invalid(String message) =>
      WallLengthEditResult._(false, message);
}

class WallLengthEditService {
  static const minLengthMm = 120.0;
  static const maxLengthMm = 100000.0;
  static const toleranceMm = 0.5;

  /// If [keepStartFixed] is true, the moving endpoint is the wall's end,
  /// otherwise it is the start. Complex T/cross junction endpoints are
  /// deliberately unsupported until constraint propagation is available.
  static WallLengthEditResult preview(
    FloorPlan floor, {
    required String wallId,
    required double lengthMm,
    bool keepStartFixed = true,
  }) => _operation(
    floor, wallId: wallId, lengthMm: lengthMm,
    keepStartFixed: keepStartFixed, apply: false,
  );

  static WallLengthEditResult resize(
    FloorPlan floor, {
    required String wallId,
    required double lengthMm,
    bool keepStartFixed = true,
  }) => _operation(
    floor, wallId: wallId, lengthMm: lengthMm,
    keepStartFixed: keepStartFixed, apply: true,
  );

  static WallLengthEditResult _operation(
    FloorPlan floor, {
    required String wallId,
    required double lengthMm,
    required bool keepStartFixed,
    required bool apply,
  }) {
    WallLengthEditResult reject(String reason) =>
        WallLengthEditResult.invalid(reason);

    if (!lengthMm.isFinite ||
        lengthMm < minLengthMm ||
        lengthMm > maxLengthMm) {
      return reject('Укажите длину от 120 мм до 100 м.');
    }

    final wall = floor.wallById(wallId);
    if (wall == null) return reject('Стена не найдена.');
    if (wall.isCurved) {
      return reject('Изменение длины дуги пока не поддерживается.');
    }
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) {
      return reject('У стены отсутствует начальный или конечный узел.');
    }
    final length = floor.wallLengthMm(wall);
    if (!length.isFinite || length < minLengthMm) {
      return reject('Стена имеет недопустимую исходную длину.');
    }
    final isHorizontal = (start.yMm - end.yMm).abs() < toleranceMm;
    final isVertical = (start.xMm - end.xMm).abs() < toleranceMm;
    if (isHorizontal == isVertical) {
      return reject('Точный ввод пока доступен только для прямых стен под 90°.');
    }

    final difference = lengthMm - length;
    if (difference.abs() < .001) return WallLengthEditResult.success;

    final movingNode = keepStartFixed ? end : start;
    final attached = floor.walls.where((candidate) =>
        candidate.startNodeId == movingNode.id ||
        candidate.endNodeId == movingNode.id).toList();

    if (attached.length != 2) {
      return reject('У выбранного конца сложный стык. '
          'Выберите другой конец или измените узел вручную.');
    }

    final neighbours = attached.where((candidate) => candidate.id != wallId);
    if (neighbours.length != 1) {
      return reject('Не удалось однозначно определить соседнюю стену.');
    }
    final neighbour = neighbours.single;
    if (neighbour.isCurved) {
      return reject('К выбранному концу примыкает дуговая стена.');
    }
    final next = floor.nodeById(
      neighbour.startNodeId == movingNode.id
          ? neighbour.endNodeId : neighbour.startNodeId,
    );
    if (next == null) {
      return reject('В соседней стене отсутствует крайний узел.');
    }

    // To extend the selected wall without changing its bearing, its endpoint
    // moves along its axis. Translating the perpendicular neighbouring wall
    // moves BOTH its endpoints, keeping the rectangle and its other wall
    // orthogonal rather than introducing a diagonal.
    if (isHorizontal &&
        (next.xMm - movingNode.xMm).abs() >= toleranceMm) {
      return reject('Нужна перпендикулярная соседняя стена.');
    }
    if (isVertical &&
        (next.yMm - movingNode.yMm).abs() >= toleranceMm) {
      return reject('Нужна перпендикулярная соседняя стена.');
    }

    final alongX = (end.xMm - start.xMm) / length;
    final alongY = (end.yMm - start.yMm) / length;
    final direction = keepStartFixed ? 1.0 : -1.0;
    final dx = alongX * difference * direction;
    final dy = alongY * difference * direction;
    final shiftMm = isHorizontal ? dx : dy;

    if (!shiftMm.isFinite) return reject('Неверное смещение стены.');

    final check = OrthogonalWallEditService.preview(
      floor,
      wallId: neighbour.id,
      offsetMm: shiftMm,
    );
    if (!check.isValid) return reject(check.message);
    if (!apply) return WallLengthEditResult.success;

    final moved = OrthogonalWallEditService.move(
      floor, wallId: neighbour.id, offsetMm: shiftMm,
    );
    if (!moved.isValid) return reject(moved.message);
    // No new nodes/edges are introduced. Everything was validated before
    // mutation; floating precision is limited by existing CAD coordinates.
    assert((floor.wallLengthMm(wall) - lengthMm).abs() < .01);
    return WallLengthEditResult.success;
  }

  static double? angleDegrees(FloorPlan floor, PlanWall wall) {
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) return null;
    return math.atan2(end.yMm - start.yMm, end.xMm - start.xMm) *
        180 / math.pi;
  }
}
