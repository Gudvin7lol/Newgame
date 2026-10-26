import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/work_generation_service.dart';
import 'package:zamer_app/services/work_floor_surface_service.dart';

FloorPlan rectangle([String id = 'f1']) {
  final floor = FloorPlan(
    id: id, name: 'Этаж',
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  test('tile and laminate areas are clipped without overlap or loss', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    final b = WorkFloorSurfaceService.bounds(face, 'x');
    final split = WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'x', cutMm: (b.min + b.max) / 2,
      tileBeforeCut: true,
    );
    final result = WorkFloorSurfaceService.areas(
      board, floor, face, preview: split);
    expect(result.tileM2, closeTo(face.areaM2 / 2, .02));
    expect(result.laminateM2, closeTo(face.areaM2 / 2, .02));
    expect(result.tileM2 + result.laminateM2, closeTo(face.areaM2, .001));
    expect(board.floorFinishes, isEmpty);
    WorkFloorSurfaceService.save(board, floor, face, split);
    expect(WorkFloorSurfaceService.areas(board, floor, face), result);
    final restored = WorkBoard.fromJson(board.toJson());
    expect(restored.floorFinishes.single.cutMm, split.cutMm);
    expect(WorkFloorSurfaceService.areas(restored, floor, face), result);
  });

  test('horizontal split and swapped tile side partition entire room', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    final bounds = WorkFloorSurfaceService.bounds(face, 'y');
    final cutoff = bounds.min + (bounds.max - bounds.min) * .32;
    final selected = WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'y', cutMm: cutoff, tileBeforeCut: true,
    );
    final left = WorkFloorSurfaceService.areas(
      board, floor, face, preview: selected);
    final swapped = WorkFloorSurfaceService.areas(
      board, floor, face, preview: WorkFloorFinishSplit(
        floorId: selected.floorId, roomId: selected.roomId,
        axis: 'y', cutMm: cutoff, tileBeforeCut: false,
      ));
    expect(left.tileM2 + left.laminateM2, closeTo(face.areaM2, .001));
    expect(swapped.tileM2, closeTo(left.laminateM2, .001));
    expect(swapped.laminateM2, closeTo(left.tileM2, .001));
  });

  test('save validates belongs-to-room, split bounds and nonempty zones', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard();
    final bounds = WorkFloorSurfaceService.bounds(face, 'x');
    WorkFloorFinishSplit item(double cut, {String room = ''}) =>
      WorkFloorFinishSplit(
        floorId: floor.id,
        roomId: room.isEmpty ? floor.roomMetas.single.id : room,
        axis: 'x', cutMm: cut, tileBeforeCut: true,
      );
    expect(() => WorkFloorSurfaceService.save(
      board, floor, face, item(bounds.min)), throwsArgumentError);
    expect(() => WorkFloorSurfaceService.save(
      board, floor, face, item(bounds.max + 1000)), throwsArgumentError);
    expect(() => WorkFloorSurfaceService.save(
      board, floor, face, item((bounds.min + bounds.max) / 2, room: 'other')),
      throwsArgumentError);
    expect(board.floorFinishes, isEmpty);
  });

  test('generator creates two separate area-bound finish tasks', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final project = MeasureProject(
      id: 'p', name: 'Комната', floors: [floor]);
    final b = WorkFloorSurfaceService.bounds(face, 'x');
    WorkFloorSurfaceService.save(project.workBoard, floor, face,
      WorkFloorFinishSplit(
        floorId: floor.id, roomId: floor.roomMetas.single.id,
        axis: 'x', cutMm: b.min + (b.max - b.min) * .4,
        tileBeforeCut: true,
      ));
    final plan = WorkGenerationService.preview(
      project, begin: DateTime(2026, 11, 2));
    final tile = plan.tasks.firstWhere((t) =>
      t.operationCode == 'floor_tile');
    final laminate = plan.tasks.firstWhere((t) =>
      t.operationCode == 'floor_laminate');
    final underlay = plan.tasks.firstWhere((t) =>
      t.operationCode == 'floor_underlay');
    expect(tile.quantity, greaterThan(0));
    expect(laminate.quantity, greaterThan(0));
    expect(tile.quantity + laminate.quantity, closeTo(face.areaM2, .03));
    expect(underlay.quantity, closeTo(laminate.quantity, .001));
    expect(tile.requiredPredecessorIds, isNot(contains(laminate.id)));
    expect(laminate.requiredPredecessorIds, isNot(contains(tile.id)));
    expect(project.workBoard.tasks, isEmpty);
  });

  test('refresh changes only unstarted floor works without losing acceptance', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final project = MeasureProject(
      id: 'p', name: 'Комната', floors: [floor]);
    final board = project.workBoard;
    final plan = WorkGenerationService.preview(project);
    expect(WorkGenerationService.apply(board, plan), isNull);
    final laminate = board.tasks.firstWhere(
      (t) => t.operationCode == 'floor_laminate');
    final oldQuantity = laminate.quantity;
    final oldHours = laminate.hours;
    final bounds = WorkFloorSurfaceService.bounds(face, 'x');
    WorkFloorSurfaceService.save(board, floor, face, WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'x', cutMm: (bounds.min + bounds.max) / 2,
      tileBeforeCut: true,
    ));
    expect(WorkFloorSurfaceService.refreshUnstarted(board, floor, face),
      greaterThan(0));
    expect(laminate.quantity, lessThan(oldQuantity));
    expect(laminate.hours, lessThan(oldHours));
    final keptQty = laminate.quantity;
    laminate.done = keptQty / 2;
    WorkFloorSurfaceService.save(board, floor, face, WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'x', cutMm: bounds.min + (bounds.max - bounds.min) * .8,
      tileBeforeCut: true,
    ));
    WorkFloorSurfaceService.refreshUnstarted(board, floor, face);
    expect(laminate.quantity, keptQty);
    expect(laminate.done, keptQty / 2);
  });

  test('old projects keep existing floor finish mode by default', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final board = WorkBoard.fromJson({});
    expect(board.floorFinishes, isEmpty);
    final defaultAreas = WorkFloorSurfaceService.areas(
      board, floor, face);
    expect(defaultAreas.laminateM2, closeTo(face.areaM2, .001));
    expect(defaultAreas.tileM2, 0);
    floor.roomMetas.single.materials.floorMode = 'tile';
    final tile = WorkFloorSurfaceService.areas(board, floor, face);
    expect(tile.tileM2, closeTo(face.areaM2, .001));
    expect(tile.laminateM2, 0);
  });
}
