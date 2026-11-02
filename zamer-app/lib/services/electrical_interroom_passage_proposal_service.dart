import 'dart:math' as math;

import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_route_service.dart';
import 'electrical_wall_corridor_graph_service.dart';
import 'geometry_service.dart';

/// An explicit, review-only passage proposal. A doorway is used as a
/// *reference* for a candidate above-opening penetration. This does NOT
/// certify permission to drill a lintel, load-bearing structure, fire barrier
/// or any other wall. Approval remains a separate site/design decision.
class ElectricalInterroomPassageProposalService {
  const ElectricalInterroomPassageProposalService._();

  static ElectricalRoute3d prepare(
    FloorPlan floor,
    ElectricalCableRecord cable, {
    required String passageWallId,
    required String openingId,
    required bool explicitlySelected,
    double ceilingDropMm = 150,
  }) {
    if (!explicitlySelected) {
      throw const FormatException(
          'Выберите конкретный переход между помещениями.');
    }
    if (cable.route3dId != null) {
      throw const FormatException(
          'Ручная трасса уже сохранена. Автоподбор не заменяет её.');
    }
    if (!ceilingDropMm.isFinite ||
        ceilingDropMm < 150 || ceilingDropMm > 1000) {
      throw const FormatException('Неверный отступ трассы от потолка.');
    }
    final source = floor.electricalPoints
        .where((p) => p.id == cable.fromPointId).firstOrNull;
    final target = floor.electricalPoints
        .where((p) => p.id == cable.toPointId).firstOrNull;
    if (source == null || target == null || source.id == target.id ||
        source.wallId == null || target.wallId == null) {
      throw const FormatException(
          'Концевые точки перехода не привязаны к стенам.');
    }
    final wall = floor.wallById(passageWallId);
    final opening = wall?.openings
        .where((o) => o.id == openingId).firstOrNull;
    if (wall == null || opening == null ||
        opening.type != OpeningType.door || wall.isCurved ||
        wall.demolition) {
      throw const FormatException(
          'Нужна реальная дверь в существующей прямой общей стене.');
    }
    final n0 = floor.nodeById(wall.startNodeId);
    final n1 = floor.nodeById(wall.endNodeId);
    if (n0 == null || n1 == null) {
      throw const FormatException('Недоступна геометрия стены перехода.');
    }
    final wallDx = n1.xMm - n0.xMm;
    final wallDy = n1.yMm - n0.yMm;
    final len = floor.wallLengthMm(wall);
    final aligned = wallDx.abs() < .001 || wallDy.abs() < .001;
    final station = opening.offsetFromStartMm + opening.widthMm / 2;
    final wallHeight = wall.heightOverrideMm ?? floor.defaultHeightMm;
    final z = wallHeight - ceilingDropMm;
    if (!aligned || !len.isFinite || len <= 0 ||
        !wall.thicknessMm.isFinite || wall.thicknessMm <= 0 ||
        station <= 0 || station >= len ||
        !wallHeight.isFinite || z <= 0 ||
        z < opening.sillHeightMm + opening.heightMm + 100) {
      throw const FormatException(
        'Нет проверяемого прямого участка над дверью для черновика. '
        'Наличие перемычки требует отдельной оценки.',
      );
    }

    final faces = GeometryService.roomFaces(floor);
    bool belongs(RoomFace face, ElectricalPoint p) =>
        face.edges.any((edge) {
          if (edge.wallId != p.wallId) return false;
          final candidate = floor.wallById(edge.wallId);
          if (candidate == null) return false;
          final side = edge.fromNodeId == candidate.startNodeId ? 1 : -1;
          return side == p.wallSide;
        });
    final roomsA = faces.where((f) => belongs(f, source)).toList();
    final roomsB = faces.where((f) => belongs(f, target)).toList();
    if (roomsA.length != 1 || roomsB.length != 1 ||
        roomsA.single.key == roomsB.single.key) {
      throw const FormatException(
          'Для перехода нужны две разные замкнутые комнаты.');
    }
    final roomA = roomsA.single, roomB = roomsB.single;
    int? passageSide(RoomFace room) {
      for (final edge in room.edges) {
        if (edge.wallId == passageWallId) {
          return edge.fromNodeId == wall.startNodeId ? 1 : -1;
        }
      }
      return null;
    }
    final sideA = passageSide(roomA);
    final sideB = passageSide(roomB);
    if (sideA == null || sideB == null || sideA == sideB) {
      throw const FormatException(
          'Дверь не является общей границей выбранных комнат.');
    }
    final x = n0.xMm + (wallDx / len) * station;
    final y = n0.yMm + (wallDy / len) * station;
    ElectricalPoint gate(String suffix, int side) => ElectricalPoint(
      id: 'preview-gate-$suffix',
      type: ElectricalPointType.junctionBox,
      xMm: x, yMm: y, heightMm: z,
      wallId: passageWallId, wallOffsetMm: station,
      wallSide: side,
    );
    final pathA = ElectricalWallCorridorGraphService.find(
        floor, source, gate('a', sideA),
        zMm: z, minimumCeilingDropMm: ceilingDropMm);
    final pathB = ElectricalWallCorridorGraphService.find(
        floor, gate('b', sideB), target,
        zMm: z, minimumCeilingDropMm: ceilingDropMm);

    final vertices = <ElectricalRouteVertex>[
      ElectricalRouteService.endpoint(source),
    ];
    void append(ElectricalRouteVertex vertex) {
      if (vertices.last.distanceTo(vertex) > .001) vertices.add(vertex);
    }
    for (final v in pathA) append(v);
    // Nominal geometric witness of the wall thickness. Both offsets are
    // fictive until a surveyed penetration/route is specified; even the
    // measured geometric total must never be treated as procurement quantity.
    final nx = -wallDy / len, ny = wallDx / len;
    final half = wall.thicknessMm / 2;
    append(ElectricalRouteVertex(
      xMm: x + nx * sideA * half,
      yMm: y + ny * sideA * half, zMm: z));
    append(ElectricalRouteVertex(
      xMm: x + nx * sideB * half,
      yMm: y + ny * sideB * half, zMm: z));
    append(ElectricalRouteVertex(xMm: x, yMm: y, zMm: z));
    for (final v in pathB) append(v);
    append(ElectricalRouteService.endpoint(target));
    final route = ElectricalRoute3d(
      id: 'route-' + cable.id,
      fromPointId: source.id, toPointId: target.id,
      vertices: vertices,
      methods: List.filled(
          vertices.length - 1, ElectricalInstallationMethod.unspecified),
      source: ElectricalPathSource.unspecified,
      note: 'ПРЕДПРОСМОТР: переход над дверью $openingId '
          'в стене $passageWallId. Проход через конструкцию и '
          'номинальная толщина НЕ обмерены и НЕ согласованы. '
          'Требуется отдельная проверка пожарных преград, перемычки, '
          'несущих конструкций и способа монтажа.',
    );
    // Independently validate the axis-aligned construction and endpoints.
    ElectricalRouteService.measure(floor, route);
    return route;
  }
}
