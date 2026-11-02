import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_route_service.dart';
import 'electrical_wall_corridor_graph_service.dart';
import 'electrical_route_exclusion_service.dart';

/// Restricted, transparent routing proposal for two devices on the SAME
/// straight axis-aligned wall. It NEVER writes a cable or route into a FloorPlan.
/// No proposal is offered through unknown walls, service shafts or rooms.
/// True project-wide routing requires certified obstacle and installation data.
class ElectricalAutoRouteProposal {
  const ElectricalAutoRouteProposal({
    required this.route,
    required this.measurement,
    required this.warnings,
  });
  final ElectricalRoute3d route;
  final ElectricalRouteMeasurement measurement;
  final List<String> warnings;
}

class ElectricalAutoRouteProposalService {
  const ElectricalAutoRouteProposalService._();

  static ElectricalAutoRouteProposal prepare(
    FloorPlan floor,
    ElectricalCableRecord cable, {
    ElectricalRoute3d? existing,
    double ceilingDropMm = 150,
  }) {
    if (existing != null || cable.route3dId != null) {
      throw const FormatException(
        'Для кабеля уже есть трасса. Автоподбор её не заменяет. '
        'Редактируйте или удалите её вручную.');
    }
    if (!ceilingDropMm.isFinite || ceilingDropMm < 0 ||
        ceilingDropMm > 1000) {
      throw const FormatException('Неверный отступ от потолка.');
    }
    final a = floor.electricalPoints
        .where((p) => p.id == cable.fromPointId).firstOrNull;
    final b = floor.electricalPoints
        .where((p) => p.id == cable.toPointId).firstOrNull;
    if (a == null || b == null || a.id == b.id ||
        a.wallId == null || b.wallId == null ||
        a.wallOffsetMm == null || b.wallOffsetMm == null) {
      throw const FormatException(
        'Для предложения нужны две настенные точки с известной привязкой.');
    }
    if (a.wallId != b.wallId) {
      final ceilingZ = floor.defaultHeightMm - ceilingDropMm;
      final corridor = ElectricalWallCorridorGraphService.find(
        floor, a, b, zMm: ceilingZ,
        minimumCeilingDropMm: ceilingDropMm,
      );
      final begin = ElectricalRouteService.endpoint(a);
      final finish = ElectricalRouteService.endpoint(b);
      final vertices = <ElectricalRouteVertex>[begin];
      void add(ElectricalRouteVertex next) {
        if (vertices.last.distanceTo(next) > .001) vertices.add(next);
      }
      for (final vertex in corridor) add(vertex);
      add(finish);
      final route = ElectricalRoute3d(
        id: 'route-' + cable.id,
        fromPointId: a.id,
        toPointId: b.id,
        vertices: vertices,
        methods: List.filled(
          vertices.length - 1, ElectricalInstallationMethod.unspecified),
        source: ElectricalPathSource.unspecified,
        note: 'АВТОЧЕРНОВИК по графу стен одной комнаты. '
            'Не проверены инженерные коммуникации, балки, штробы, '
            'повороты, нормативные зоны, способ и доступность прокладки.',
      );
      ElectricalRouteExclusionService.requireClear(floor, route);
      final measurement = ElectricalRouteService.measure(
          floor, route, reserveMm: cable.explicitReserveMm);
      return ElectricalAutoRouteProposal(
        route: route,
        measurement: measurement,
        warnings: const [
          'Коридор найден только по геометрии стен одного помещения.',
          'Проверьте потолочные коммуникации, штробление, повороты, '
              'доступность и действующие ограничения.',
          'Это черновик без доказанной монтажной допустимости.',
        ],
      );
    }
    final wall = floor.wallById(a.wallId!);
    final wallStart = wall == null
        ? null : floor.nodeById(wall.startNodeId);
    final wallEnd = wall == null
        ? null : floor.nodeById(wall.endNodeId);
    if (wall == null || wall.demolition || wall.isCurved ||
        wallStart == null || wallEnd == null || a.wallSide != b.wallSide) {
      throw const FormatException(
        'Обе точки должны находиться на одной стороне существующей стены.');
    }
    final verticalWall = (wallStart.xMm - wallEnd.xMm).abs() < .001;
    final horizontalWall = (wallStart.yMm - wallEnd.yMm).abs() < .001;
    if (!verticalWall && !horizontalWall) {
      throw const FormatException(
        'Для повёрнутой стены автопуть пока не строится. '
        'Нужен алгоритм по графу допустимых коридоров.');
    }
    final height = wall.heightOverrideMm ?? floor.defaultHeightMm;
    final routeZ = height - ceilingDropMm;
    if (!height.isFinite || height <= 0 || routeZ < 0 ||
        !a.heightMm.isFinite || !b.heightMm.isFinite ||
        a.heightMm < 0 || b.heightMm < 0 ||
        a.heightMm > routeZ || b.heightMm > routeZ) {
      throw const FormatException(
        'Не хватает подтверждённой высоты для подъёма к потолку.');
    }
    final low = a.wallOffsetMm! < b.wallOffsetMm!
        ? a.wallOffsetMm! : b.wallOffsetMm!;
    final high = a.wallOffsetMm! > b.wallOffsetMm!
        ? a.wallOffsetMm! : b.wallOffsetMm!;
    final wallLength = floor.wallLengthMm(wall);
    if (!wallLength.isFinite || low < 0 || high > wallLength) {
      throw const FormatException('Точки вышли за пределы выбранной стены.');
    }
    for (final opening in wall.openings) {
      final oStart = opening.offsetFromStartMm;
      final oEnd = oStart + opening.widthMm;
      final oTop = opening.sillHeightMm + opening.heightMm;
      if (low <= oEnd && high >= oStart &&
          routeZ <= oTop && routeZ >= opening.sillHeightMm) {
        throw FormatException(
          'Черновой коридор пересекает проём ${opening.id} '
          'на высоте ${routeZ.round()} мм.');
      }
    }

    final begin = ElectricalRouteService.endpoint(a);
    final finish = ElectricalRouteService.endpoint(b);
    final vertices = <ElectricalRouteVertex>[begin];
    final methods = <ElectricalInstallationMethod>[];
    void append(ElectricalRouteVertex next) {
      if (vertices.last.distanceTo(next) < .001) return;
      vertices.add(next);
      // Candidate only. Actual concealed/open installation method is unknown.
      methods.add(ElectricalInstallationMethod.unspecified);
    }
    append(ElectricalRouteVertex(
      xMm: begin.xMm, yMm: begin.yMm, zMm: routeZ));
    append(ElectricalRouteVertex(
      xMm: finish.xMm, yMm: finish.yMm, zMm: routeZ));
    append(finish);
    if (vertices.length < 2) {
      throw const FormatException('Нулевая длина маршрута.');
    }
    final proposed = ElectricalRoute3d(
      id: 'route-' + cable.id,
      fromPointId: a.id,
      toPointId: b.id,
      vertices: vertices,
      methods: methods,
      source: ElectricalPathSource.unspecified,
      note: 'АВТОЧЕРНОВИК по стене. Не проверены способ прокладки, '
          'балки, инженерные коммуникации, доступность, нормативные зоны '
          'и возможность скрытого монтажа.',
    );
    ElectricalRouteExclusionService.requireClear(floor, proposed);
    final measurement = ElectricalRouteService.measure(
        floor, proposed, reserveMm: cable.explicitReserveMm);
    return ElectricalAutoRouteProposal(
      route: proposed,
      measurement: measurement,
      warnings: const [
        'Черновой вариант, не монтажная трасса.',
        'Проверьте балки, запретные зоны, влажность, коммуникации, '
            'реальную отметку потолка и способ прокладки.',
        'Ручные существующие трассы никогда не заменяются автоматически.',
      ],
    );
  }
}
