import 'dart:math' as math;
import '../models/models.dart';
import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import 'electrical_route_service.dart';

enum ElectricalCrossingKind {
  wallAxis,
  opening,
  alongWall,
  wallEndpoint,
  outsideWallHeight,
  unsupportedWall,
}

class ElectricalCrossingNotice {
  const ElectricalCrossingNotice({
    required this.cableId,
    required this.routeId,
    required this.wallId,
    required this.kind,
    required this.message,
    required this.xMm,
    required this.yMm,
    required this.zMm,
    this.openingId,
    this.routeSegment = -1,
  });
  final String cableId, routeId, wallId;
  final ElectricalCrossingKind kind;
  final String message;
  final String? openingId;
  final double xMm, yMm, zMm;
  final int routeSegment;
  bool get needsReview => kind != ElectricalCrossingKind.opening;
}

class ElectricalCrossingReport {
  const ElectricalCrossingReport({
    required this.notices,
    required this.missingRoutes,
    required this.invalidRoutes,
  });
  final List<ElectricalCrossingNotice> notices;
  final int missingRoutes, invalidRoutes;
  int get needsReview => notices.where((n) => n.needsReview).length;
  bool get complete => missingRoutes == 0 && invalidRoutes == 0;
}

/// Geometric test against *wall centre axes*, not wall solids, permitted
/// penetrations, code separation limits, or approved construction details.
/// A crossing is a review marker, never a verdict of electrical safety.
class ElectricalCrossingService {
  const ElectricalCrossingService._();

  static const _epsilon = 1e-8;
  static const _vertexTolMm = .5;

  static ElectricalCrossingReport inspect(FloorPlan floor,
      {String? circuitId}) {
    final network = floor.electricalNetwork;
    if (network == null) {
      return const ElectricalCrossingReport(
          notices: [], missingRoutes: 0, invalidRoutes: 0);
    }
    final notices = <ElectricalCrossingNotice>[];
    var missing = 0, invalid = 0;
    for (final cable in network.cables) {
      if (circuitId != null && cable.circuitId != circuitId) continue;
      if (cable.route3dId == null) {
        missing++;
        continue;
      }
      ElectricalRoute3d? route;
      try {
        ElectricalRouteService.measureCable(floor, cable);
        route = network.routes3d
            .where((r) => r.id == cable.route3dId).firstOrNull;
      } on FormatException {
        invalid++;
        continue;
      }
      if (route == null) {
        invalid++;
        continue;
      }
      notices.addAll(_inspectRoute(floor, cable, route));
    }
    // A shared physical path can have several cables. Each cable is
    // actionable in the journal, but each issue belongs to one exact cable.
    return ElectricalCrossingReport(
        notices: notices, missingRoutes: missing, invalidRoutes: invalid);
  }

