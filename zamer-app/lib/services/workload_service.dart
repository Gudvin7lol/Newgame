import '../models/work_board.dart';
import '../models/work_calendar.dart';
import 'work_schedule_service.dart';

/// Estimated person-hours for one executor/crew on one working day.
/// Tasks have no clock-time slots: conflicts mean daily overcapacity.
class WorkloadDay {
  WorkloadDay({
    required this.day,
    required this.crew,
    required this.crewKey,
    required this.capacity,
  });

  final DateTime day;
  final String crew, crewKey;
  final double capacity;
  final Map<String, String> taskTitles = <String, String>{};
  double plannedHours = 0;

  bool get overloaded => plannedHours > capacity + 0.0001;
  bool get simultaneousTasks => taskTitles.length > 1;
  double get overloadHours => overloaded ? plannedHours - capacity : 0;
}

class WorkloadReport {
  WorkloadReport(this.days, {this.skippedInvalidTasks = 0});

  final List<WorkloadDay> days;
  final int skippedInvalidTasks;

  List<WorkloadDay> get overloadedDays =>
      days.where((day) => day.overloaded).toList(growable: false);
  int get overloadedDayCount => overloadedDays.length;
  int get overlappingDayCount =>
      days.where((day) => day.simultaneousTasks).length;
  double get overloadPersonHours => overloadedDays.fold<double>(
      0, (sum, day) => sum + day.overloadHours);
}

/// Default daily capacity is 8 person-hours per named executor/crew.
/// A user may explicitly configure a different crew capacity. This tool
/// warns about load; it does not infer headcount or rearrange any tasks.
class WorkloadService {
  static const double defaultCapacity = 8;

  static String crewKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static double capacityFor(WorkBoard board, String name) {
    final configured = board.crewDailyHours[crewKey(name)];
    if (configured == null || !configured.isFinite || configured <= 0) {
      return defaultCapacity;
    }
    return configured;
  }

  static List<String> assignedCrews(WorkBoard board) {
    final names = <String, String>{};
    for (final task in board.tasks) {
      final normalized = crewKey(task.assignee);
      if (normalized.isEmpty) continue;
      names.putIfAbsent(normalized, () => task.assignee.trim());
    }
    return names.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static WorkloadReport analyze(
    WorkBoard board, {
    Iterable<WorkScheduleChange> proposedChanges = const [],
  }) {
    final adjustments = <String, WorkScheduleChange>{
      for (final change in proposedChanges) change.taskId: change,
    };
    final result = <String, WorkloadDay>{};
    var invalid = 0;

    for (final task in board.tasks) {
      final normalized = crewKey(task.assignee);
      if (normalized.isEmpty || task.hours <= 0 || !task.hours.isFinite) {
        continue;
      }
      final proposal = adjustments[task.id];
      final start = WorkCalendar.dateOnly(proposal?.start ?? task.start);
      final finish = WorkCalendar.dateOnly(proposal?.finish ?? task.finish);
      if (finish.isBefore(start)) {
        invalid++;
        continue;
      }
      final utcStart = DateTime.utc(start.year, start.month, start.day);
      final utcFinish = DateTime.utc(finish.year, finish.month, finish.day);
      // Guard against broken imports locking the UI for decades of dates.
      if (utcFinish.difference(utcStart).inDays > 3660) {
        invalid++;
        continue;
      }
      final workdays = board.calendar.workingDaysInclusive(start, finish);
      if (workdays == 0) {
        invalid++;
        continue;
      }
      final perDay = task.hours / workdays;
      final capacity = capacityFor(board, task.assignee);
      var cursor = start;
      while (!cursor.isAfter(finish)) {
        if (board.calendar.isWorkday(cursor)) {
          final key = '${normalized}|${WorkCalendar.key(cursor)}';
          final item = result.putIfAbsent(key, () => WorkloadDay(
            day: cursor,
            crew: task.assignee.trim(),
            crewKey: normalized,
            capacity: capacity,
          ));
          item.plannedHours += perDay;
          item.taskTitles[task.id] = task.title;
        }
        cursor = WorkCalendar.addDays(cursor, 1);
      }
    }

    final days = result.values.toList()
      ..sort((a, b) {
        final compare = a.day.compareTo(b.day);
        return compare != 0 ? compare : a.crewKey.compareTo(b.crewKey);
      });
    return WorkloadReport(days, skippedInvalidTasks: invalid);
  }
}
