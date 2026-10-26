import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/work_schedule_service.dart';

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
  test('rescheduling retains original plan baseline through JSON', () {
    final task = WorkTask(
      id: 'original',
      title: 'Отделка',
      start: DateTime(2026, 10, 26),
      finish: DateTime(2026, 10, 28),
      quantity: 40,
      unit: 'м²',
      hours: 16,
    );
    final board = WorkBoard(tasks: [task]);
    final baselineAt = board.plannedProgress(DateTime(2026, 10, 27));
    task.start = DateTime(2026, 11, 1);
    task.finish = DateTime(2026, 11, 4);
    final loaded = WorkBoard.fromJson(board.toJson());
    expect(loaded.plannedProgress(DateTime(2026, 10, 27)), baselineAt);
    expect(loaded.tasks.single.finish, DateTime(2026, 11, 4));
    expect(loaded.tasks.single.baselineFinish, DateTime(2026, 10, 28));
  });

  test('dependency rules reject overlaps and cycles', () {
    WorkTask make(String id, int start, int finish, {String? prior}) => WorkTask(
      id: id, title: id, start: DateTime(2026, 10, start),
      finish: DateTime(2026, 10, finish), quantity: 1, unit: 'шт',
      hours: 4, predecessorId: prior,
    );
    final board = WorkBoard(tasks: [
      make('a', 20, 21),
      make('b', 22, 24, prior: 'a'),
      make('c', 25, 26, prior: 'b'),
    ]);
    expect(WorkScheduleService.validate(
      board: board, taskId: 'a', start: DateTime(2026, 10, 20),
      finish: DateTime(2026, 10, 21), predecessorId: 'c',
    ), contains('цикл'));
    expect(WorkScheduleService.validate(
      board: board, taskId: 'b', start: DateTime(2026, 10, 21),
      finish: DateTime(2026, 10, 24), predecessorId: 'a',
    ), contains('раньше'));
    expect(WorkScheduleService.validate(
      board: board, taskId: 'b', start: DateTime(2026, 10, 22),
      finish: DateTime(2026, 10, 25), predecessorId: 'a',
    ), contains('зависимую'));
    expect(WorkScheduleService.validate(
      board: board, taskId: 'b', start: DateTime(2026, 10, 22),
      finish: DateTime(2026, 10, 24), predecessorId: 'a',
    ), isNull);
  });

}
