import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/models/work_calendar.dart';
import 'package:zamer_app/services/workload_service.dart';
import 'package:zamer_app/services/work_schedule_service.dart';

WorkTask job(String id, DateTime from, DateTime to,
    {String crew = 'Бригада А', double hours = 8}) => WorkTask(
  id: id,
  title: id,
  start: from,
  finish: to,
  quantity: 10,
  unit: 'м²',
  hours: hours,
  assignee: crew,
);

void main() {
  test('same crew tasks sum their day person-hours', () {
    final date = DateTime(2026, 11, 2);
    final board = WorkBoard(tasks: [
      job('a', date, date),
      job('b', date, date, crew: '  бРИГАДА   а '),
    ]);
    final report = WorkloadService.analyze(board);
    expect(report.days.length, 1);
    expect(report.days.single.plannedHours, 16);
    expect(report.days.single.capacity, 8);
    expect(report.days.single.overloadHours, 8);
    expect(report.overloadedDayCount, 1);
    expect(report.overlappingDayCount, 1);
  });

  test('different crews are never mixed', () {
    final date = DateTime(2026, 11, 2);
    final board = WorkBoard(tasks: [
      job('a', date, date, crew: 'Иван'),
      job('b', date, date, crew: 'Пётр'),
    ]);
    final report = WorkloadService.analyze(board);
    expect(report.days.length, 2);
    expect(report.overloadedDayCount, 0);
  });

  test('loading excludes weekends and explicitly closed days', () {
    final board = WorkBoard(
      calendar: WorkCalendar(weekdaysOnly: true,
        daysOff: ['2026-11-09']),
      tasks: [
        job('a', DateTime(2026, 11, 6), DateTime(2026, 11, 11),
          hours: 24),
      ],
    );
    final report = WorkloadService.analyze(board);
    expect(report.days.map((e) => WorkCalendar.key(e.day)), [
      '2026-11-06', '2026-11-10', '2026-11-11',
    ]);
    expect(report.days.every((e) => e.plannedHours == 8), true);
    expect(report.overloadedDayCount, 0);
  });

  test('custom crew daily capacity is persisted and respected', () {
    final day = DateTime(2026, 11, 2);
    final board = WorkBoard(
      tasks: [
        job('a', day, day),
        job('b', day, day),
      ],
      crewDailyHours: {'бригада а': 16},
    );
    expect(WorkloadService.analyze(board).overloadedDayCount, 0);
    final copy = WorkBoard.fromJson(board.toJson());
    expect(copy.crewDailyHours['бригада а'], 16);
    expect(WorkloadService.analyze(copy).days.single.capacity, 16);
  });

  test('proposed date change warns before schedule is applied', () {
    final one = job('a', DateTime(2026, 11, 2),
        DateTime(2026, 11, 2));
    final two = job('b', DateTime(2026, 11, 4),
        DateTime(2026, 11, 4));
    final board = WorkBoard(tasks: [one, two]);
    expect(WorkloadService.analyze(board).overloadedDayCount, 0);
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: 'b',
      start: DateTime(2026, 11, 2),
      finish: DateTime(2026, 11, 2),
    );
    expect(preview.error, isNull);
    final estimate = WorkloadService.analyze(
      board, proposedChanges: preview.changes);
    expect(estimate.overloadedDayCount, 1);
    expect(two.start, DateTime(2026, 11, 4));
  });

  test('unset executor is ignored and invalid dates are reported', () {
    final day = DateTime(2026, 11, 2);
    final board = WorkBoard(tasks: [
      job('empty', day, day, crew: ''),
      job('bad', DateTime(2026, 11, 5),
        DateTime(2026, 11, 1)),
    ]);
    final report = WorkloadService.analyze(board);
    expect(report.days, isEmpty);
    expect(report.skippedInvalidTasks, 1);
  });

  test('overlapping tasks below capacity are informational only', () {
    final day = DateTime(2026, 11, 2);
    final board = WorkBoard(tasks: [
      job('a', day, day, hours: 2),
      job('b', day, day, hours: 3),
    ]);
    final report = WorkloadService.analyze(board);
    expect(report.overloadedDayCount, 0);
    expect(report.overlappingDayCount, 1);
    expect(report.days.single.taskTitles.length, 2);
  });
}
