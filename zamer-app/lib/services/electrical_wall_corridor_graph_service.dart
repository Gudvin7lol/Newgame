import 'dart:math' as math;

import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'geometry_service.dart';
import 'electrical_route_exclusion_service.dart';

/// Finds the shortest known orthogonal wall-axis corridor within one
/// topologically closed room. The output is a DRAFT, never a permitted cable
/// installation route. Missing rooms, inaccessible bends and unknown services
/// are NOT assumed to be safe.
class ElectricalWallCorridorGraphService {
  const ElectricalWallCorridorGraphService._();

  static List<ElectricalRouteVertex> find(
    FloorPlan floor,
    ElectricalPoint start,
    ElectricalPoint finish, {
    required double zMm,
    double minimumCeilingDropMm = 150,
  }) {
    if (!zMm.isFinite || zMm < 0 ||
        !minimumCeilingDropMm.isFinite || minimumCeilingDropMm < 0 ||
        start.wallId == null || finish.wallId == null ||
        start.wallOffsetMm == null || finish.wallOffsetMm == null ||
        !start.heightMm.isFinite || !finish.heightMm.isFinite ||
        start.heightMm > zMm || finish.heightMm > zMm) {
      throw const FormatException('Нет достоверной геометрии и высот для коридора.');
    }
    final faces = GeometryService.roomFaces(floor).where(
      (face) => face.innerPolygon.length >= 3 &&
          face.edges.any((e) => e.wallId == start.wallId) &&
          face.edges.any((e) => e.wallId == finish.wallId),
    );
    List<ElectricalRouteVertex>? shortest;
    double shortestMm = double.infinity;
    for (final face in faces) {
      // Verify the mount faces. A wall shared by two rooms has two different
      // normals. Never join a socket to a route on the opposite room face.
      bool belongs(ElectricalPoint point) => face.edges.any((edge) {
        if (edge.wallId != point.wallId) return false;
        final wall = floor.wallById(edge.wallId);
        if (wall == null) return false;
        final side = edge.fromNodeId == wall.startNodeId ? 1 : -1;
        return point.wallSide == side;
      });
      if (!belongs(start) || !belongs(finish)) continue;
      final adjacency = <String, List<({String to, double lengthMm})>>{};
      void connect(String first, String second, double lengthMm) {
        if (!lengthMm.isFinite || lengthMm <= .001) return;
        adjacency.putIfAbsent(first, () => [])
            .add((to: second, lengthMm: lengthMm));
        adjacency.putIfAbsent(second, () => [])
            .add((to: first, lengthMm: lengthMm));
      }
      bool spanAllowed(PlanWall wall, double beginMm, double endMm) {
        final low = math.min(beginMm, endMm);
        final high = math.max(beginMm, endMm);
        final from = floor.nodeById(wall.startNodeId);
        final to = floor.nodeById(wall.endNodeId);
        final length = floor.wallLengthMm(wall);
        if (from == null || to == null || length <= 0) return false;
        ElectricalRouteVertex at(double station) => ElectricalRouteVertex(
          xMm: from.xMm + (to.xMm-from.xMm)*station/length,
          yMm: from.yMm + (to.yMm-from.yMm)*station/length,
          zMm: zMm,
        );
        if (ElectricalRouteExclusionService.conflictForLeg(
          at(beginMm), at(endMm),
          ElectricalRouteExclusionService.saved(floor),
        ) != null) return false;
        return !wall.openings.any((opening) {
          final oLow = opening.offsetFromStartMm;
          final oHigh = oLow + opening.widthMm;
          final oBottom = opening.sillHeightMm;
          final oTop = oBottom + opening.heightMm;
          return low < oHigh && high > oLow &&
              zMm >= oBottom && zMm <= oTop;
        });
      }
      bool sameAxis(PlanNode a, PlanNode b) =>
          (a.xMm - b.xMm).abs() < .001 ||
          (a.yMm - b.yMm).abs() < .001;
      bool pointProjectionValid(ElectricalPoint point, PlanWall wall,
          PlanNode a, PlanNode b, double length) {
        final station = point.wallOffsetMm;
        if (station == null || !station.isFinite ||
            station < 0 || station > length) return false;
        final t = station / length;
        return (point.xMm - (a.xMm + (b.xMm - a.xMm) * t)).abs() < .5 &&
            (point.yMm - (a.yMm + (b.yMm - a.yMm) * t)).abs() < .5;
      }
      var validFace = true;
      for (final edge in face.edges) {
        final wall = floor.wallById(edge.wallId);
        if (wall == null || wall.isCurved || wall.demolition) continue;
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        final length = floor.wallLengthMm(wall);
        final ceiling = wall.heightOverrideMm ?? floor.defaultHeightMm;
        if (a == null || b == null || !sameAxis(a, b) ||
            !length.isFinite || length <= .001 ||
            !ceiling.isFinite || ceiling - minimumCeilingDropMm < zMm) {
          continue;
        }
        final aKey = 'node:${a.id}';
        final bKey = 'node:${b.id}';
        if (spanAllowed(wall, 0, length)) connect(aKey, bKey, length);
        for (final record in [
          (point: start, key: '@start'),
          (point: finish, key: '@finish'),
        ]) {
          final point = record.point;
          if (wall.id != point.wallId) continue;
          if (!pointProjectionValid(point, wall, a, b, length)) {
            validFace = false;
            break;
          }
          final station = point.wallOffsetMm!;
          if (station < .001) {
            connect(record.key, aKey, .002);
          } else if (spanAllowed(wall, 0, station)) {
            connect(record.key, aKey, station);
          }
          if ((length - station).abs() < .001) {
            connect(record.key, bKey, .002);
          } else if (spanAllowed(wall, station, length)) {
            connect(record.key, bKey, length - station);
          }
        }
        if (!validFace) break;
      }
      if (!validFace) continue;

      // Dijkstra over the room's orthogonal wall graph; no crossing of walls,
      // no Manhattan diagonals through rooms and no unsupported Z movement.
      final dist = <String, double>{'@start': 0};
      final previous = <String, String>{};
      final visited = <String>{};
      while (true) {
        String? current;
        var minDistance = double.infinity;
        for (final entry in dist.entries) {
          if (!visited.contains(entry.key) && entry.value < minDistance) {
            current = entry.key;
            minDistance = entry.value;
          }
        }
        if (current == null || current == '@finish') break;
        visited.add(current);
        for (final edge in adjacency[current] ??
            const <({String to, double lengthMm})>[]) {
          final candidate = minDistance + edge.lengthMm;
          if (candidate < (dist[edge.to] ?? double.infinity)) {
            dist[edge.to] = candidate;
            previous[edge.to] = current;
          }
        }
      }
      if (!dist.containsKey('@finish')) continue;
      final order = <String>[];
      String? current = '@finish';
      while (current != null) {
        order.add(current);
        current = previous[current];
      }
      final ordered = order.reversed.toList();
      ElectricalRouteVertex vertex(String key) {
        if (key == '@start') return ElectricalRouteVertex(
            xMm: start.xMm, yMm: start.yMm, zMm: zMm);
        if (key == '@finish') return ElectricalRouteVertex(
            xMm: finish.xMm, yMm: finish.yMm, zMm: zMm);
        final node = floor.nodeById(key.substring(5))!;
        return ElectricalRouteVertex(
            xMm: node.xMm, yMm: node.yMm, zMm: zMm);
      }
      final result = <ElectricalRouteVertex>[];
      for (final key in ordered) {
        final next = vertex(key);
        if (result.isNotEmpty && result.last.distanceTo(next) < .001) {
          continue;
        }
        result.add(next);
      }
      if (result.length < 2) continue;
      if (dist['@finish']! < shortestMm) {
        shortestMm = dist['@finish']!;
        shortest = result;
      }
    }
    if (shortest == null) {
      throw const FormatException(
        'Не найден непрерывный коридор по одной стороне стен '
        'одного помещения. Проверьте проёмы, отметки и геометрию.');
    }
    return shortest;
  }
}
