import '../models/work_board.dart';

/// Stable visual ordering for the Works accordion.
/// Dependencies are respected within each group, while independent jobs are
/// ordered by start date and title. Parallel co-stages remain parallel: they
/// never gain artificial predecessor edges.
class WorkStagePresentationService {
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
