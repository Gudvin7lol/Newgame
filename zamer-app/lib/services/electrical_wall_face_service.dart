import 'dart:math' as math;

import '../models/electrical_wall_face.dart';
import '../models/models.dart';

/// All distances are world millimetres, never screen coordinates.
/// This is a *computed plane*, not survey verification or legal approval.
class ElectricalWallFaceProjection {
  const ElectricalWallFaceProjection({
    required this.wallId,
    required this.side,
    required this.wallCoreHalfMm,
    required this.finish,
    required this.uMm,
    required this.offsetFromAxisMm,
    required this.signedDistanceToFaceMm,
  });

  final String wallId;
  final int side;
  final double wallCoreHalfMm;
  final WallFaceFinish? finish;
  final double uMm, offsetFromAxisMm;
  /// Positive is toward the wall's left normal, irrespective of which side
  /// the face is on; zero means centre lies on the modelled finished plane.
  /// Null means finish thickness not specified, NOT zero thickness.
  final double? signedDistanceToFaceMm;
  bool get faceKnown => finish != null;
  bool get surveyedFinish => finish?.source == WallFinishSource.measured;
  double? get signedFaceOffsetMm => finish == null
      ? null : side * (wallCoreHalfMm + finish!.thicknessMm);
}

class ElectricalWallFaceService {
  const ElectricalWallFaceService._();

  static String sideLabel(int side) => switch (side) {
    1 => 'Слева от оси (начало → конец)',
    -1 => 'Справа от оси (начало → конец)',
    _ => 'Сторона не определена',
  };

  static WallFaceFinish? saved(PlanWall wall, int side) => switch (side) {
    1 => wall.electricalFaceLeft,
    -1 => wall.electricalFaceRight,
    _ => throw const FormatException('Укажите сторону стены.'),
  };

  static void validate(FloorPlan floor, PlanWall wall, int side,
      WallFaceFinish? finish) {
    if (side != 1 && side != -1) {
      throw const FormatException('Сторона должна быть левой или правой.');
    }
    if (floor.wallById(wall.id) != wall) {
      throw const FormatException('Стена удалена или заменена.');
    }
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (wall.isCurved || a == null || b == null) {
      throw const FormatException(
          'Для этой стены пока нет поддерживаемой прямой оси.');
    }
    if (!wall.thicknessMm.isFinite ||
        wall.thicknessMm <= 0 || wall.thicknessMm > 2000) {
      throw const FormatException(
          'Некорректная толщина конструктивной части стены.');
    }
    if (finish != null &&
        (!finish.thicknessMm.isFinite ||
         finish.thicknessMm < 0 || finish.thicknessMm > 500)) {
      throw const FormatException(
          'Толщина отделки должна быть от 0 до 500 мм.');
    }
    final length = math.sqrt(
        math.pow(a.xMm - b.xMm, 2) +
        math.pow(a.yMm - b.yMm, 2));
    if (!length.isFinite || length < 1) {
      throw const FormatException('Невозможно определить ось стены.');
    }
  }

  static String? orientationProblem(PlanWall wall, int side) {
    final finish = saved(wall, side);
    if (finish == null) return null;
    if (finish.axisStartNodeId != wall.startNodeId ||
        finish.axisEndNodeId != wall.endNodeId) {
      return 'Направление стены изменилось или не зафиксировано. '
          'Подтвердите сторону и толщину отделки заново.';
    }
    return null;
  }

  /// Apply ONLY after explicit user save. Existing device XYZ remain unchanged.
  /// Caller owns the single undo boundary and persistence.
  static void apply(FloorPlan floor, String wallId, int side,
      WallFaceFinish? finish) {
    final wall = floor.wallById(wallId);
    if (wall == null) {
      throw const FormatException('Стена больше не существует.');
    }
    validate(floor, wall, side, finish);
    final stamped = finish == null ? null : WallFaceFinish(
      thicknessMm: finish.thicknessMm,
      source: finish.source,
      note: finish.note,
      axisStartNodeId: wall.startNodeId,
      axisEndNodeId: wall.endNodeId,
    );
    if (side == 1) {
      wall.electricalFaceLeft = stamped;
    } else {
      wall.electricalFaceRight = stamped;
    }
  }

  static ElectricalWallFaceProjection project(
      FloorPlan floor, String wallId, int side,
      {required double xMm, required double yMm}) {
    final wall = floor.wallById(wallId);
    if (wall == null) throw const FormatException('Стена удалена.');
    final finish = saved(wall, side);
    validate(floor, wall, side, finish);
    final stale = orientationProblem(wall, side);
    if (stale != null) throw FormatException(stale);
    if (!xMm.isFinite || !yMm.isFinite) {
      throw const FormatException('Положение точки недостоверно.');
    }
    final a = floor.nodeById(wall.startNodeId)!;
    final b = floor.nodeById(wall.endNodeId)!;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    final along = ((xMm - a.xMm) * dx +
        (yMm - a.yMm) * dy) / length;
    final normal = ((xMm - a.xMm) * -dy +
        (yMm - a.yMm) * dx) / length;
    final face = finish == null
        ? null : side * (wall.thicknessMm / 2 + finish.thicknessMm);
    return ElectricalWallFaceProjection(
      wallId: wallId, side: side,
      wallCoreHalfMm: wall.thicknessMm / 2,
      finish: finish,
      uMm: along, offsetFromAxisMm: normal,
      signedDistanceToFaceMm: face == null ? null : normal - face,
    );
  }
}