  static List<ElectricalCrossingNotice> _inspectRoute(
      FloorPlan floor, ElectricalCableRecord cable, ElectricalRoute3d route) {
    final results = <ElectricalCrossingNotice>[];
    final seen = <String>{};
    void add(PlanWall w, ElectricalCrossingKind kind, String message,
        ElectricalRouteVertex at, int segment, [String? opening]) {
      final key = w.id + '/' + kind.name + '/' +
          at.xMm.toStringAsFixed(1) + '/' +
          at.yMm.toStringAsFixed(1) + '/' +
          at.zMm.toStringAsFixed(1);
      if (!seen.add(key)) return;
      results.add(ElectricalCrossingNotice(
        cableId: cable.id, routeId: route.id, wallId: w.id,
        kind: kind, message: message,
        xMm: at.xMm, yMm: at.yMm, zMm: at.zMm,
        openingId: opening, routeSegment: segment,
      ));
    }

    for (final wall in floor.walls) {
      if (wall.demolition || wall.projectLayer == ProjectLayer.demolition) {
        continue;
      }
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) {
        add(wall, ElectricalCrossingKind.unsupportedWall,
            'Ось стены не определена: проверить вручную.',
            route.vertices.first, -1);
        continue;
      }
      if (wall.isCurved) {
        add(wall, ElectricalCrossingKind.unsupportedWall,
            'Дуговая стена: анализ пересечений пока не поддерживается.',
            route.vertices.first, -1);
        continue;
      }
      final wx = b.xMm - a.xMm, wy = b.yMm - a.yMm;
      final wallLength = math.sqrt(wx * wx + wy * wy);
      if (wallLength <= 0 || !wallLength.isFinite) {
        add(wall, ElectricalCrossingKind.unsupportedWall,
            'Неопределённая длина стены.',
            route.vertices.first, -1);
        continue;
      }
      for (var segment = 0; segment < route.vertices.length - 1; segment++) {
        final p = route.vertices[segment], q = route.vertices[segment + 1];
        final dx = q.xMm - p.xMm, dy = q.yMm - p.yMm;
        final flat = math.sqrt(dx * dx + dy * dy);
        if (flat <= _vertexTolMm) {
          // A pure vertical leg has no 2D axis crossing, but the wall solid
          // and the route depth are not modelled. Do not invent a penetration.
          continue;
        }
        final rx = a.xMm - p.xMm, ry = a.yMm - p.yMm;
        final cross = dx * wy - dy * wx;
        final parallelTol = flat * wallLength * _epsilon;
        if (cross.abs() <= parallelTol) {
          // Check collinearity and longitudinal overlap in world millimetres.
          if ((rx * dy - ry * dx).abs() > parallelTol) continue;
          final u1 = ((p.xMm - a.xMm) * wx +
              (p.yMm - a.yMm) * wy) / (wallLength * wallLength);
          final u2 = ((q.xMm - a.xMm) * wx +
              (q.yMm - a.yMm) * wy) / (wallLength * wallLength);
          final overlap = (math.min(1.0, math.max(u1, u2)) -
              math.max(0.0, math.min(u1, u2))) * wallLength;
          if (overlap > 20) {
            // Mark the *actual overlap* instead of the centre of the whole
            // cable leg, which may be far outside this wall's finite axis.
            final lo = math.max(0.0, math.min(u1, u2));
            final hi = math.min(1.0, math.max(u1, u2));
            final midU = (lo + hi) / 2;
            final x = a.xMm + wx * midU;
            final y = a.yMm + wy * midU;
            final t = (((x - p.xMm) * dx + (y - p.yMm) * dy) /
                (flat * flat)).clamp(0.0, 1.0);
            add(wall, ElectricalCrossingKind.alongWall,
                'Трасса совпадает с осью стены. Глубина и способ прокладки '
                'не определены.', ElectricalRouteVertex(
                  xMm: x, yMm: y,
                  zMm: p.zMm + (q.zMm - p.zMm) * t,
                ), segment);
          }
          continue;
        }
        final t = (rx * wy - ry * wx) / cross;
        final u = (rx * dy - ry * dx) / cross;
        // Not an intersection of the actual finite planar segments.
        if (t < -_epsilon || t > 1 + _epsilon ||
            u < -_epsilon || u > 1 + _epsilon) continue;
        final at = ElectricalRouteVertex(
          xMm: p.xMm + dx * t,
          yMm: p.yMm + dy * t,
          zMm: p.zMm + (q.zMm - p.zMm) * t,
        );
        if (t <= _epsilon || t >= 1 - _epsilon ||
            u <= _epsilon || u >= 1 - _epsilon) {
          add(wall, ElectricalCrossingKind.wallEndpoint,
              'Трасса касается оси или конца стены. '
              'Требуется проверка положения и проходки.', at, segment);
          continue;
        }

        final height = wall.heightOverrideMm ?? floor.defaultHeightMm;
        if (at.zMm < 0 || at.zMm > height) {
          add(wall, ElectricalCrossingKind.outsideWallHeight,
              'Пересечение оси за пределами указанной высоты стены. '
              'Проверьте уровни и перекрытие.', at, segment);
          continue;
        }
        final alongMm = u * wallLength;
        WallOpening? opening;
        for (final o in wall.openings) {
          if (alongMm >= o.offsetFromStartMm &&
              alongMm <= o.offsetFromStartMm + o.widthMm &&
              at.zMm >= o.sillHeightMm &&
              at.zMm <= o.sillHeightMm + o.heightMm) {
            opening = o;
            break;
          }
        }
        if (opening != null) {
          add(wall, ElectricalCrossingKind.opening,
              'Трасса пересекает ось стены внутри указанного '
              'проёма. Способ прохода проверить отдельно.',
              at, segment, opening.id);
        } else {
          add(wall, ElectricalCrossingKind.wallAxis,
              'Трасса пересекает ось стены вне светового проёма. '
              'Уточните проходку и способ прокладки.',
              at, segment);
        }
      }
    }
    return results;
  }
}
