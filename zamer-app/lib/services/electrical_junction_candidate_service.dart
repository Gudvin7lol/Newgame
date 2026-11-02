import 'dart:math' as math;

import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_frame_geometry.dart';
import 'electrical_route_exclusion_service.dart';
import 'geometry_service.dart';

/// An unapproved, geometric candidate for a junction box. These suggestions
/// NEVER create circuits, terminals, physical routes, or wiring connections.
class ElectricalJunctionCandidate {
  const ElectricalJunctionCandidate({
    required this.roomKey,
    required this.circuitLabel,
    required this.loadClass,
    required this.wallId,
    required this.wallSide,
    required this.wallOffsetMm,
    required this.xMm,
    required this.yMm,
    required this.heightMm,
    required this.consumerIds,
    required this.nominalDistanceMm,
    required this.warnings,
  });

  final String roomKey, circuitLabel, loadClass, wallId;
  final int wallSide;
  final double wallOffsetMm, xMm, yMm, heightMm, nominalDistanceMm;
  final List<String> consumerIds;
  final List<String> warnings;

  /// Placement of the symbol is not acceptance of the terminal design.
  ElectricalPoint asPoint(String id) => ElectricalPoint(
    id: id,
    type: ElectricalPointType.junctionBox,
    xMm: xMm,
    yMm: yMm,
    wallId: wallId,
    wallOffsetMm: wallOffsetMm,
    wallSide: wallSide,
    heightMm: heightMm,
    label: 'РК · $circuitLabel',
    circuit: circuitLabel,
  );
}

class ElectricalJunctionCandidateService {
  const ElectricalJunctionCandidateService._();

  static String? _loadClass(ElectricalPoint p) => switch (p.type) {
    ElectricalPointType.socket ||
    ElectricalPointType.frame ||
    ElectricalPointType.appliance => 'силовая',
    ElectricalPointType.wallLight ||
    ElectricalPointType.ceilingLight ||
    ElectricalPointType.switchPoint => 'освещение',
    _ => null,
  };

  /// Room membership needs an oriented wall face or a ceiling point strictly
  /// inside the known inner polygon. Never use proximity to guess a room.
  static bool _inRoom(FloorPlan floor, RoomFace room, ElectricalPoint p) {
    if (p.wallId != null) {
      return room.edges.any((edge) {
        if (edge.wallId != p.wallId) return false;
        final wall = floor.wallById(edge.wallId);
        if (wall == null) return false;
        final side = edge.fromNodeId == wall.startNodeId ? 1 : -1;
        return side == p.wallSide;
      });
    }
    if (p.type != ElectricalPointType.ceilingLight ||
        room.innerPolygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = room.innerPolygon.length - 1;
        i < room.innerPolygon.length; j = i++) {
      final a = room.innerPolygon[i], b = room.innerPolygon[j];
      if ((a.y > p.yMm) == (b.y > p.yMm)) continue;
      final x = (b.x - a.x) * (p.yMm - a.y) / (b.y - a.y) + a.x;
      if (p.xMm < x) inside = !inside;
    }
    return inside;
  }

