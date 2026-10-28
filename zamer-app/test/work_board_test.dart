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


  test('automatic cascade shifts a chain and preserves initial dates', () {
    WorkTask task(String id, int startDay, int finishDay, {String? prior}) =>
        WorkTask(
          id: id, title: id, start: DateTime(2026, 11, startDay),
          finish: DateTime(2026, 11, finishDay), predecessorId: prior,
          quantity: 10, unit: 'м²', hours: 16,
        );
    final a = task('a', 1, 2);
    final b = task('b', 3, 5, prior: 'a');
    final c = task('c', 6, 7, prior: 'b');
    final unrelated = task('unrelated', 2, 15);
    final board = WorkBoard(tasks: [a, b, c, unrelated]);
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: 'a',
      start: DateTime(2026, 11, 1), finish: DateTime(2026, 11, 5),
    );
    expect(preview.error, isNull);
    expect(preview.changes.map((e) => e.taskId), ['a', 'b', 'c']);
    expect(preview.shiftedSuccessors, 2);
    expect(preview.changes[1].start, DateTime(2026, 11, 6));
    expect(preview.changes[1].finish, DateTime(2026, 11, 8));
    expect(preview.changes[2].start, DateTime(2026, 11, 9));
    // The preview must never mutate the project.
    expect(b.start, DateTime(2026, 11, 3));
    expect(WorkSchedulePlanner.apply(board, preview), isNull);
    expect(a.finish, DateTime(2026, 11, 5));
    expect(b.finish, DateTime(2026, 11, 8));
    expect(c.finish, DateTime(2026, 11, 10));
    expect(unrelated.start, DateTime(2026, 11, 2));
    expect(b.baselineStart, DateTime(2026, 11, 3));
    final restored = WorkBoard.fromJson(board.toJson());
    expect(restored.tasks[1].finish, DateTime(2026, 11, 8));
    expect(restored.tasks[1].baselineFinish, DateTime(2026, 11, 5));
  });

  test('branching descendants shift only when needed', () {
    WorkTask task(String id, int from, int through, {String? prior}) =>
        WorkTask(
          id: id, title: id, start: DateTime(2026, 11, from),
          finish: DateTime(2026, 11, through), predecessorId: prior,
          quantity: 1, unit: 'шт', hours: 8,
        );
    final board = WorkBoard(tasks: [
      task('root', 1, 2),
      task('soon', 3, 4, prior: 'root'),
      task('later', 15, 16, prior: 'root'),
      task('deep', 5, 6, prior: 'soon'),
    ]);
    final change = WorkSchedulePlanner.preview(
      board: board, taskId: 'root',
      start: DateTime(2026, 11, 1), finish: DateTime(2026, 11, 6),
    );
    expect(change.error, isNull);
    expect(change.changes.map((e) => e.taskId), ['root', 'soon', 'deep']);
    expect(WorkSchedulePlanner.apply(board, change), isNull);
    expect(board.tasks[2].start, DateTime(2026, 11, 15));
    expect(board.tasks[3].start, DateTime(2026, 11, 9));
  });

  test('started successor blocks automatic rescheduling without mutation', () {
    final a = WorkTask(
      id: 'a', title: 'Основание', start: DateTime(2026, 11, 1),
      finish: DateTime(2026, 11, 2), quantity: 1, unit: 'шт', hours: 8);
    final b = WorkTask(
      id: 'b', title: 'Плитка', start: DateTime(2026, 11, 3),
      finish: DateTime(2026, 11, 5), predecessorId: 'a',
      quantity: 10, done: 2, unit: 'м²', hours: 16);
    final board = WorkBoard(tasks: [a, b]);
    final plan = WorkSchedulePlanner.preview(
      board: board, taskId: 'a',
      start: a.start, finish: DateTime(2026, 11, 4));
    expect(plan.error, contains('уже начатую'));
    expect(a.finish, DateTime(2026, 11, 2));
    expect(b.start, DateTime(2026, 11, 3));
  });

  test('cyclic links and stale proposals are never applied', () {
    final a = WorkTask(
      id: 'a', title: 'a', start: DateTime(2026, 11, 1),
      finish: DateTime(2026, 11, 2), quantity: 1, unit: 'шт', hours: 8);
    final b = WorkTask(
      id: 'b', title: 'b', start: DateTime(2026, 11, 3),
      finish: DateTime(2026, 11, 4), predecessorId: 'a',
      quantity: 1, unit: 'шт', hours: 8);
    final board = WorkBoard(tasks: [a, b]);
    final cyclic = WorkSchedulePlanner.preview(
      board: board, taskId: 'a', start: a.start, finish: a.finish,
      predecessorId: 'b');
    expect(cyclic.error, contains('цикл'));

    final original = WorkSchedulePlanner.preview(
      board: board, taskId: 'a', start: a.start,
      finish: DateTime(2026, 11, 4));
    expect(original.error, isNull);
    board.tasks.add(WorkTask(
      id: 'new', title: 'new', start: DateTime(2026, 11, 5),
      finish: DateTime(2026, 11, 6), predecessorId: 'b',
      quantity: 1, unit: 'шт', hours: 8));
    expect(WorkSchedulePlanner.apply(board, original), contains('изменился'));
    expect(a.finish, DateTime(2026, 11, 2));
    expect(b.start, DateTime(2026, 11, 3));
  });

  test('earlier completion never pulls successors backwards', () {
    final a = WorkTask(
      id: 'a', title: 'a', start: DateTime(2026, 11, 1),
      finish: DateTime(2026, 11, 4), quantity: 1, unit: 'шт', hours: 8);
    final b = WorkTask(
      id: 'b', title: 'b', start: DateTime(2026, 11, 7),
      finish: DateTime(2026, 11, 9), predecessorId: 'a',
      quantity: 1, unit: 'шт', hours: 8);
    final board = WorkBoard(tasks: [a, b]);
    final plan = WorkSchedulePlanner.preview(
      board: board, taskId: 'a',
      start: a.start, finish: DateTime(2026, 11, 2));
    expect(plan.error, isNull);
    expect(plan.changes.map((e) => e.taskId), ['a']);
    expect(WorkSchedulePlanner.apply(board, plan), isNull);
    expect(b.start, DateTime(2026, 11, 7));
  });


  test('prerequisite may be removed while preserving task baseline', () {
    final first = WorkTask(
      id: 'first', title: 'Черновые', start: DateTime(2026, 11, 1),
      finish: DateTime(2026, 11, 2), quantity: 1, unit: 'шт', hours: 8);
    final second = WorkTask(
      id: 'second', title: 'Отделка', start: DateTime(2026, 11, 3),
      finish: DateTime(2026, 11, 4), predecessorId: 'first',
      quantity: 1, unit: 'шт', hours: 8);
    final board = WorkBoard(tasks: [first, second]);
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: 'second',
      start: second.start, finish: second.finish, predecessorId: null);
    expect(preview.isValid, isTrue);
    expect(preview.changes.length, 1);
    expect(WorkSchedulePlanner.apply(board, preview), isNull);
    expect(second.predecessorId, isNull);
    expect(second.baselineFinish, DateTime(2026, 11, 4));
  });

}
