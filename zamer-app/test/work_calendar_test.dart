import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/models/work_calendar.dart';
import 'package:zamer_app/services/work_schedule_service.dart';

WorkTask example(String id, DateTime from, DateTime to,
    {String? prior, int lag = 0}) => WorkTask(
  id: id, title: id, start: from, finish: to,
  quantity: 10, unit: 'м²', hours: 12,
  predecessorId: prior, lagDays: lag,
);

void main() {
  test('old work boards keep 7/7 calendar and zero technological lag', () {
    final board = WorkBoard.fromJson({
      'tasks': [
        example('old', DateTime(2026, 11, 6), DateTime(2026, 11, 8)).toJson()
          ..remove('lagDays'),
      ],
    });
    expect(board.calendar.weekdaysOnly, false);
    expect(board.tasks.single.lagDays, 0);
    expect(board.calendar.isWorkday(DateTime(2026, 11, 7)), true);
  });

  test('five-day calendar skips weekends and manually blocked days', () {
    final calendar = WorkCalendar(weekdaysOnly: true);
    expect(calendar.isWorkday(DateTime(2026, 11, 7)), false);
    expect(calendar.firstDayAfter(DateTime(2026, 11, 6), 0),
        DateTime(2026, 11, 9));
    calendar.daysOff.add('2026-11-09');
    expect(calendar.firstDayAfter(DateTime(2026, 11, 6), 0),
        DateTime(2026, 11, 10));
    expect(calendar.workingDaysInclusive(
        DateTime(2026, 11, 6), DateTime(2026, 11, 11)), 3);
    expect(calendar.finishForDuration(DateTime(2026, 11, 10), 3),
        DateTime(2026, 11, 12));
    expect(WorkCalendar.fromJson(calendar.toJson()).daysOff,
        contains('2026-11-09'));
  });

  test('technological lag always counts calendar days', () {
    final calendar = WorkCalendar(weekdaysOnly: true);
    // Finished Thursday Nov 5, the successor can start Fri with no lag.
    expect(calendar.firstDayAfter(DateTime(2026, 11, 5), 0),
        DateTime(2026, 11, 6));
    // Two waiting days are Friday+Saturday, so it starts Monday.
    expect(calendar.firstDayAfter(DateTime(2026, 11, 5), 2),
        DateTime(2026, 11, 9));
  });

  test('cascading schedule keeps two working days after weekend', () {
    final parent = example('plaster', DateTime(2026, 11, 5),
        DateTime(2026, 11, 6));
    final child = example('tiles', DateTime(2026, 11, 9),
        DateTime(2026, 11, 10), prior: 'plaster');
    final board = WorkBoard(tasks: [parent, child],
      calendar: WorkCalendar(weekdaysOnly: true));
    final proposal = WorkSchedulePlanner.preview(
      board: board, taskId: parent.id,
      start: DateTime(2026, 11, 5), finish: DateTime(2026, 11, 9));
    expect(proposal.error, isNull);
    expect(proposal.changes.length, 2);
    expect(proposal.changes.last.start, DateTime(2026, 11, 10));
    expect(proposal.changes.last.finish, DateTime(2026, 11, 11));
    expect(child.start, DateTime(2026, 11, 9));
    expect(WorkSchedulePlanner.apply(board, proposal), isNull);
    expect(child.start, DateTime(2026, 11, 10));
    expect(child.baselineStart, DateTime(2026, 11, 9));
  });

  test('technical pause is considered for linked job', () {
    final parent = example('waterproofing', DateTime(2026, 11, 5),
        DateTime(2026, 11, 5));
    final child = example('tiling', DateTime(2026, 11, 6),
        DateTime(2026, 11, 6), prior: parent.id, lag: 2);
    final board = WorkBoard(tasks: [parent, child],
      calendar: WorkCalendar(weekdaysOnly: true));
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: parent.id,
      start: parent.start, finish: parent.finish);
    expect(preview.error, isNull);
    expect(preview.changes.single.taskId, child.id);
    expect(preview.changes.single.start, DateTime(2026, 11, 9));
    expect(WorkSchedulePlanner.apply(board, preview), isNull);
    expect(child.lagDays, 2);
    expect(child.start, DateTime(2026, 11, 9));
  });

  test('manual job with weekend dates is rejected in 5/2 mode', () {
    final board = WorkBoard(calendar: WorkCalendar(weekdaysOnly: true));
    expect(WorkScheduleService.validate(
      board: board, taskId: 'w',
      start: DateTime(2026, 11, 7), finish: DateTime(2026, 11, 8)),
      contains('рабочими'));
  });

  test('a changed calendar invalidates already confirmed preview', () {
    final parent = example('a', DateTime(2026, 11, 5),
        DateTime(2026, 11, 6));
    final child = example('b', DateTime(2026, 11, 9),
        DateTime(2026, 11, 10), prior: 'a');
    final board = WorkBoard(tasks: [parent, child],
        calendar: WorkCalendar(weekdaysOnly: true));
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: parent.id,
      start: parent.start, finish: DateTime(2026, 11, 9));
    expect(preview.error, isNull);
    board.calendar.daysOff.add('2026-11-10');
    expect(WorkSchedulePlanner.apply(board, preview), contains('Календарь'));
    expect(parent.finish, DateTime(2026, 11, 6));
    expect(child.start, DateTime(2026, 11, 9));
  });

  test('baseline progress excludes manually configured nonworking day', () {
    final task = example('job', DateTime(2026, 11, 6),
        DateTime(2026, 11, 10));
    final calendar = WorkCalendar(
      weekdaysOnly: true, daysOff: ['2026-11-09']);
    final board = WorkBoard(tasks: [task], calendar: calendar);
    expect(board.plannedProgress(DateTime(2026, 11, 10)),
        closeTo(.5, .0001));
    final restored = WorkBoard.fromJson(board.toJson());
    expect(restored.calendar.weekdaysOnly, true);
    expect(restored.calendar.daysOff, contains('2026-11-09'));
    expect(restored.plannedProgress(DateTime(2026, 11, 10)),
        closeTo(.5, .0001));
  });
}
