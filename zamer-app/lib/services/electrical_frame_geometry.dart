import '../models/models.dart';

/// Nominal geometric layout of centres for a wall-mounted multi-gang frame.
///
/// The default pitch of 71 mm is a *planning assumption*. Exact mounting
/// dimensions, faceplate outline and mixed-device compatibility depend on
/// the selected manufacturer's system and must be checked before installation.
class ElectricalFrameCentre {
  const ElectricalFrameCentre({required this.uMm, required this.zMm});
  final double uMm;
  final double zMm;
}

class ElectricalFrameGeometry {
  const ElectricalFrameGeometry._();

  static const double defaultPitchMm = 71;
  // Nominal 80 mm face envelope, not a measured manufacturer's dimension.
  static const double nominalFaceHalfMm = 40;

  static bool isMultiPost(ElectricalPoint point) =>
      point.type == ElectricalPointType.frame || point.modules.length > 1;

  static List<ElectricalFrameCentre> centres(ElectricalPoint point) {
    final count = point.modules.length;
    if (count < 1 || count > 5 ||
        !point.modulePitchMm.isFinite ||
        point.modulePitchMm < 40 || point.modulePitchMm > 150) {
      throw const FormatException('Рамка: проверь 1–5 мест и межосевое расстояние.');
    }
    final u = point.wallOffsetMm;
    if (u == null || !u.isFinite || !point.heightMm.isFinite) {
      throw const FormatException('Рамка не привязана к стене и высоте.');
    }
    return [
      for (var i = 0; i < count; i++)
        ElectricalFrameCentre(
          uMm: u + (point.frameVertical ? 0 :
              (i - (count - 1) / 2) * point.modulePitchMm),
          zMm: point.heightMm + (point.frameVertical ?
              (i - (count - 1) / 2) * point.modulePitchMm : 0),
        ),
    ];
  }

  static double getSpanMm(ElectricalPoint point) =>
      nominalFaceHalfMm * 2 +
      (point.modules.length - 1) * point.modulePitchMm;

  static double halfWidthMm(ElectricalPoint point) =>
      isMultiPost(point) && !point.frameVertical
          ? getSpanMm(point) / 2 : nominalFaceHalfMm;

  static double halfHeightMm(ElectricalPoint point) =>
      isMultiPost(point) && point.frameVertical
          ? getSpanMm(point) / 2 : nominalFaceHalfMm;

  /// Null means the nominal envelope fits known wall geometry.
  /// This does not verify actual box diameters, finishing layers or devices.
  static String? placementIssue(FloorPlan floor, ElectricalPoint point) {
    if (!isMultiPost(point)) return null;
    final wallId = point.wallId;
    if (wallId == null || point.wallOffsetMm == null) {
      return 'Для рамки нужно выбрать стену и центр.';
    }
    final wall = floor.wallById(wallId);
    if (wall == null || wall.isCurved || wall.demolition) {
      return 'Рамка требует существующую прямую стену.';
    }
    try {
      centres(point);
    } on FormatException catch (e) {
      return e.message;
    }
    final u = point.wallOffsetMm!;
    final z = point.heightMm;
    final x0 = u - halfWidthMm(point);
    final x1 = u + halfWidthMm(point);
    final y0 = z - halfHeightMm(point);
    final y1 = z + halfHeightMm(point);
    final wallLength = floor.wallLengthMm(wall);
    final wallHeight = wall.heightOverrideMm ?? floor.defaultHeightMm;
    if (!wallLength.isFinite || !wallHeight.isFinite ||
        wallLength <= 0 || wallHeight <= 0) {
      return 'Нет достоверных размеров стены для рамки.';
    }
    if (x0 < 0 || x1 > wallLength || y0 < 0 || y1 > wallHeight) {
      return 'Край рамки выходит за пределы стены или высоты помещения.';
    }
    for (final opening in wall.openings) {
      final lo = opening.offsetFromStartMm;
      final hi = lo + opening.widthMm;
      final bottom = opening.sillHeightMm;
      final top = bottom + opening.heightMm;
      if (x0 < hi && x1 > lo && y0 < top && y1 > bottom) {
        return 'Рамка пересекает проём ${opening.id}.';
      }
    }
    for (final other in floor.electricalPoints) {
      if (other.id == point.id || other.wallId != wallId ||
          other.wallSide != point.wallSide ||
          other.wallOffsetMm == null ||
          !other.wallOffsetMm!.isFinite || !other.heightMm.isFinite) {
        continue;
      }
      final ox0 = other.wallOffsetMm! - halfWidthMm(other);
      final ox1 = other.wallOffsetMm! + halfWidthMm(other);
      final oy0 = other.heightMm - halfHeightMm(other);
      final oy1 = other.heightMm + halfHeightMm(other);
      if (x0 < ox1 && x1 > ox0 && y0 < oy1 && y1 > oy0) {
        return 'Рамка пересекает электроточку ${other.id} на той же стороне стены.';
      }
    }
    return null;
  }
}
