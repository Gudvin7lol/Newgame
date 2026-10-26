import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/work_floor_polygon_service.dart';
import 'package:zamer_app/services/work_floor_surface_service.dart';
import 'package:zamer_app/services/work_generation_service.dart';
import 'package:zamer_app/services/work_status_service.dart';

typedef P = math.Point<double>;

FloorPlan room() {
  final f = FloorPlan(id: 'f', name: 'Этаж', nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ], walls: [
    PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
  ]);
  GeometryService.syncRoomMetadata(f);
  return f;
}

WorkFloorFinishZone zone(FloorPlan f, String id, List<P> polygon,
    {String material = 'tile'}) => WorkFloorFinishZone(
      id: id, floorId: f.id, roomId: f.roomMetas.single.id,
      material: material, polygon: polygon);

void main() {
  test('multiple tile polygons replace laminate only once and survive JSON', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final board = WorkBoard();
    // Use the actual internal polygon's bounding dimensions.
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final a = zone(f, 'a', [
      P(x.min + 100, y.min + 100), P(x.min + 800, y.min + 100),
      P(x.min + 800, y.min + 800), P(x.min + 100, y.min + 800),
    ]);
    final b = zone(f, 'b', [
      P(x.max - 900, y.max - 900), P(x.max - 200, y.max - 900),
      P(x.max - 200, y.max - 200), P(x.max - 900, y.max - 200),
    ]);
    WorkFloorPolygonService.save(board, f, face, [a, b]);
    final result = WorkFloorSurfaceService.areas(board, f, face);
    expect(result.tileM2, closeTo(.98, .001));
    expect(result.tileM2 + result.laminateM2,
      closeTo(face.areaM2, .001));
    expect(board.floorZones, hasLength(2));
    final loaded = WorkBoard.fromJson(board.toJson());
    expect(loaded.floorZones.length, 2);
    expect(loaded.floorZones[0].polygon.length, 4);
    expect(WorkFloorSurfaceService.areas(loaded, f, face), result);
  });

  test('rejects self-crossing, overlap, areas outside room, and duplicate IDs', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final board = WorkBoard();
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final crossing = zone(f, 'bad', [
      P(x.min + 100, y.min + 100), P(x.min + 1400, y.min + 1400),
      P(x.min + 100, y.min + 1400), P(x.min + 1400, y.min + 100),
    ]);
    expect(WorkFloorPolygonService.isSimple(crossing.polygon), false);
    expect(() => WorkFloorPolygonService.save(
      board, f, face, [crossing]), throwsArgumentError);
    final a = zone(f, 'a', [
      P(x.min + 100, y.min + 100), P(x.min + 1400, y.min + 100),
      P(x.min + 1400, y.min + 1400), P(x.min + 100, y.min + 1400),
    ]);
    final overlap = zone(f, 'b', [
      P(x.min + 800, y.min + 800), P(x.min + 1800, y.min + 800),
      P(x.min + 1800, y.min + 1800), P(x.min + 800, y.min + 1800),
    ]);
    expect(() => WorkFloorPolygonService.save(
      board, f, face, [a, overlap]), throwsArgumentError);
    final beyond = zone(f, 'outside', [
      P(x.min - 200, y.min + 100), P(x.min + 500, y.min + 100),
      P(x.min + 500, y.min + 800), P(x.min - 200, y.min + 800),
    ]);
    expect(() => WorkFloorPolygonService.save(
      board, f, face, [beyond]), throwsArgumentError);
    expect(() => WorkFloorPolygonService.save(
      board, f, face, [a, a]), throwsArgumentError);
    expect(board.floorZones, isEmpty);
  });

  test('concave clipping excludes cut-out of L shaped room', () {
    final f = room();
    final face = RoomFace(
      key: f.roomMetas.single.faceKey,
      nodeIds: const [],
      edges: const [],
      signedAreaMm2: 14000000,
      innerPolygon: const [
        P(0, 0), P(5000, 0), P(5000, 2000),
        P(2000, 2000), P(2000, 4000), P(0, 4000),
      ],
    );
    final forbidden = zone(f, 'notch', const [
      P(1000, 1000), P(3000, 1000),
      P(3000, 3000), P(1000, 3000),
    ]);
    expect(WorkFloorPolygonService.intersectionArea(
        face.innerPolygon, forbidden.polygon), closeTo(3, .001));
    expect(() => WorkFloorPolygonService.validate(
      face, f, [forbidden]), throwsArgumentError);
    final valid = zone(f, 'lower', const [
      P(100, 100), P(3900, 100), P(3900, 1900), P(100, 1900),
    ]);
    WorkFloorPolygonService.validate(face, f, [valid]);
    final values = WorkFloorPolygonService.areas(f, face, [valid]);
    expect(values.tileM2, closeTo(6.84, .001));
    expect(values.tileM2 + values.laminateM2, closeTo(14, .001));
  });

  test('floor generator takes polygon quantities and preserves work gates', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final project = MeasureProject(id: 'p', name: 'Квартира', floors: [f]);
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final area = zone(f, 'tile1', [
      P(x.min + 100, y.min + 100), P(x.min + 1800, y.min + 100),
      P(x.min + 1800, y.min + 1000), P(x.min + 100, y.min + 1000),
    ]);
    WorkFloorPolygonService.save(project.workBoard, f, face, [area]);
    final plan = WorkGenerationService.preview(
      project, begin: DateTime(2026, 11, 2));
    final tileTask = plan.tasks.firstWhere((t) =>
      t.operationCode == 'floor_tile');
    final laminateTask = plan.tasks.firstWhere((t) =>
      t.operationCode == 'floor_laminate');
    expect(tileTask.quantity, closeTo(1.53, .001));
    expect(tileTask.quantity + laminateTask.quantity,
      closeTo(face.areaM2, .01));
    expect(WorkGenerationService.apply(project.workBoard, plan), isNull);
    // Already recorded work must not be overwritten by new zone selection.
    laminateTask.done = laminateTask.quantity;
    laminateTask.accepted = laminateTask.quantity;
    final newZone = zone(f, 'tile2', [
      P(x.max - 1200, y.max - 1200), P(x.max - 100, y.max - 1200),
      P(x.max - 100, y.max - 100), P(x.max - 1200, y.max - 100),
    ]);
    final qtyBefore = laminateTask.quantity;
    WorkFloorPolygonService.save(project.workBoard, f, face, [area, newZone]);
    WorkFloorSurfaceService.refreshUnstarted(project.workBoard, f, face);
    expect(laminateTask.quantity, qtyBefore);
    expect(laminateTask.accepted, qtyBefore);
    expect(laminateTask.needsQuantityReview, true);
    final successor = WorkTask(
      id: 'successor', title: 'Принять объект',
      start: DateTime(2026, 12, 1), finish: DateTime(2026, 12, 2),
      quantity: 1, unit: 'шт', hours: 4,
      predecessorId: laminateTask.id,
    );
    project.workBoard.tasks.add(successor);
    expect(WorkStatusService.canStart(project.workBoard, successor), false);
  });

  test('snap and move one vertex while keeping saved and sibling zones untouched', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final a = zone(f, 'a', [
      P(x.min + 100, y.min + 100), P(x.min + 800, y.min + 100),
      P(x.min + 800, y.min + 800), P(x.min + 100, y.min + 800),
    ]);
    final b = zone(f, 'b', [
      P(x.max - 850, y.max - 850), P(x.max - 150, y.max - 850),
      P(x.max - 150, y.max - 150), P(x.max - 850, y.max - 150),
    ]);
    final board = WorkBoard();
    WorkFloorPolygonService.save(board, f, face, [a, b]);
    final before = WorkFloorPolygonService.areas(f, face, [a, b]);
    final moved = WorkFloorPolygonService.movedVertex(
      face, f, [a, b], zoneId: a.id, vertexIndex: 1,
      position: P(x.min + 965, y.min + 110), snapMm: 50);
    final snappedX = ((x.min + 965) / 50).roundToDouble() * 50;
    final snappedY = ((y.min + 110) / 50).roundToDouble() * 50;
    expect(moved.first.polygon[1], P(snappedX, snappedY));
    expect(moved.first.id, 'a');
    expect(moved.last.polygon, b.polygon);
    expect(a.polygon[1], P(x.min + 800, y.min + 100));
    expect(board.floorZones.first.polygon[1], a.polygon[1]);
    final after = WorkFloorPolygonService.areas(f, face, moved);
    expect(after.tileM2, greaterThan(before.tileM2));
    expect(after.tileM2 + after.laminateM2, closeTo(face.areaM2, .001));
    WorkFloorPolygonService.save(board, f, face, moved);
    final restored = WorkBoard.fromJson(board.toJson());
    expect(restored.floorZones.first.polygon[1], moved.first.polygon[1]);
  });

  test('drag validation rejects crossings, room escape, other zones and bad indices', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final a = zone(f, 'a', [
      P(x.min + 100, y.min + 100), P(x.min + 900, y.min + 100),
      P(x.min + 900, y.min + 900), P(x.min + 100, y.min + 900),
    ]);
    final b = zone(f, 'b', [
      P(x.min + 1300, y.min + 200), P(x.min + 2000, y.min + 200),
      P(x.min + 2000, y.min + 900), P(x.min + 1300, y.min + 900),
    ]);
    final current = [a, b];
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'a', vertexIndex: 0,
      position: P(x.min - 100, y.min + 100)), throwsArgumentError);
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'a', vertexIndex: 1,
      position: P(x.min + 1700, y.min + 100)), throwsArgumentError);
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'a', vertexIndex: 1,
      position: P(x.min + 500, y.min + 1300)), throwsArgumentError);
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'a', vertexIndex: 9,
      position: P(x.min + 700, y.min + 100)), throwsRangeError);
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'gone', vertexIndex: 0,
      position: P(500, 500)), throwsArgumentError);
    expect(() => WorkFloorPolygonService.movedVertex(
      face, f, current, zoneId: 'a', vertexIndex: 0,
      position: P(100, 100), snapMm: 0), throwsArgumentError);
    expect(a.polygon.first, P(x.min + 100, y.min + 100));
  });

  test('finish material can change without losing the polygon geometry', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final a = zone(f, 'first', [
      P(x.min + 100, y.min + 100), P(x.min + 800, y.min + 100),
      P(x.min + 800, y.min + 800), P(x.min + 100, y.min + 800),
    ]);
    final updated = WorkFloorPolygonService.changedMaterial(
      face, f, [a], zoneId: 'first', material: 'laminate');
    expect(updated.single.material, 'laminate');
    expect(updated.single.polygon, a.polygon);
    expect(updated.single.id, a.id);
    expect(a.material, 'tile');
    expect(WorkFloorPolygonService.areas(f, face, updated).tileM2, 0);
    expect(() => WorkFloorPolygonService.changedMaterial(
      face, f, [a], zoneId: 'first', material: 'unknown'),
      throwsArgumentError);
  });

  test('legacy straight split replaces polygon layout and vice versa', () {
    final f = room(), face = GeometryService.roomFaces(f).single;
    final b = WorkBoard();
    final x = WorkFloorSurfaceService.bounds(face, 'x');
    final y = WorkFloorSurfaceService.bounds(face, 'y');
    final zone1 = zone(f, 'tile', [
      P(x.min + 100, y.min + 100), P(x.min + 900, y.min + 100),
      P(x.min + 900, y.min + 800), P(x.min + 100, y.min + 800),
    ]);
    WorkFloorPolygonService.save(b, f, face, [zone1]);
    expect(b.floorZones, hasLength(1));
    WorkFloorSurfaceService.save(b, f, face, WorkFloorFinishSplit(
      floorId: f.id, roomId: f.roomMetas.single.id,
      axis: 'y', cutMm: (y.min + y.max) / 2,
      tileBeforeCut: true,
    ));
    expect(b.floorZones, isEmpty);
    expect(b.floorFinishes, hasLength(1));
    WorkFloorPolygonService.save(b, f, face, [zone1]);
    expect(b.floorFinishes, isEmpty);
    expect(WorkFloorSurfaceService.areas(b, f, face).tileM2,
      closeTo(.56, .001));
  });
}
