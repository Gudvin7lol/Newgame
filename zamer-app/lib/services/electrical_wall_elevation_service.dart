import 'dart:math' as math;

import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_crossing_service.dart';
import 'electrical_route_service.dart';

/// Wall elevation coordinates: u is millimetres from the oriented wall's
/// *start node*; z is project height above the finished floor datum.
/// This is a projection onto the wall axis, NOT a model of wall thickness.
class ElectricalWallElevationPoint {
  const ElectricalWallElevationPoint({
    required this.pointId,
    required this.label,
    required this.uMm,
    required this.zMm,
    required this.offsetFromAxisMm,
  });
  final String pointId, label;
  final double uMm, zMm, offsetFromAxisMm;
}

class ElectricalWallElevationOpening {
  const ElectricalWallElevationOpening({
    required this.id,
    required this.kind,
    required this.fromUMm,
    required this.toUMm,
    required this.bottomMm,
    required this.topMm,
  });
  final String id, kind;
  final double fromUMm, toUMm, bottomMm, topMm;
}

class ElectricalWallElevationSegment {
  const ElectricalWallElevationSegment({
    required this.routeId,
    required this.cableId,
    required this.circuitId,
    required this.fromUMm,
    required this.toUMm,
    required this.fromZMm,
    required this.toZMm,
    required this.source,
  });
  final String routeId, cableId, circuitId;
  final double fromUMm, toUMm, fromZMm, toZMm;
  final ElectricalPathSource source;
}

class ElectricalWallElevationCrossingMark {
  const ElectricalWallElevationCrossingMark({
    required this.cableId,
    required this.uMm,
    required this.zMm,
    required this.needsReview,
  });
  final String cableId;
  final double uMm, zMm;
  final bool needsReview;
}

class ElectricalWallElevationData {
  const ElectricalWallElevationData({
    required this.wallId,
    required this.lengthMm,
    required this.heightMm,
    required this.points,
    required this.openings,
    required this.segments,
    required this.crossings,
    required this.crossingMarks,
    required this.warnings,
    required this.supported,
  });
  final String wallId;
  final double lengthMm, heightMm;
  final List<ElectricalWallElevationPoint> points;
  final List<ElectricalWallElevationOpening> openings;
  final List<ElectricalWallElevationSegment> segments;
  final List<ElectricalCrossingNotice> crossings;
  final List<ElectricalWallElevationCrossingMark> crossingMarks;
  final List<String> warnings;
  final bool supported;
}

/// Pure, no-write wall elevation projection. Neither proximity to a wall nor
/// crossing its axis creates any electrical network connection.
class ElectricalWallElevationService {
  const ElectricalWallElevationService._();

  static ElectricalWallElevationData build(
    FloorPlan floor,
    String wallId, {
    String? circuitId,
    int? wallSide,
  }) {
    if (wallSide != null && wallSide != 1 && wallSide != -1) {
      throw const FormatException('Неизвестная сторона стены.');
    }
    final wall = floor.wallById(wallId);
    if (wall == null) {
      throw const FormatException('Выбранная стена больше не существует.');
    }
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) {
      throw const FormatException('У стены отсутствует начальный или конечный узел.');
    }
    final dx = end.xMm - start.xMm;
    final dy = end.yMm - start.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    final h = wall.heightOverrideMm ?? floor.defaultHeightMm;
    if (!length.isFinite || length < 1 || !h.isFinite || h <= 0) {
      throw const FormatException('Некорректная длина или высота стены.');
    }
    final warnings = <String>[];
    final curved = wall.isCurved;
    if (curved) {
      warnings.add('Стена дуговая: прямолинейная развёртка не поддерживается.');
    }
    final ux = dx / length, uy = dy / length;
    ({double u, double offset}) projected(double x, double y) {
      final px = x - start.xMm, py = y - start.yMm;
      return (u: px * ux + py * uy, offset: px * (-uy) + py * ux);
    }
    final openings = <ElectricalWallElevationOpening>[];
    if (!curved) {
      for (final opening in wall.openings) {
        if (opening.widthMm <= 0 || opening.heightMm <= 0 ||
            opening.offsetFromStartMm < 0 ||
            opening.offsetFromStartMm + opening.widthMm > length + .5 ||
            opening.sillHeightMm < 0 ||
            opening.sillHeightMm + opening.heightMm > h + .5) {
          warnings.add('Проём ' + opening.id +
              ': размеры выходят за границы стены, требуется проверка.');
          continue;
        }
        openings.add(ElectricalWallElevationOpening(
          id: opening.id,
          kind: opening.type == OpeningType.door ? 'Дверь' : 'Окно',
          fromUMm: opening.offsetFromStartMm,
          toUMm: opening.offsetFromStartMm + opening.widthMm,
          bottomMm: opening.sillHeightMm,
          topMm: opening.sillHeightMm + opening.heightMm,
        ));
      }
    }

