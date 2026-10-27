import 'dart:math' as math;

import '../models/electrical_wall_face.dart';
import '../models/models.dart';
import 'electrical_mounting_service.dart';
import 'electrical_wall_face_service.dart';

enum ElectricalDatumKind { finishedCorner, structuralOpeningStart, structuralOpeningEnd }

class ElectricalWallDatum {
  const ElectricalWallDatum({
    required this.id,
    required this.kind,
    required this.title,
    required this.uMm,
    required this.finishedReference,
    required this.description,
    this.neighbourWallId,
    this.openingId,
    this.source,
  });

  final String id, title, description;
  final ElectricalDatumKind kind;
  /// Signed coordinate along the selected oriented wall, in world mm.
  final double uMm;
  /// Whether all needed *finish inputs* exist. Not site verification.
  final bool finishedReference;
  final String? neighbourWallId, openingId;
  final WallFinishSource? source;
}

class ElectricalDatumDimension {
  const ElectricalDatumDimension({
    required this.pointId,
    required this.pointName,
    required this.uMm,
    required this.heightMm,
    required this.fromDatumMm,
    required this.mountingProblem,
  });

  final String pointId, pointName;
  final double uMm, heightMm, fromDatumMm;
  final String? mountingProblem;
}

class ElectricalWallDatumCatalog {
  const ElectricalWallDatumCatalog({
    required this.wallId,
    required this.side,
    required this.lengthMm,
    required this.datums,
    required this.issues,
  });
  final String wallId;
  final int side;
  final double lengthMm;
  final List<ElectricalWallDatum> datums;
  final List<String> issues;
}

/// Read-only 2D reference stations for dimensional marking.
///
/// A "finished corner" is an intersection of two *modelled* finished face
/// lines. This never asserts actual measured site geometry or that the
/// walls/finishes are buildable at their recorded dimensions.
///
/// Opening edges are explicit structural-axis references only. No edge is
/// claimed to be a finished reveal unless an actual reveal survey is stored.
class ElectricalWallDatumService {
  const ElectricalWallDatumService._();

  static double _cross(double ax, double ay, double bx, double by) =>
      ax * by - ay * bx;

