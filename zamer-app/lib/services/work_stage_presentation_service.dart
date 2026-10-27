import '../models/work_board.dart';
import 'work_status_service.dart';

/// Stable visual ordering for the Works accordion.
/// Dependencies are respected within each group, while independent jobs are
/// ordered by start date and title. Parallel co-stages remain parallel: they
/// never gain artificial predecessor edges.
class WorkStagePresentationService {
  /// A workload-weighted fraction, rather than treating a 1-hour inspection
  /// as equally important as a 60-hour plastering job.
  static double acceptedProgress(Iterable<WorkTask> tasks) {
    var total = 0.0, completed = 0.0;
    for (final task in tasks) {
      final weight = task.hours.isFinite && task.hours > 0
          ? task.hours : 1.0;
      // Geometry changes can invalidate an otherwise accepted quantity.
      // Do not present unchecked scope as verified completion.
      final fraction = task.needsQuantityReview
          ? 0.0 : task.acceptedProgress.clamp(0.0, 1.0);
      total += weight;
      completed += weight * fraction;
    }
    return total == 0 ? 0.0 :
        (completed / total).clamp(0.0, 1.0).toDouble();
  }

  /// One actionable task for a compact summary. Acceptance/defects belong to
  /// the dedicated Control tab and do not duplicate the alert indicator.
  static WorkTask? currentTask(
      WorkBoard board, Iterable<WorkTask> tasks, {DateTime? at}) {
    int priority(WorkTask task) => switch (
      WorkStatusService.state(board, task, at: at)) {
      WorkState.inProgress => 0,
      WorkState.overdue => 1,
      WorkState.ready => 2,
      WorkState.paused => 3,
      WorkState.planned => 4,
      WorkState.blocked => 5,
      WorkState.accepted || WorkState.awaitingAcceptance ||
      WorkState.quantityReview || WorkState.defect => 99,
    };
    final candidates = tasks.where((t) => priority(t) < 99).toList()
      ..sort((a, b) {
        final difference = priority(a).compareTo(priority(b));
        if (difference != 0) return difference;
        final date = a.start.compareTo(b.start);
        if (date != 0) return date;
        return a.id.compareTo(b.id);
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  static List<WorkTask> order(List<WorkTask> tasks) {
    final byId = <String, WorkTask>{for (final t in tasks) t.id: t};
    final pending = <String, Set<String>>{};
    for (final task in tasks) {
      pending[task.id] = <String>{
        ...task.requiredPredecessorIds,
        if (task.predecessorId != null) task.predecessorId!,
      }.where((id) => id != task.id && byId.containsKey(id)).toSet();
    }

    int bySchedule(WorkTask a, WorkTask b) {
      final date = a.start.compareTo(b.start);
      if (date != 0) return date;
      final title = a.title.compareTo(b.title);
      return title != 0 ? title : a.id.compareTo(b.id);
    }

    final result = <WorkTask>[];
    final visited = <String>{};
    while (result.length < tasks.length) {
      final ready = tasks.where((t) =>
          !visited.contains(t.id) && pending[t.id]!.isEmpty).toList()
        ..sort(bySchedule);
      if (ready.isEmpty) {
        // Imported legacy projects may contain invalid cycles. Keep all jobs
        // visible for correction rather than hanging the planning screen.
        final invalid = tasks.where((t) => !visited.contains(t.id)).toList()
          ..sort(bySchedule);
        result.addAll(invalid);
        break;
      }
      final current = ready.first;
      visited.add(current.id);
      result.add(current);
      for (final prerequisites in pending.values) {
        prerequisites.remove(current.id);
      }
    }
    return result;
  }
}
