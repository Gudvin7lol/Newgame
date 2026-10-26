import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/work_generation_service.dart';
import 'package:zamer_app/services/work_status_service.dart';

FloorPlan rectangle(String id) {
  final floor = FloorPlan(
    id: id, name: 'Этаж ' + id,
    nodes: [
      PlanNode(id: 'n1', xMm: 0, yMm: 0),
      PlanNode(id: 'n2', xMm: 4000, yMm: 0),
      PlanNode(id: 'n3', xMm: 4000, yMm: 3000),
      PlanNode(id: 'n4', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'n1', endNodeId: 'n2'),
      PlanWall(id: 'w2', startNodeId: 'n2', endNodeId: 'n3'),
      PlanWall(id: 'w3', startNodeId: 'n3', endNodeId: 'n4'),
      PlanWall(id: 'w4', startNodeId: 'n4', endNodeId: 'n1'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  test('model-based generation uses actual room geometry', () {
    final floor = rectangle('f1');
    expect(GeometryService.roomFaces(floor).length, 1);
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor]);
    final plan = WorkGenerationService.preview(
      project, begin: DateTime(2026, 10, 26));
    expect(plan.roomsProcessed, 1);
    expect(plan.tasks.length, greaterThan(8));
    expect(project.workBoard.tasks, isEmpty);
    final floorTask = plan.tasks.firstWhere(
      (task) => task.operationCode == 'floor_laminate');
    expect(floorTask.quantity, closeTo(12, .01));
    expect(floorTask.unit, 'м²');
    expect(floorTask.roomId, floor.roomMetas.first.id);
    expect(floorTask.floorId, 'f1');
    final wall = plan.tasks.firstWhere(
      (task) => task.operationCode == 'wall_plaster');
    expect(wall.quantity, closeTo(37.8, .1));
    expect(wall.requiredPredecessorIds, isNotEmpty);
    expect(wall.predecessorId, isNotNull);
  });

  test('generator never duplicates or overwrites accepted work', () {
    final floor = rectangle('f2');
    final project = MeasureProject(id: 'p', name: 'Квартира', floors: [floor]);
    final preview = WorkGenerationService.preview(project);
    expect(WorkGenerationService.apply(project.workBoard, preview), isNull);
    final original = project.workBoard.tasks.first;
    original.done = original.quantity;
    original.accepted = original.quantity;
    final repeated = WorkGenerationService.preview(project);
    expect(repeated.tasks, isEmpty);
    expect(repeated.skippedExisting, preview.tasks.length);
    expect(original.accepted, original.quantity);
    expect(project.workBoard.tasks.length, preview.tasks.length);
    expect(WorkGenerationService.apply(project.workBoard, preview),
      contains('изменился'));
  });

  test('required predecessor must be accepted before task can start', () {
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [rectangle('f3')]);
    final plan = WorkGenerationService.preview(project);
    expect(WorkGenerationService.apply(project.workBoard, plan), isNull);
    final primer = project.workBoard.tasks.firstWhere(
      (t) => t.operationCode == 'wall_primer');
    final plaster = project.workBoard.tasks.firstWhere(
      (t) => t.operationCode == 'wall_plaster');
    expect(WorkStatusService.canStart(project.workBoard, plaster), false);
    expect(WorkStatusService.startBlocker(project.workBoard, plaster),
      contains('Сначала'));
    for (final id in plaster.requiredPredecessorIds) {
      final prior = project.workBoard.tasks.firstWhere((t) => t.id == id);
      prior.done = prior.quantity;
      prior.accepted = prior.quantity;
    }
    expect(WorkStatusService.canStart(project.workBoard, plaster), true);
    expect(WorkStatusService.canStart(project.workBoard, primer), true);
  });

  test('optional operations require quantity review and remain selected', () {
    final floor = rectangle('f4');
    final project = MeasureProject(id: 'p', name: 'Ремонт', floors: [floor]);
    final base = WorkGenerationService.preview(project);
    final full = WorkGenerationService.preview(
      project, includeOptional: true);
    expect(full.tasks.length, greaterThan(base.tasks.length));
    expect(full.reviewCount, greaterThan(0));
    expect(full.tasks.where((t) => t.operationCode == 'wall_wallpaper'), isEmpty);
    expect(full.tasks.where((t) => t.operationCode == 'ceiling_stretch'), isEmpty);
    final demo = full.tasks.firstWhere((t) => t.operationCode == 'demolition');
    expect(demo.needsQuantityReview, true);
    expect(WorkStatusService.canStart(project.workBoard, demo), false);
  });

  test('room filtering and floor ID survive serialization', () {
    final a = rectangle('a');
    final b = rectangle('b');
    final project = MeasureProject(id: 'x', name: 'Два этажа', floors: [a, b]);
    final targetRoomId = b.roomMetas.single.id;
    final preview = WorkGenerationService.preview(
      project, roomIds: {targetRoomId});
    expect(preview.roomsProcessed, 1);
    expect(preview.tasks.every((t) =>
      t.roomId == targetRoomId && t.floorId == 'b'), true);
    expect(WorkGenerationService.apply(project.workBoard, preview), isNull);
    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.workBoard.tasks.first.roomId, targetRoomId);
    expect(restored.workBoard.tasks.first.generatedKey, isNotNull);
    expect(restored.workBoard.tasks.first.operationCode, isNotNull);
  });

  test('open defects prevent acceptance, but not recording work', () {
    final project = MeasureProject(id: 'x', name: 'Квартира', floors: [
      rectangle('d')]);
    final board = project.workBoard;
    final plan = WorkGenerationService.preview(project);
    WorkGenerationService.apply(board, plan);
    final task = board.tasks.first;
    task.done = task.quantity;
    board.issues.add(WorkIssue(
      id: 'issue', title: 'Переделать',
      createdAt: DateTime(2026, 10, 26), taskId: task.id));
    expect(WorkStatusService.state(board, task), WorkState.defect);
    expect(WorkStatusService.canAccept(board, task), false);
    board.issues.first.closedAt = DateTime(2026, 10, 27);
    expect(WorkStatusService.canAccept(board, task), true);
  });
  test('rescheduling one prerequisite cascades through mandatory edges', () {
    final project = MeasureProject(
      id: 'deps', name: 'Зависимости', floors: [rectangle('deps')]);
    final generated = WorkGenerationService.preview(
      project, begin: DateTime(2026, 11, 2));
    WorkGenerationService.apply(project.workBoard, generated);
    final board = project.workBoard;
    final cleaning = board.tasks.firstWhere(
      (task) => task.operationCode == 'cleaning');
    final paint = board.tasks.firstWhere(
      (task) => task.operationCode == 'wall_paint');
    expect(cleaning.requiredPredecessorIds, contains(paint.id));
    // Final cleaning is blocked until all mandatory stages are accepted.
    expect(WorkStatusService.canStart(board, cleaning), false);
  });

}
