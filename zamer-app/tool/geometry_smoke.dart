import 'dart:math' as math;

import '../lib/models/models.dart';
import '../lib/services/geometry_service.dart';
import '../lib/services/floor_continuity_service.dart';
import '../lib/services/layout_service.dart';

void main() {
  final floor = FloorPlan(id: 'smoke', name: 'Две комнаты');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3000, yMm: 0),
    PlanNode(id: 'c', xMm: 6000, yMm: 0),
    PlanNode(id: 'd', xMm: 6000, yMm: 3000),
    PlanNode(id: 'e', xMm: 3000, yMm: 3000),
    PlanNode(id: 'f', xMm: 1500, yMm: 3000),
    PlanNode(id: 'g', xMm: 0, yMm: 3000),
    PlanNode(id: 'tip', xMm: 1500, yMm: 1800),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
    PlanWall(id: 'ef', startNodeId: 'e', endNodeId: 'f'),
    PlanWall(id: 'fg', startNodeId: 'f', endNodeId: 'g'),
    PlanWall(id: 'ga', startNodeId: 'g', endNodeId: 'a'),
    PlanWall(id: 'partition', startNodeId: 'f', endNodeId: 'tip'),
    PlanWall(
      id: 'shared',
      startNodeId: 'b',
      endNodeId: 'e',
      openings: [
        WallOpening(
          id: 'door',
          type: OpeningType.door,
          widthMm: 900,
          heightMm: 2100,
          offsetFromStartMm: 1000,
        ),
      ],
    ),
  ]);
  final rooms = GeometryService.roomFaces(floor);
  if (rooms.length != 2 ||
      rooms.any((r) => r.edges.any((e) => e.wallId == 'partition'))) {
    throw StateError('Свободная перегородка исказила контур: ${rooms.length}');
  }
  final thresholds = FloorContinuityService.doorThresholds(floor, rooms);
  if (thresholds.length != 1 ||
      thresholds.single.map((p) => p.x).reduce(math.min) >= 3000 ||
      thresholds.single.map((p) => p.x).reduce(math.max) <= 3000) {
    throw StateError('Покрытие не продолжается через дверь');
  }
  for (final room in rooms) {
    if (LayoutService.finishPolygon(room).length < 4 || room.areaM2 < 7) {
      throw StateError('Неверная геометрия пола');
    }
  }
  final opposite = GeometryService.parallelReferenceLength(
    floor,
    floor.nodeById('a')!,
    0,
  );
  if (opposite == null || (opposite - 3000).abs() > 1) {
    throw StateError('Не найдена противоположная стена: $opposite');
  }
  print('Геометрия: 2 комнаты, 1 дверной переход, перегородка без выреза.');
}
