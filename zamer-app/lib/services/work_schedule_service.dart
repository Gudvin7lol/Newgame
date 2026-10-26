import 'dart:convert';

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
    int lagDays = 0,
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final through = DateTime(finish.year, finish.month, finish.day);
    if (through.isBefore(from)) return 'Дата окончания раньше начала.';
    if (lagDays < 0 || lagDays > 3650) return 'Недопустимая технологическая пауза.';
    if (!board.calendar.isWorkday(from) || !board.calendar.isWorkday(through)) {
      return 'Начало и окончание должны быть рабочими днями.';
    }
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
        from.isBefore(board.calendar.firstDayAfter(predecessor.finish, lagDays))) {
      return 'Начало раньше завершения предыдущей работы.';
    }

    final nextTasks = board.tasks.where((t) => t.predecessorId == taskId);
    for (final next in nextTasks) {
      final nextStart = DateTime(next.start.year, next.start.month, next.start.day);
      if (nextStart.isBefore(board.calendar.firstDayAfter(through, next.lagDays))) {
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
    required this.oldLagDays,
    required this.lagDays,
  });

  final String taskId;
  final String title;
  final DateTime oldStart, oldFinish, start, finish;
  final String? oldPredecessorId, predecessorId;
  final int oldLagDays, lagDays;
  bool get moved => oldStart != start || oldFinish != finish;
}

class WorkScheduleProposal {
  const WorkScheduleProposal({
    required this.changes,
    this.rootTaskId,
    this.calendarSignature,
    required this.previousCompletion,
    required this.projectedCompletion,
    this.error,
  });

  final List<WorkScheduleChange> changes;
  final String? rootTaskId, calendarSignature;
  final DateTime? previousCompletion, projectedCompletion;
  final String? error;
  bool get isValid => error == null;
  int get shiftedSuccessors =>
      changes.where((change) => change.taskId != rootTaskId).length;
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
    int? lagDays,
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
    final selectedLag = lagDays ?? root.lagDays;
    if (selectedLag < 0 || selectedLag > 3650) {
      return _error('Недопустимая технологическая пауза.');
    }
    start = _date(start);
    finish = _date(finish);
    if (finish.isBefore(start)) return _error('Дата окончания раньше начала.');
    if (!board.calendar.isWorkday(start) || !board.calendar.isWorkday(finish)) {
      return _error('Выберите рабочие дни для начала и завершения работы.');
    }
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
    if (rootPrevious != null &&
        start.isBefore(board.calendar.firstDayAfter(rootPrevious.finish, selectedLag))) {
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
      int proposedLag,
    ) => WorkScheduleChange(
      taskId: task.id,
      title: task.title,
      oldStart: _date(task.start),
      oldFinish: _date(task.finish),
      start: newStart,
      finish: newFinish,
      oldPredecessorId: task.predecessorId,
      predecessorId: prior,
      oldLagDays: task.lagDays,
      lagDays: proposedLag,
    );

    final changedRoot = !_sameDay(root.start, start) ||
        !_sameDay(root.finish, finish) ||
        root.predecessorId != predecessorId || root.lagDays != selectedLag;
    if (changedRoot) {
      proposals[root.id] = makeChange(root, start, finish, predecessorId,
          selectedLag);
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
        final minimumStart =
            board.calendar.firstDayAfter(parentFinish, child.lagDays);
        if (currentStart.isBefore(minimumStart)) {
          if (child.done > 0 || child.accepted > 0) {
            return _error('Нельзя автоматически перенести уже начатую работу «' +
                child.title + '». Измените график вручную.');
          }
          final workingDuration =
              board.calendar.workingDaysInclusive(currentStart, currentFinish);
          final nextStart = board.calendar.nextWorkday(minimumStart);
          final nextFinish = board.calendar.finishForDuration(
              nextStart, workingDuration < 1 ? 1 : workingDuration);
          proposals[childId] = makeChange(
              child, nextStart, nextFinish, child.predecessorId, child.lagDays);
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
      rootTaskId: taskId,
      calendarSignature: jsonEncode(board.calendar.toJson()),
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
    if (proposal.calendarSignature != null &&
        proposal.calendarSignature != jsonEncode(board.calendar.toJson())) {
      return 'Календарь изменился. Пересчитайте график.';
    }
    final byId = {for (final task in board.tasks) task.id: task};
    for (final change in proposal.changes) {
      final task = byId[change.taskId];
      if (task == null ||
          !_sameDay(task.start, change.oldStart) ||
          !_sameDay(task.finish, change.oldFinish) ||
          task.predecessorId != change.oldPredecessorId ||
          task.lagDays != change.oldLagDays) {
        return 'График изменился. Откройте предварительный просмотр заново.';
      }
    }
    if (proposal.changes.isNotEmpty) {
      final rootId = proposal.rootTaskId;
      final rootEdit = proposal.changes.where((c) => c.taskId == rootId).firstOrNull;
      final currentRoot = rootId == null ? null : byId[rootId];
      if (currentRoot == null) {
        return 'График изменился. Обновите предварительный просмотр.';
      }
      final current = preview(
        board: board,
        taskId: rootId!,
        start: rootEdit?.start ?? currentRoot.start,
        finish: rootEdit?.finish ?? currentRoot.finish,
        predecessorId: rootEdit == null ? currentRoot.predecessorId : rootEdit.predecessorId,
        lagDays: rootEdit == null ? currentRoot.lagDays : rootEdit.lagDays,
      );
      if (!current.isValid ||
          current.changes.length != proposal.changes.length) {
        return 'График изменился. Обновите предварительный просмотр.';
      }
      for (var i = 0; i < current.changes.length; i++) {
        final a = current.changes[i];
        final b = proposal.changes[i];
        if (a.taskId != b.taskId ||
            !_sameDay(a.start, b.start) ||
            !_sameDay(a.finish, b.finish) ||
            a.predecessorId != b.predecessorId || a.lagDays != b.lagDays) {
          return 'График изменился. Обновите предварительный просмотр.';
        }
      }
    }
    for (final change in proposal.changes) {
      final task = byId[change.taskId]!;
      task.start = change.start;
      task.finish = change.finish;
      task.predecessorId = change.predecessorId;
      task.lagDays = change.lagDays;
    }
    return null;
  }
}
