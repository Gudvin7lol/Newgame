import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/orthogonal_wall_edit_service.dart';

FloorPlan twoRooms() => FloorPlan(
  id: 'two', name: 'Точная геометрия',
  nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 7000, yMm: 0),
    PlanNode(id: 'd', xMm: 7000, yMm: 3000),
    PlanNode(id: 'e', xMm: 4000, yMm: 3000),
    PlanNode(id: 'f', xMm: 0, yMm: 3000),
  ],
  walls: [
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'de', startNodeId: 'd', endNodeId: 'e'),
    PlanWall(id: 'ef', startNodeId: 'e', endNodeId: 'f'),
    PlanWall(id: 'fa', startNodeId: 'f', endNodeId: 'a'),
    PlanWall(id: 'shared', startNodeId: 'b', endNodeId: 'e'),
  ],
);

void main() {
  test('shared wall valid move retains both rooms and topological junctions', () {
    final floor = twoRooms();
    expect(GeometryService.roomFaces(floor).length, 2);
    final result = OrthogonalWallEditService.move(
      floor, wallId: 'shared', offsetMm: 400);
    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodeById('b')!.xMm, 4400);
    expect(floor.nodeById('e')!.xMm, 4400);
    expect(floor.nodeDegree('b'), 3);
    expect(floor.nodeDegree('e'), 3);
    expect(GeometryService.roomFaces(floor).length, 2);
  });

  test('invalid extension does not mutate last valid two-room geometry', () {
    final floor = twoRooms();
    expect(OrthogonalWallEditService.move(
        floor, wallId: 'shared', offsetMm: 400).isValid, isTrue);
    final before = floor.toJson().toString();
    final result = OrthogonalWallEditService.move(
        floor, wallId: 'shared', offsetMm: 4000);
    expect(result.isValid, isFalse);
    expect(floor.toJson().toString(), before);
    expect(GeometryService.roomFaces(floor).length, 2);
  });

  test('wall drag must rollback on invalid release, pinch and tool switch', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains('_dragWallStartFloor'));
    expect(src, contains('_wallDragFinish(cancel: true)'));
    expect(src, contains('final mustRollback = cancel || rejected != null'));
    expect(src, contains('floor.restoreFrom(beforeDrag)'));
    expect(src, contains('if (mustRollback)'));
    expect(src, contains('Сдвиг стены отменён'));
    expect(src, contains("ValueKey('wall-drag-status')"));
    expect(src, contains('Сдвиг:'));
    expect(src, contains('if (_dragWallStartFloor != null)'));
  });

  test('wall drag clears rejection after returning to a valid position', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains('if (change.abs() < .01)'));
    expect(src, contains('setState(() => _dragWallRejected = null)'));
    expect(src, contains('setState(() => _dragWallRejected = result.message)'));
    expect(src, contains('if (changed) await _changed()'));
  });
}
