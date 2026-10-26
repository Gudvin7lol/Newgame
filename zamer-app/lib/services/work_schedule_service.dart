import '../models/work_board.dart';

/// Guards manual schedule edits. The original baseline dates live on WorkTask
/// and are never modified by this service.
class WorkScheduleService {
  static String? validate({
    required WorkBoard board,
    required String taskId,
    required DateTime start,
    required DateTime finish,
    String? predecessorId,
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final through = DateTime(finish.year, finish.month, finish.day);
    if (through.isBefore(from)) return 'Дата окончания раньше начала.';
    final predecessor = predecessorId == null
        ? null
        : board.tasks.where((t) => t.id == predecessorId).firstOrNull;
    if (predecessorId != null && predecessor == null) {
      return 'Предыдущая работа не найдена.';
    }
    if (predecessorId == taskId) {
      return 'Работа не может зависеть от самой себя.';
    }

    // Walk the predecessor chain to exclude a task dependency cycle.
    var current = predecessor;
    final visited = <String>{};
    while (current != null) {
      if (current.id == taskId || !visited.add(current.id)) {
        return 'Зависимости образуют замкнутый цикл.';
      }
      final priorId = current.predecessorId;
      current = priorId == null
          ? null
          : board.tasks.where((t) => t.id == priorId).firstOrNull;
    }

    if (predecessor != null &&
        !from.isAfter(DateTime(predecessor.finish.year,
            predecessor.finish.month, predecessor.finish.day))) {
      return 'Начало раньше завершения предыдущей работы.';
    }

    final nextTasks = board.tasks.where((t) => t.predecessorId == taskId);
    for (final next in nextTasks) {
      final nextStart = DateTime(next.start.year, next.start.month, next.start.day);
      if (!nextStart.isAfter(through)) {
        return 'Сначала перенесите зависимую работу «${next.title}».';
      }
    }
    return null;
  }

  static List<WorkTask> successors(WorkBoard board, String taskId) =>
      board.tasks.where((t) => t.predecessorId == taskId).toList();
}


/// One proposed task date/dependency change. The planning pass never mutates
/// WorkBoard; it returns a complete preview first.
class WorkScheduleChange {
  const WorkScheduleChange({
    required this.taskId,
    required this.title,
    required this.oldStart,
    required this.oldFinish,
    required this.start,
    required this.finish,
    required this.oldPredecessorId,
    required this.predecessorId,
  });

  final String taskId;
  final String title;
  final DateTime oldStart, oldFinish, start, finish;
  final String? oldPredecessorId, predecessorId;
  bool get moved => oldStart != start || oldFinish != finish;
}

class WorkScheduleProposal {
  const WorkScheduleProposal({
    required this.changes,
    required this.previousCompletion,
    required this.projectedCompletion,
    this.error,
  });