    final points = <ElectricalWallElevationPoint>[];
    if (!curved) {
      for (final p in floor.electricalPoints) {
        // Never put nearby sockets on a wall unless the master has explicitly
        // assigned a persistent wallId.
        if (p.wallId != wallId) continue;
        if (wallSide != null && p.wallSide != wallSide) continue;
        final position = projected(p.xMm, p.yMm);
        if (position.u < -.5 || position.u > length + .5 ||
            !p.heightMm.isFinite || p.heightMm < 0 || p.heightMm > h) {
          warnings.add('Электроточка ' + p.id +
              ': за пределами развёртки, требуется перепривязка.');
          continue;
        }
        // The mounting datum may refer to the wall face, not its axis.
        // Show the actual calculated offset, without assuming a face.
        points.add(ElectricalWallElevationPoint(
          pointId: p.id,
          label: p.label.trim().isEmpty ? p.type.label : p.label.trim(),
          uMm: position.u.clamp(0.0, length),
          zMm: p.heightMm,
          offsetFromAxisMm: position.offset,
        ));
      }
    }

    final segments = <ElectricalWallElevationSegment>[];
    if (!curved && floor.electricalNetwork != null) {
      final network = floor.electricalNetwork!;
      final seen = <String>{};
      for (final cable in network.cables) {
        if (circuitId != null && cable.circuitId != circuitId) continue;
        if (cable.route3dId == null) continue;
        try {
          ElectricalRouteService.measureCable(floor, cable);
        } on FormatException {
          continue; // Invalid routes are never painted as verified geometry.
        }
        final route = network.routes3d
            .where((r) => r.id == cable.route3dId).firstOrNull;
        if (route == null) continue;
        for (var i = 1; i < route.vertices.length; i++) {
          final a = route.vertices[i - 1], b = route.vertices[i];
          final pa = projected(a.xMm, a.yMm);
          final pb = projected(b.xMm, b.yMm);
          // Strict axis proximity avoids displaying wall CROSSINGS as
          // cable segments lying on the wall surface.
          if (pa.offset.abs() > 2 || pb.offset.abs() > 2) continue;
          if (math.min(pa.u, pb.u) < -.5 ||
              math.max(pa.u, pb.u) > length + .5) continue;
          if (a.zMm < 0 || a.zMm > h || b.zMm < 0 || b.zMm > h) {
            warnings.add('Кабель ' + cable.id +
                ': участок выходит за высоту стены.');
            continue;
          }
          final key = route.id + '/' + cable.circuitId + '/' + i.toString();
          if (!seen.add(key)) continue;
          segments.add(ElectricalWallElevationSegment(
            routeId: route.id, cableId: cable.id,
            circuitId: cable.circuitId,
            fromUMm: pa.u.clamp(0.0, length),
            toUMm: pb.u.clamp(0.0, length),
            fromZMm: a.zMm, toZMm: b.zMm,
            source: route.source,
          ));
        }
      }
    }
    final report = ElectricalCrossingService.inspect(floor,
        circuitId: circuitId);
    final crossing = curved
        ? <ElectricalCrossingNotice>[]
        : report.notices.where((n) =>
            n.wallId == wallId &&
            n.kind != ElectricalCrossingKind.unsupportedWall).toList();

    // Crossings are projected as REVIEW markers only, not on-wall cable
    // segments. Their U coordinate is derived from the oriented wall axis.
    final crossingMarks = <ElectricalWallElevationCrossingMark>[];
    for (final notice in crossing) {
      final projectedCrossing = projected(notice.xMm, notice.yMm);
      if (projectedCrossing.u < -.5 ||
          projectedCrossing.u > length + .5 ||
          notice.zMm < 0 || notice.zMm > h) continue;
      crossingMarks.add(ElectricalWallElevationCrossingMark(
        cableId: notice.cableId,
        uMm: projectedCrossing.u.clamp(0.0, length),
        zMm: notice.zMm,
        needsReview: notice.needsReview,
      ));
    }
    if (report.missingRoutes > 0 || report.invalidRoutes > 0) {
      warnings.add('Неполная схема: кабелей без 3D-трассы ' +
          report.missingRoutes.toString() +
          ', с повреждённой трассой ' + report.invalidRoutes.toString() + '.');
    }
    points.sort((a, b) => a.uMm.compareTo(b.uMm));
    segments.sort((a, b) => a.fromUMm.compareTo(b.fromUMm));
    return ElectricalWallElevationData(
      wallId: wallId, lengthMm: length, heightMm: h,
      points: points, openings: openings,
      segments: segments, crossings: crossing,
      crossingMarks: crossingMarks,
      warnings: warnings, supported: !curved,
    );
  }
}
