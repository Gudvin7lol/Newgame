import '../models/work_board.dart';

/// Cohort membership is undirected, unlike predecessor links. An operation
/// can begin independently of its peers; downstream work waits for all peers
/// to be accepted. Mutual co-stage links are NOT dependency graph cycles.
class WorkCoStageService {
  static Map<String, WorkTask> indexed(WorkBoard board) =>
      {for (final task in board.tasks) task.id: task};

  /// Resolve a connected group, even if legacy JSON records one side only.
  static Set<String> memberIds(WorkBoard board, String taskId) {
    final byId = indexed(board);
    if (!byId.containsKey(taskId)) return {};
    final members = <String>{taskId};
    final queue = <String>[taskId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final task in board.tasks) {
        if (task.id == current) continue;
        if ((byId[current]?.coStageTaskIds.contains(task.id) ?? false) ||
            task.coStageTaskIds.contains(current)) {
          if (members.add(task.id)) queue.add(task.id);
        }
      }
    }
    return members;
  }

  /// All members are completion gates for successors of any member.
  static Set<String> expandedPredecessors(
      WorkBoard board, WorkTask task) {
    final base = <String>{
      ...task.requiredPredecessorIds,
      if (task.predecessorId != null) task.predecessorId!,
    };
    final expanded = <String>{};
    for (final id in base) {
      expanded.add(id);
      expanded.addAll(memberIds(board, id));
    }
    return expanded;
  }

  static String? validateLink(
      WorkBoard board, String firstId, String secondId) {
    final byId = indexed(board);
    final first = byId[firstId], second = byId[secondId];
    if (first == null || second == null) return 'Не найдены выбранные работы.';
    if (firstId == secondId) return 'Нельзя связать работу с самой собой.';
    if (first.floorId != second.floorId ||
        first.roomId != second.roomId) {
      return 'Созависимые работы должны относиться к одному помещению.';
    }

    // Reject peer groups that would contain direct or indirect predecessor
    // edges. Their membership is symmetric, so such a link would deadlock.
    final candidates = <String>{
      ...memberIds(board, firstId),
      ...memberIds(board, secondId),
    };
    for (final memberId in candidates) {
      final task = byId[memberId]!;
      final deps = <String>{
        ...task.requiredPredecessorIds,
        if (task.predecessorId != null) task.predecessorId!,
      };
      if (deps.any(candidates.contains)) {
        return 'Между связанными работами уже есть последовательная зависимость.';
      }
    }
    // Also reject indirect paths, e.g. task A -> B -> C then joining A/C.
    final visited = <String>{};
    bool dependsOnGroup(String origin, String id) {
      if (!visited.add(id)) return false;
      final task = byId[id];
      if (task == null) return false;
      final dependencies = expandedPredecessors(board, task);
      for (final dep in dependencies) {
        if (candidates.contains(dep) && dep != origin) return true;
        if (!visited.contains(dep) && dependsOnGroup(origin, dep)) return true;
      }
      return false;
    }
    for (final memberId in candidates) {
      visited.clear();
      if (dependsOnGroup(memberId, memberId)) {
        return 'Между этапами уже существует цепочка предшественников.';
      }
    }
    return null;
  }

  /// Store symmetric immediate links; transitively reachable peers resolve
  /// into a single phase without duplicate tasks or changed task IDs.
  static String? link(
      WorkBoard board, String firstId, String secondId) {
    final error = validateLink(board, firstId, secondId);
    if (error != null) return error;
    final byId = indexed(board);
    final first = byId[firstId]!, second = byId[secondId]!;
    if (!first.coStageTaskIds.contains(second.id)) {
      first.coStageTaskIds.add(second.id);
    }
    if (!second.coStageTaskIds.contains(first.id)) {
      second.coStageTaskIds.add(first.id);
    }
    return null;
  }

  static void unlink(
      WorkBoard board, String firstId, String secondId) {
    final byId = indexed(board);
    byId[firstId]?.coStageTaskIds.remove(secondId);
    byId[secondId]?.coStageTaskIds.remove(firstId);
  }
}
