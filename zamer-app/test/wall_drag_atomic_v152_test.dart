import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/orthogonal_wall_edit_service.dart';

FloorPlan roomWithDoorAndSocket() {
  return FloorPlan(id: 'room', name: 'Safe drag', nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ], walls: [
    PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b',
      openings: [
        WallOpening(id: 'door', type: OpeningType.door,
          offsetFromStartMm: 2200, widthMm: 900, heightMm: 2100),
      ]),
    PlanWall(id: 'right', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'bottom', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'left', startNodeId: 'd', endNodeId: 'a'),
  ], electricalPoints: [
    ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
      xMm: 4000, yMm: 1400, wallId: 'right', wallOffsetMm: 1400),
  ]);
}

void main() {
  test('valid wall movement can be fully rolled back, including attachments', () {
    final plan = roomWithDoorAndSocket();
    final original = FloorPlan.fromJson(plan.toJson());
    final before = plan.toJson().toString();
    final valid = OrthogonalWallEditService.move(
      plan, wallId: 'right', offsetMm: 300);
    expect(valid.isValid, isTrue, reason: valid.message);
    expect(plan.nodeById('b')!.xMm, 4300);
    expect(plan.wallById('top')!.openings.single.offsetFromStartMm,
        closeTo(2200, .001));
    expect(plan.electricalPoints.single.xMm, 4300);
    // This is the same restore used by the screen on cancelled/rejected drag.
    plan.restoreFrom(original);
    expect(plan.toJson().toString(), before);
  });

  test('a rejected wall move after a valid intermediate move is not committed', () {
    final floor = roomWithDoorAndSocket();
    final original = FloorPlan.fromJson(floor.toJson());
    final before = floor.toJson().toString();
    expect(OrthogonalWallEditService.move(
      floor, wallId: 'right', offsetMm: 300).isValid, isTrue);
    final rejected = OrthogonalWallEditService.move(
      floor, wallId: 'right', offsetMm: -4500);
    expect(rejected.isValid, isFalse);
    floor.restoreFrom(original);
    expect(floor.toJson().toString(), before);
  });

  test('UI preserves drag-start snapshot and cancels invalid wall releases', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final start = source.indexOf('void _wallDragStart(');
    final end = source.indexOf('Future<void> _tapCanvas(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final section = source.substring(start, end);
    expect(section, contains('_dragWallStartFloor = FloorPlan.fromJson('));
    expect(section, contains('if (details.pointerCount != 1)'));
    expect(section, contains('_wallDragCancel();'));
    expect(section, contains('floor.restoreFrom(before)'));
    expect(section, contains('if (rejected != null)'));
    expect(section, contains('Перемещение стены отменено'));
    expect(section, contains("if (changed) await _changed()"));
  });

  test('switching tools aborts both uncommitted node and wall gestures', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final change = source.indexOf('if (oldWidget.planTool != widget.planTool)');
    final reset = source.indexOf('_materialPickMode = widget.planTool', change);
    expect(change, greaterThanOrEqualTo(0));
    expect(reset, greaterThan(change));
    final fragment = source.substring(change, reset);
    expect(fragment, contains('_nodeDragStartFloor ?? _dragWallStartFloor'));
    expect(fragment, contains('floor.restoreFrom(unfinishedDrag)'));
    expect(fragment, contains('_dragWallStartFloor = null'));
  });
}
