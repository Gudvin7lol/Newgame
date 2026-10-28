import '../models/work_board.dart';
import 'work_co_stage_service.dart';

enum WorkState {
  planned,
  blocked,
  ready,
  inProgress,
  paused,
  awaitingAcceptance,
  accepted,
  overdue,
  defect,
  quantityReview,
}

extension WorkStateLabel on WorkState {
  String get label => switch (this) {
    WorkState.planned => 'Запланировано',
    WorkState.blocked => 'Ожидает этапы',
    WorkState.ready => 'Готово к началу',
    WorkState.inProgress => 'В работе',
    WorkState.paused => 'Приостановлено',
    WorkState.awaitingAcceptance => 'На приёмке',
    WorkState.accepted => 'Принято',
    WorkState.overdue => 'Просрочено',
    WorkState.defect => 'Есть замечания',
    WorkState.quantityReview => 'Проверить объём',
  };
}

/// Derives operational status from live data. Status is intentionally not
/// stored separately, so it cannot become inconsistent with completion.
class WorkStatusService {
  static List<String> prerequisites(WorkTask task) {
    final ids = <String>{...task.requiredPredecessorIds};
    if (task.predecessorId != null) ids.add(task.predecessorId!);
    ids.remove(task.id);
    return ids.toList(growable: false);
  }

  static List<WorkTask> outstanding(WorkBoard board, WorkTask task) {
    final byId = {for (final t in board.tasks) t.id: t};
    return [
      for (final id in WorkCoStageService.expandedPredecessors(board, task))
        if (byId[id] == null || !byId[id]!.fullyAccepted ||
            byId[id]!.needsQuantityReview ||
            board.issues.any((issue) => issue.open && issue.taskId == id))
          if (byId[id] != null) byId[id]!,
    ];
  }

  static List<String> missingPrerequisiteIds(WorkBoard board, WorkTask task) {
    final ids = board.tasks.map((t) => t.id).toSet();
    return WorkCoStageService.expandedPredecessors(board, task)
        .where((id) => !ids.contains(id)).toList();
  }

  static bool canStart(WorkBoard board, WorkTask task) =>
      !task.needsQuantityReview &&
      missingPrerequisiteIds(board, task).isEmpty &&
      outstanding(board, task).isEmpty;

  static bool canAccept(WorkBoard board, WorkTask task) =>
      !task.needsQuantityReview &&
      task.done > task.accepted &&
      !board.issues.any((issue) => issue.taskId == task.id && issue.open);

  static WorkState state(WorkBoard board, WorkTask task, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (board.issues.any((issue) => issue.taskId == task.id && issue.open)) {
      return WorkState.defect;
    }
    if (task.needsQuantityReview) return WorkState.quantityReview;
    if (task.fullyAccepted) return WorkState.accepted;
    if (task.paused) return WorkState.paused;
    if (task.complete) return WorkState.awaitingAcceptance;
    // An unfinished job remains overdue even if someone already started it.
    // Otherwise delayed work disappears from the compact Control view.
    if (task.progress > 0 && task.isDelayed(now)) return WorkState.overdue;
    if (task.progress > 0) return WorkState.inProgress;
    if (!canStart(board, task)) return WorkState.blocked;
    if (task.isDelayed(now)) return WorkState.overdue;
    final today = DateTime(now.year, now.month, now.day);
    final starts = DateTime(task.start.year, task.start.month, task.start.day);
    return today.isBefore(starts) ? WorkState.planned : WorkState.ready;
  }

  static String? startBlocker(WorkBoard board, WorkTask task) {
    if (task.needsQuantityReview) return 'Сначала подтвердите расчётный объём.';
    final missing = missingPrerequisiteIds(board, task);
    if (missing.isNotEmpty) return 'Не найдены обязательные этапы: ${missing.join(', ')}.';
    final pending = outstanding(board, task);
    if (pending.isNotEmpty) {
      return 'Сначала примите связанные этапы: ${pending.map((e) => e.title).join(', ')}.';
    }
    return null;
  }
}
