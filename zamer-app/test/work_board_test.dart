import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';

void main() {
  test('legacy project JSON remains compatible without a workBoard field', () {
    final project = MeasureProject(id: 'p1', name: 'Object');
    final json = project.toJson()..remove('workBoard');
    final loaded = MeasureProject.fromJson(json);
    expect(loaded.workBoard.tasks, isEmpty);
    expect(loaded.workBoard.issues, isEmpty);
  });

  test('tasks, issues and journal survive project JSON roundtrip', () {
    final start = DateTime(2026, 10, 26);
    final project = MeasureProject(id: 'p1', name: 'Object');
    project.workBoard.tasks.add(WorkTask(
      id: 'w1',
      title: 'Штукатурка',
      floorId: 'f1',
      roomId: 'r1',
      roomName: 'Гостиная',
      start: start,
      finish: start.add(const Duration(days: 3)),
      quantity: 46,
      done: 28,
      accepted: 12,
      unit: 'м²',
      hours: 64,
    ));
    project.workBoard.issues.add(WorkIssue(
      id: 'i1', title: 'Трещина',
      taskId: 'w1', roomId: 'r1',
      createdAt: start,
    ));
    project.workBoard.log('Добавлена работа', taskId: 'w1');
    final loaded = MeasureProject.fromJson(project.toJson());
    expect(loaded.workBoard.tasks.single.roomId, 'r1');
    expect(loaded.workBoard.tasks.single.done, 28);
    expect(loaded.workBoard.tasks.single.accepted, 12);
    expect(loaded.workBoard.issues.single.open, isTrue);
    expect(loaded.workBoard.events.single.taskId, 'w1');
    expect(loaded.workBoard.actualProgress, closeTo(28 / 46, 0.0001));
    expect(loaded.workBoard.acceptedProgress, closeTo(12 / 46, 0.0001));
    expect(loaded.workBoard.plannedProgress(DateTime(2026, 10, 26)), lessThan(.5));
    expect(loaded.workBoard.plannedProgress(DateTime(2026, 11, 5)), 1);
  });

  test('an empty schedule is well defined', () {
    final board = WorkBoard();
    expect(board.actualProgress, 0);
    expect(board.plannedProgress(DateTime.now()), 0);
  });
}
