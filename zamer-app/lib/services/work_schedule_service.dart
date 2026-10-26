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