  /// Generate room-level options, each for a *single provisional group*.
  /// Distance is a heuristic, NOT a calculation of the required cable length.
  static List<ElectricalJunctionCandidate> propose(
    FloorPlan floor, {
    int maxCandidates = 12,
    double minimumCornerClearanceMm = 300,
    double stationStepMm = 250,
    double dropFromCeilingMm = 200,
  }) {
    if (maxCandidates < 1 || maxCandidates > 100 ||
        !minimumCornerClearanceMm.isFinite ||
        minimumCornerClearanceMm < 150 ||
        !stationStepMm.isFinite || stationStepMm < 50 ||
        !dropFromCeilingMm.isFinite || dropFromCeilingMm < 150) {
      throw const FormatException('Недопустимые параметры поиска кандидатов РК.');
    }
    final zones = ElectricalRouteExclusionService.saved(floor);
    final suggestions = <ElectricalJunctionCandidate>[];

    for (final room in GeometryService.roomFaces(floor)) {
      final ceilingOfRoom = floor.roomMetaByKey(room.key)?.ceilingHeightMm;
      final groups = <String, List<ElectricalPoint>>{};
      for (final point in floor.electricalPoints) {
        final cls = _loadClass(point);
        if (cls == null || !_inRoom(floor, room, point)) continue;
        // This legacy display group is NOT proof of actual circuit wiring.
        final label = point.circuit.trim();
        if (label.isEmpty) continue;
        groups.putIfAbsent('$cls|$label', () => []).add(point);
      }
      for (final entry in groups.entries) {
        final consumers = entry.value;
        if (consumers.length < 2) continue;
        // Do not propose another box for the same provisional group if the
        // project already has a room box labelled for that group.
        final alreadyBoxed = floor.electricalPoints.any((point) =>
            point.type == ElectricalPointType.junctionBox &&
            point.circuit.trim() == consumers.first.circuit.trim() &&
            _inRoom(floor, room, point));
        if (alreadyBoxed) continue;
        final separator = entry.key.indexOf('|');
        final cls = entry.key.substring(0, separator);
        final circuit = entry.key.substring(separator + 1);
        ElectricalJunctionCandidate? best;

        for (final edge in room.edges) {
          final wall = floor.wallById(edge.wallId);
          if (wall == null || wall.demolition || wall.isCurved) continue;
          final start = floor.nodeById(wall.startNodeId);
          final end = floor.nodeById(wall.endNodeId);
          if (start == null || end == null) continue;
          final length = floor.wallLengthMm(wall);
          final wallHeight = wall.heightOverrideMm ?? floor.defaultHeightMm;
          final ceiling = ceilingOfRoom == null
              ? wallHeight : math.min(wallHeight, ceilingOfRoom);
          final height = ceiling - dropFromCeilingMm;
          if (!length.isFinite || length < 2 * minimumCornerClearanceMm ||
              !ceiling.isFinite || height < 1500) continue;
          final dx = end.xMm - start.xMm;
          final dy = end.yMm - start.yMm;
          if (dx.abs() > .001 && dy.abs() > .001) {
            continue; // avoid slanted-wall mounting until verified
          }
          final side = edge.fromNodeId == wall.startNodeId ? 1 : -1;

          for (var station = minimumCornerClearanceMm;
              station <= length - minimumCornerClearanceMm;
              station += stationStepMm) {
            // Allow a nominal 150 mm buffer from a known opening edge.
            if (wall.openings.any((opening) {
              final low = opening.offsetFromStartMm - 150;
              final high = opening.offsetFromStartMm + opening.widthMm + 150;
              final bottom = opening.sillHeightMm - 100;
              final top = opening.sillHeightMm + opening.heightMm + 100;
              return station >= low && station <= high &&
                  height >= bottom && height <= top;
            })) continue;

            final t = station / length;
            final x = start.xMm + dx * t;
            final y = start.yMm + dy * t;
            final vertex = ElectricalRouteVertex(
                xMm:x, yMm:y, zMm:height);
            if (ElectricalRouteExclusionService.conflictForLeg(
                vertex, vertex, zones) != null) continue;

            // Installation position must not overlap an existing electrical
            // mechanism or junction, even if no formal collision model exists.
            final overlaps = floor.electricalPoints.any((p) =>
              p.wallId == wall.id && p.wallSide == side &&
              p.wallOffsetMm != null &&
              (p.wallOffsetMm! - station).abs() < 180 &&
              (p.heightMm - height).abs() < 180);
            if (overlaps) continue;
            final candidatePoint = ElectricalPoint(
              id:'preview-junction',type:ElectricalPointType.junctionBox,
              xMm:x,yMm:y,heightMm:height,
              wallId:wall.id,wallOffsetMm:station,wallSide:side,
            );
            if (ElectricalFrameGeometry.conflictWithFrames(
                  floor,candidatePoint) != null) continue;

            var nominalDistance = 0.0;
            for (final p in consumers) {
              nominalDistance += (p.xMm-x).abs() + (p.yMm-y).abs()
                  + (p.heightMm-height).abs();
            }
            if (best == null ||
                nominalDistance < best.nominalDistanceMm) {
              best = ElectricalJunctionCandidate(
                roomKey:room.key, circuitLabel:circuit, loadClass:cls,
                wallId:wall.id, wallSide:side,
                wallOffsetMm:station, xMm:x, yMm:y, heightMm:height,
                consumerIds:List.unmodifiable(consumers.map((p) => p.id)),
                nominalDistanceMm:nominalDistance,
                warnings:const [
                  'Группа взята из подписей точек, а не из '
                      'проверенной схемы соединений.',
                  'Требуется подтвердить доступность коробки после отделки, '
                      'отсутствие скрытых коммуникаций и допустимость монтажа.',
                  'Вместимость, соединители, количество кабелей и '
                      'назначение жил не рассчитаны.',
                  'Длина дана только для сравнения кандидатов, '
                      'не для закупки кабеля.',
                ],
              );
            }
          }
        }
        if (best != null) suggestions.add(best);
      }
    }
    suggestions.sort((a,b) {
      final score = a.nominalDistanceMm.compareTo(b.nominalDistanceMm);
      return score != 0 ? score : a.wallId.compareTo(b.wallId);
    });
    return suggestions.take(maxCandidates).toList();
  }

  /// Recompute before a user-approved placement to avoid stale geometry.
  /// Does not mutate the floor. The caller owns Undo and persistence.
  static ElectricalPoint preparePlacement(
    FloorPlan floor,
    ElectricalJunctionCandidate candidate, {
    required String id,
  }) {
    if (id.trim().isEmpty ||
        floor.electricalPoints.any((p) => p.id == id)) {
      throw const FormatException('Некорректный ID новой коробки.');
    }
    final available = propose(floor, maxCandidates:100)
        .where((c) => c.roomKey == candidate.roomKey &&
          c.circuitLabel == candidate.circuitLabel &&
          c.loadClass == candidate.loadClass &&
          c.wallId == candidate.wallId &&
          c.wallSide == candidate.wallSide &&
          (c.wallOffsetMm - candidate.wallOffsetMm).abs() < .01 &&
          (c.heightMm - candidate.heightMm).abs() < .01)
        .firstOrNull;
    if (available == null) {
      throw const FormatException(
        'Кандидат РК устарел. Пересчитайте предложения.');
    }
    return available.asPoint(id);
  }
}
