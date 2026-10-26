import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/work_generation_service.dart';
import 'package:zamer_app/services/work_surface_service.dart';

FloorPlan sampleRoom({bool door = false}) {
  final floor = FloorPlan(
    id: 'f1', name: 'Этаж',
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b',
        openings: door ? [
          WallOpening(id: 'door', type: OpeningType.door,
            widthMm: 900, heightMm: 2100, offsetFromStartMm: 900)
        ] : null),
      PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  test('paint and tile allocations never count wall area twice', () {
    final floor = sampleRoom(door: true);
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    final initial = WorkSurfaceService.walls(board, floor, face);
    expect(initial.length, 4);
    final net = initial.fold<double>(0, (s, wall) => s + wall.netAreaM2);
    final initialPaint = WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_paint');
    expect(initialPaint, closeTo(net, .001));
    expect(WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_tile'), closeTo(0, .001));

    WorkSurfaceService.save(board, floor, face, {
      'w1': 2700, 'w2': 0, 'w3': 2700, 'w4': 0,
    });
    final surfaces = WorkSurfaceService.walls(board, floor, face);
    final tile = WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_tile');
    final paint = WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_paint');
    expect(tile, greaterThan(0));
    expect(paint, greaterThan(0));
    expect(tile + paint, closeTo(net, .001));
    expect(surfaces.firstWhere((s) => s.wallId == 'w1').paintAreaM2,
      closeTo(0, .001));
    expect(WorkSurfaceService.wallIdsForCode(
      board, floor, face, 'wall_tile').toSet(), {'w1', 'w3'});
    expect(WorkSurfaceService.wallIdsForCode(
      board, floor, face, 'wall_paint').toSet(), {'w2', 'w4'});
  });

  test('partial tile band subtracts only intersecting part of door', () {
    final floor = sampleRoom(door: true);
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    WorkSurfaceService.save(board, floor, face, {'w1': 1200});
    final first = WorkSurfaceService.walls(board, floor, face)
      .firstWhere((s) => s.wallId == 'w1');
    final noDoor = sampleRoom();
    WorkSurfaceService.save(board, noDoor,
      GeometryService.roomFaces(noDoor).single, {'w1': 1200});
    final comparison = WorkSurfaceService.walls(board, noDoor,
      GeometryService.roomFaces(noDoor).single)
      .firstWhere((s) => s.wallId == 'w1');
    expect(first.tileAreaM2, lessThan(comparison.tileAreaM2));
    expect(first.paintAreaM2, lessThan(comparison.paintAreaM2));
    expect(first.tileAreaM2, greaterThan(0));
    expect(first.paintAreaM2, greaterThan(0));
  });

  test('preview does not mutate finish instructions and validates selections', () {
    final floor = sampleRoom();
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    final preview = WorkSurfaceService.walls(board, floor, face,
      previewHeights: {'w1': 1200});
    expect(preview.firstWhere((s) => s.wallId == 'w1').tileAreaM2,
      greaterThan(0));
    expect(board.wallFinishes, isEmpty);
    expect(() => WorkSurfaceService.save(board, floor, face,
      {'bad-wall': 300}), throwsArgumentError);
    expect(board.wallFinishes, isEmpty);
    WorkSurfaceService.save(board, floor, face, {'w1': 1200});
    final restored = WorkBoard.fromJson(board.toJson());
    expect(restored.wallFinishes.single.wallId, 'w1');
    expect(restored.wallFinishes.single.tileHeightMm, 1200);
  });

  test('room-based generator creates separate paint and tile quantities', () {
    final floor = sampleRoom(door: true);
    final project = MeasureProject(
      id: 'p', name: 'Комната', floors: [floor]);
    final face = GeometryService.roomFaces(floor).single;
    WorkSurfaceService.save(project.workBoard, floor, face, {
      'w1': 2700, 'w2': 0, 'w3': 2700, 'w4': 0,
    });
    final plan = WorkGenerationService.preview(project);
    final paint = plan.tasks.firstWhere((t) =>
      t.operationCode == 'wall_paint');
    final tile = plan.tasks.firstWhere((t) =>
      t.operationCode == 'wall_tile');
    expect(paint.quantity, closeTo(
      WorkSurfaceService.areaForCode(
        project.workBoard, floor, face, 'wall_paint'), .01));
    expect(tile.quantity, closeTo(
      WorkSurfaceService.areaForCode(
        project.workBoard, floor, face, 'wall_tile'), .01));
    expect(paint.surfaceWallIds.toSet(), {'w2', 'w4'});
    expect(tile.surfaceWallIds.toSet(), {'w1', 'w3'});
    expect(paint.quantity + tile.quantity,
      closeTo(WorkSurfaceService.walls(
        project.workBoard, floor, face).fold<double>(
          0, (s, wall) => s + wall.netAreaM2), .02));
  });

  test('refresh never changes accepted or started work', () {
    final floor = sampleRoom();
    final project = MeasureProject(
      id: 'p', name: 'Комната', floors: [floor]);
    final face = GeometryService.roomFaces(floor).single;
    final board = project.workBoard;
    final plan = WorkGenerationService.preview(project);
    expect(WorkGenerationService.apply(board, plan), isNull);
    final paint = board.tasks.firstWhere((t) =>
      t.operationCode == 'wall_paint');
    final initialQty = paint.quantity;
    final initialHours = paint.hours;
    WorkSurfaceService.save(board, floor, face, {
      'w1': 2700, 'w2': 0, 'w3': 0, 'w4': 0,
    });
    expect(WorkSurfaceService.refreshUnstartedFinishes(
      board, floor, face), greaterThan(0));
    expect(paint.quantity, lessThan(initialQty));
    expect(paint.hours, lessThan(initialHours));
    final safeQuantity = paint.quantity;
    paint.done = safeQuantity / 2;
    WorkSurfaceService.save(board, floor, face, {
      'w1': 2700, 'w2': 2700, 'w3': 0, 'w4': 0,
    });
    WorkSurfaceService.refreshUnstartedFinishes(board, floor, face);
    expect(paint.quantity, safeQuantity);
  });

  test('legacy material finish remains unchanged without explicit assignment', () {
    final floor = sampleRoom();
    final face = GeometryService.roomFaces(floor).single;
    final room = floor.roomMetas.single;
    room.materials.wallTile = true;
    room.materials.wallPaint = false;
    final board = WorkBoard();
    expect(WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_tile'), greaterThan(0));
    expect(WorkSurfaceService.areaForCode(
      board, floor, face, 'wall_paint'), 0);
  });
}
