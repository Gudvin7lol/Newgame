/// Command contract for all future project edits.
///
/// Existing screens can migrate one operation at a time without changing the
/// persisted model or the CAD painters.
abstract interface class WorkspaceCommand {
  String get description;

  void execute();

  void undo();
}

/// Small command history used by the workspace controller. The current
/// recovery shell still supplies its JSON snapshot history; this class is the
/// target for moving individual edits to transactional commands.
class WorkspaceCommandHistory {
  WorkspaceCommandHistory({this.limit = 100});

  final int limit;
  final List<WorkspaceCommand> _undo = [];
  final List<WorkspaceCommand> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void execute(WorkspaceCommand command) {
    command.execute();
    _undo.add(command);
    _redo.clear();
    if (_undo.length > limit) _undo.removeAt(0);
  }

  void undo() {
    if (_undo.isEmpty) return;
    final command = _undo.removeLast();
    command.undo();
    _redo.add(command);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final command = _redo.removeLast();
    command.execute();
    _undo.add(command);
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