  final List<WorkScheduleChange> changes;
  final DateTime? previousCompletion, projectedCompletion;
  final String? error;
  bool get isValid => error == null;
  int get shiftedSuccessors => changes.length > 1 ? changes.length - 1 : 0;
}

/// Calendar-day finish-to-start scheduling. A successor may begin on the
/// calendar day after its predecessor finishes. Non-working day calendars,
/// manpower conflicts and critical path calculations are deliberately NOT
/// modeled here.
class WorkSchedulePlanner {
  static DateTime _date(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static WorkScheduleProposal preview({
    required WorkBoard board,
    required String taskId,
    required DateTime start,
    required DateTime finish,
    String? predecessorId,
  }) {
    final tasks = board.tasks;
    final byId = <String, WorkTask>{};
    for (final task in tasks) {
      if (task.id.isEmpty || byId.containsKey(task.id)) {
        return _error('В графике обнаружены повторяющиеся или пустые ID работ.');
      }
      byId[task.id] = task;
    }
    final root = byId[taskId];
    if (root == null) return _error('Работа больше не найдена в проекте.');
    start = _date(start);
    finish = _date(finish);
    if (finish.isBefore(start)) return _error('Дата окончания раньше начала.');
    if (predecessorId == taskId) {
      return _error('Работа не может зависеть от самой себя.');
    }
    if (predecessorId != null && !byId.containsKey(predecessorId)) {
      return _error('Предыдущая работа не найдена.');
    }

    String? predecessorOf(String id) =>
        id == taskId ? predecessorId : byId[id]!.predecessorId;

    // Check the whole dependency graph before attempting any date changes.
    final visits = <String, int>{};
    String? graphProblem;
    bool visit(String id) {
      final visitState = visits[id] ?? 0;
      if (visitState == 1) {
        graphProblem = 'Обнаружен цикл зависимостей между работами.';
        return false;
      }
      if (visitState == 2) return true;
      visits[id] = 1;
      final prior = predecessorOf(id);
      if (prior != null) {
        if (!byId.containsKey(prior)) {
          graphProblem = 'У одной из работ отсутствует предыдущая задача.';
          return false;
        }
        if (!visit(prior)) return false;
      }
      visits[id] = 2;
      return true;
    }
    for (final id in byId.keys) {
      if (!visit(id)) return _error(graphProblem!);
    }

    final rootPrevious = predecessorId == null ? null : byId[predecessorId];
    if (rootPrevious != null && !start.isAfter(_date(rootPrevious.finish))) {
      return _error('Начало работы должно быть после завершения предыдущей.');
    }

    final children = <String, List<String>>{};
    for (final id in byId.keys) {
      final prior = predecessorOf(id);
      if (prior != null) children.putIfAbsent(prior, () => []).add(id);
    }
    final proposals = <String, WorkScheduleChange>{};

    WorkScheduleChange makeChange(
      WorkTask task, DateTime newStart, DateTime newFinish, String? prior,
    ) => WorkScheduleChange(
      taskId: task.id,
      title: task.title,
      oldStart: _date(task.start),
      oldFinish: _date(task.finish),
      start: newStart,
      finish: newFinish,
      oldPredecessorId: task.predecessorId,
      predecessorId: prior,
    );

    final changedRoot = !_sameDay(root.start, start) ||
        !_sameDay(root.finish, finish) ||
        root.predecessorId != predecessorId;
    if (changedRoot) {
      proposals[root.id] = makeChange(root, start, finish, predecessorId);
    }

    // Traverse the descendants in topological order; only push a successor
    // forward when it would overlap its prerequisite. Never pull it earlier.
    final queue = <String>[root.id];
    while (queue.isNotEmpty) {
      final parentId = queue.removeAt(0);
      final parent = byId[parentId]!;
      final parentFinish = proposals[parentId]?.finish ?? _date(parent.finish);
      for (final childId in children[parentId] ?? const <String>[]) {
        final child = byId[childId]!;
        final currentStart = proposals[childId]?.start ?? _date(child.start);
        final currentFinish = proposals[childId]?.finish ?? _date(child.finish);
        final minimumStart = _addDays(parentFinish, 1);
        if (currentStart.isBefore(minimumStart)) {
          if (child.done > 0 || child.accepted > 0) {
            return _error('Нельзя автоматически перенести уже начатую работу «' +
                child.title + '». Измените график вручную.');
          }
          final shiftDays = minimumStart.difference(currentStart).inDays;
          // DateTime(year, month, day + N) avoids local DST hour drift.
          final nextStart = _addDays(currentStart, shiftDays);
          final nextFinish = _addDays(currentFinish, shiftDays);
          proposals[childId] =
              makeChange(child, nextStart, nextFinish, child.predecessorId);
        }
        queue.add(childId);
      }
    }

    final originalCompletion = tasks.isEmpty
        ? null
        : tasks.map((task) => _date(task.finish))
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final newCompletion = tasks.isEmpty
        ? null
        : tasks.map((task) => proposals[task.id]?.finish ?? _date(task.finish))
            .reduce((a, b) => a.isAfter(b) ? a : b);
    return WorkScheduleProposal(
      changes: proposals.values.toList(growable: false),
      previousCompletion: originalCompletion,
      projectedCompletion: newCompletion,
    );
  }

  static WorkScheduleProposal _error(String message) =>
      WorkScheduleProposal(
        changes: const [],
        previousCompletion: null,
        projectedCompletion: null,
        error: message,
      );

  /// Atomic apply, with a stale-preview check. No state is mutated on error.
  static String? apply(WorkBoard board, WorkScheduleProposal proposal) {
    if (!proposal.isValid) return proposal.error;
    final byId = {for (final task in board.tasks) task.id: task};
    for (final change in proposal.changes) {
      final task = byId[change.taskId];
      if (task == null ||
          !_sameDay(task.start, change.oldStart) ||
          !_sameDay(task.finish, change.oldFinish) ||
          task.predecessorId != change.oldPredecessorId) {
        return 'График изменился. Откройте предварительный просмотр заново.';
      }
    }
    for (final change in proposal.changes) {
      final task = byId[change.taskId]!;
      task.start = change.start;
      task.finish = change.finish;
      task.predecessorId = change.predecessorId;
    }
    return null;
  }
}
