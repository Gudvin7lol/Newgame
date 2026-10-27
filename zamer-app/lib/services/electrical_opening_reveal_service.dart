import 'dart:convert';
import 'dart:math' as math;

import '../models/electrical_finished_reveal.dart';
import '../models/models.dart';
import 'electrical_wall_face_service.dart';

/// Per-face finished opening edge measurements in explicit project millimetres.
/// Never infer these from rough WallOpening or from door swing.
class ElectricalOpeningRevealService {
  const ElectricalOpeningRevealService._();

  static ElectricalFinishedReveal? saved(
      WallOpening opening, int side) => switch (side) {
    1 => opening.electricalRevealLeft,
    -1 => opening.electricalRevealRight,
    _ => throw const FormatException('Неизвестная сторона проёма.'),
  };

  static WallOpening _opening(FloorPlan floor, String wallId, String openingId) {
    final wall = floor.wallById(wallId);
    if (wall == null || wall.demolition ||
        wall.projectLayer == ProjectLayer.demolition) {
      throw const FormatException('Активная стена не найдена.');
    }
    final matching = wall.openings.where((o) => o.id == openingId).toList();
    if (matching.length != 1) {
      throw const FormatException('Проём отсутствует или ID не уникален.');
    }
    return matching.single;
  }

  static String snapshot(
      FloorPlan floor, PlanWall wall, WallOpening opening, int side) {
    // Geometry in the snapshot must not contain reveal metadata itself.
    // That would make a saved reveal instantly stale on its own update.
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    final finish = ElectricalWallFaceService.saved(wall, side);
    return jsonEncode({
      'wallId': wall.id,
      'a': a?.toJson(),
      'b': b?.toJson(),
      'wallThicknessMm': wall.thicknessMm,
      'wallHeightMm': wall.heightOverrideMm ?? floor.defaultHeightMm,
      'wallCurve': wall.isCurved,
      'opening': {
        'id': opening.id,
        'type': opening.type.name,
        'offsetFromStartMm': opening.offsetFromStartMm,
        'widthMm': opening.widthMm,
        'heightMm': opening.heightMm,
        'sillHeightMm': opening.sillHeightMm,
        'doorSwing': opening.doorSwing.name,
      },
      'side': side,
      'faceFinish': finish?.toJson(),
    });
  }

  static void validate(
      FloorPlan floor, String wallId, String openingId,
      int side, ElectricalFinishedReveal? proposal) {
    final wall = floor.wallById(wallId);
    if (wall == null) throw const FormatException('Стена отсутствует.');
    final opening = _opening(floor, wallId, openingId);
    final finish = ElectricalWallFaceService.saved(wall, side);
    ElectricalWallFaceService.validate(floor, wall, side, finish);
    if (finish == null) {
      throw const FormatException(
        'Перед чистовыми гранями задайте отделку выбранной стороны стены.',
      );
    }
    final sideError = ElectricalWallFaceService.orientationProblem(wall, side);
    if (sideError != null) throw FormatException(sideError);
    final a = floor.nodeById(wall.startNodeId)!;
    final b = floor.nodeById(wall.endNodeId)!;
    final length = math.sqrt(
      math.pow(b.xMm - a.xMm, 2) + math.pow(b.yMm - a.yMm, 2));
    final height = wall.heightOverrideMm ?? floor.defaultHeightMm;
    if (!height.isFinite || height <= 0 ||
        !opening.offsetFromStartMm.isFinite ||
        !opening.widthMm.isFinite || opening.widthMm <= 0 ||
        !opening.heightMm.isFinite || opening.heightMm <= 0 ||
        !opening.sillHeightMm.isFinite || opening.sillHeightMm < 0 ||
        opening.offsetFromStartMm < 0 ||
        opening.offsetFromStartMm + opening.widthMm > length + .001 ||
        opening.sillHeightMm + opening.heightMm > height + .001) {
      throw const FormatException(
        'Черновая геометрия проёма вне стены. Сначала исправьте проём.',
      );
    }
    if (proposal == null) return; // Clear entry, not structural geometry.
    if (!proposal.startUMm.isFinite || !proposal.endUMm.isFinite ||
        proposal.startUMm < 0 ||
        proposal.endUMm > length ||
        proposal.endUMm - proposal.startUMm < 1 ||
        proposal.uncertaintyMm != null &&
          (!proposal.uncertaintyMm!.isFinite ||
           proposal.uncertaintyMm! < 0 ||
           proposal.uncertaintyMm! > 500)) {
      throw const FormatException(
        'Грани должны находиться на стене, слева направо, '
        'с положительной шириной. Погрешность: 0–500 мм.',
      );
    }
  }

  /// Null means the saved reference matches CURRENT project geometry.
  /// It does NOT mean the entered survey has been independently verified.
  static String? problem(
      FloorPlan floor, String wallId, String openingId, int side) {
    try {
      final wall = floor.wallById(wallId);
      if (wall == null) return 'Стена отсутствует.';
      final opening = _opening(floor, wallId, openingId);
      final entry = saved(opening, side);
      if (entry == null) return 'Чистовые грани не введены.';
      validate(floor, wallId, openingId, side, entry);
      if (entry.geometrySnapshot !=
          snapshot(floor, wall, opening, side)) {
        return 'Геометрия стены, отделки или проёма изменилась. '
            'Проверьте и введите размер повторно.';
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  /// Caller validates and owns undo/persistence. No socket/route movement.
  static void apply(
      FloorPlan floor, String wallId, String openingId,
      int side, ElectricalFinishedReveal? proposal) {
    validate(floor, wallId, openingId, side, proposal);
    final wall = floor.wallById(wallId)!;
    final opening = _opening(floor, wallId, openingId);
    final entry = proposal == null ? null : ElectricalFinishedReveal(
      startUMm: proposal.startUMm,
      endUMm: proposal.endUMm,
      geometrySnapshot: snapshot(floor, wall, opening, side),
      source: proposal.source,
      uncertaintyMm: proposal.uncertaintyMm,
      note: proposal.note,
    );
    if (side == 1) {
      opening.electricalRevealLeft = entry;
    } else {
      opening.electricalRevealRight = entry;
    }
  }
}