  static ElectricalWallDatumCatalog catalog(
      FloorPlan floor, String wallId, int side) {
    final wall = floor.wallById(wallId);
    if (wall == null) throw const FormatException('Стена удалена.');
    final ownFinish = ElectricalWallFaceService.saved(wall, side);
    ElectricalWallFaceService.validate(floor, wall, side, ownFinish);
    final start = floor.nodeById(wall.startNodeId)!;
    final end = floor.nodeById(wall.endNodeId)!;
    final dx = end.xMm - start.xMm, dy = end.yMm - start.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    final datums = <ElectricalWallDatum>[];
    final issues = <String>[];

    if (ownFinish == null) {
      issues.add('Для выбранной стороны нет толщины отделки. '
          'Чистовые углы не вычисляются.');
    } else {
      final ownProblem = ElectricalWallFaceService.orientationProblem(wall, side);
      if (ownProblem != null) {
        issues.add(ownProblem);
      } else {
        final ownOffset = side * (wall.thicknessMm / 2 +
            ownFinish.thicknessMm);
        final ownX = start.xMm - dy / length * ownOffset;
        final ownY = start.yMm + dx / length * ownOffset;

        for (final adjacent in floor.walls) {
          if (adjacent.id == wall.id || adjacent.demolition ||
              adjacent.projectLayer == ProjectLayer.demolition ||
              adjacent.isCurved) continue;
          final junction = <String>{
            wall.startNodeId, wall.endNodeId,
          }.intersection({adjacent.startNodeId, adjacent.endNodeId});
          if (junction.length != 1) continue;
          final n = junction.single;
          final a = floor.nodeById(adjacent.startNodeId);
          final b = floor.nodeById(adjacent.endNodeId);
          if (a == null || b == null) {
            issues.add('Смежная стена ' + adjacent.id +
                ': неполная геометрия узлов.');
            continue;
          }
          final bx = b.xMm - a.xMm, by = b.yMm - a.yMm;
          final lengthB = math.sqrt(bx * bx + by * by);
          if (!lengthB.isFinite || lengthB < 1) continue;

          // Try both recorded *face sides*, never choose a room side
          // automatically. An interior corner often has just one valid pair.
          for (final adjacentSide in const [-1, 1]) {
            final neighbourFinish =
                ElectricalWallFaceService.saved(adjacent, adjacentSide);
            if (neighbourFinish == null) continue;
            if (ElectricalWallFaceService.orientationProblem(
                    adjacent, adjacentSide) != null) {
              issues.add('Смежная стена ' + adjacent.id +
                  ': чистовая сторона устарела после изменения направления.');
              continue;
            }
            try {
              ElectricalWallFaceService.validate(
                  floor, adjacent, adjacentSide, neighbourFinish);
            } on FormatException {
              continue;
            }

            // The corner of the two lines offset from the wall axes.
            final otherOffset = adjacentSide *
                (adjacent.thicknessMm / 2 + neighbourFinish.thicknessMm);
            final otherX = a.xMm - by / lengthB * otherOffset;
            final otherY = a.yMm + bx / lengthB * otherOffset;
            final denom = _cross(dx, dy, bx, by);
            if (denom.abs() < length * lengthB * 1e-8) {
              // Parallel axes cannot define a finite corner.
              continue;
            }
            final vx = otherX - ownX, vy = otherY - ownY;
            final t = _cross(vx, vy, bx, by) / denom;
            final u = _cross(vx, vy, dx, dy) / denom;
            final along = t * length, alongB = u * lengthB;

            // Do not invent intersections on arbitrary infinite extensions:
            // both calculated face-line coordinates must lie on their finite
            // wall extents and near the common plan corner.
            if (along < -.01 || along > length + .01 ||
                alongB < -.01 || alongB > lengthB + .01) continue;
            final jointU = n == wall.startNodeId ? 0.0 : length;
            final jointB = n == adjacent.startNodeId ? 0.0 : lengthB;
            if ((along - jointU).abs() > 500 ||
                (alongB - jointB).abs() > 500) continue;

            final id = 'corner:' + n + ':' + adjacent.id +
                ':' + adjacentSide.toString();
            datums.add(ElectricalWallDatum(
              id: id,
              kind: ElectricalDatumKind.finishedCorner,
              title: 'Расчётный чистовой угол · ' + adjacent.id,
              uMm: along.clamp(0.0, length),
              neighbourWallId: adjacent.id,
              finishedReference: true,
              source: ownFinish.source == WallFinishSource.measured &&
                      neighbourFinish.source == WallFinishSource.measured
                  ? WallFinishSource.measured
                  : WallFinishSource.unknown,
              description: 'Пересечение расчётных чистовых плоскостей '
                  'стен ' + wall.id + ' и ' + adjacent.id +
                  '. Не подтверждает фактический угол на объекте.',
            ));
          }
        }
        if (!datums.any((d) => d.kind ==
            ElectricalDatumKind.finishedCorner)) {
          issues.add('Нет пригодных пересечений известных чистовых плоскостей. '
              'Проверьте смежные стены, толщины и выбранную сторону.');
        }
      }
    }

    for (final opening in wall.openings) {
      final from = opening.offsetFromStartMm;
      final to = from + opening.widthMm;
      if (!from.isFinite || !to.isFinite || !opening.heightMm.isFinite ||
          !opening.sillHeightMm.isFinite || opening.widthMm <= 0 ||
          opening.heightMm <= 0 || opening.sillHeightMm < 0 ||
          from < 0 || to > length + .001) {
        issues.add('Проём ' + opening.id +
            ': размеры некорректны, база не создана.');
        continue;
      }
      datums.add(ElectricalWallDatum(
        id: 'opening:' + opening.id + ':start',
        kind: ElectricalDatumKind.structuralOpeningStart,
        title: 'Проём ' + opening.id + ' · начало по оси',
        uMm: from,
        openingId: opening.id,
        finishedReference: false,
        description: 'Положение черновой грани в модели стены. '
            'Чистовой откос, коробка и наличник не учтены.',
      ));
      datums.add(ElectricalWallDatum(
        id: 'opening:' + opening.id + ':end',
        kind: ElectricalDatumKind.structuralOpeningEnd,
        title: 'Проём ' + opening.id + ' · конец по оси',
        uMm: to,
        openingId: opening.id,
        finishedReference: false,
        description: 'Положение черновой грани в модели стены. '
            'Чистовой откос, коробка и наличник не учтены.',
      ));
    }

    datums.sort((a, b) {
      final c = a.uMm.compareTo(b.uMm);
      return c == 0 ? a.id.compareTo(b.id) : c;
    });
    return ElectricalWallDatumCatalog(
      wallId: wallId, side: side,
      lengthMm: length, datums: datums,
      issues: issues,
    );
  }

  static List<ElectricalDatumDimension> dimensions(
      FloorPlan floor, ElectricalWallDatumCatalog catalog,
      ElectricalWallDatum datum) {
    if (!catalog.datums.any((item) => item.id == datum.id)) {
      throw const FormatException('Выбранная база устарела.');
    }
    // Recompute the catalog rather than trust a UI cache after a wall edit.
    final live = ElectricalWallDatumService.catalog(
        floor, catalog.wallId, catalog.side);
    final current = live.datums.where((d) => d.id == datum.id).firstOrNull;
    if (current == null || (current.uMm - datum.uMm).abs() > .001) {
      throw const FormatException(
          'Геометрия монтажной базы изменилась. Обновите развёртку.');
    }
    final result = <ElectricalDatumDimension>[];
    for (final point in floor.electricalPoints) {
      if (point.wallId != catalog.wallId ||
          point.wallSide != catalog.side) continue;
      if (!point.xMm.isFinite || !point.yMm.isFinite ||
          !point.heightMm.isFinite) continue;
      final pos = ElectricalWallFaceService.project(
        floor, catalog.wallId, catalog.side,
        xMm: point.xMm, yMm: point.yMm,
      );
      if (pos.uMm < -.5 || pos.uMm > catalog.lengthMm + .5) continue;
      result.add(ElectricalDatumDimension(
        pointId: point.id,
        pointName: point.label.trim().isNotEmpty
            ? point.label : point.type.label,
        uMm: pos.uMm,
        heightMm: point.heightMm,
        fromDatumMm: pos.uMm - datum.uMm,
        mountingProblem: ElectricalMountingService.problem(floor, point),
      ));
    }
    result.sort((a, b) => a.uMm.compareTo(b.uMm));
    return result;
  }
}
