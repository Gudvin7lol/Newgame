import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/application/workspace_action_registry.dart';
import 'package:zamer_app/application/workspace_commands.dart';
import 'package:zamer_app/application/workspace_session.dart';
import 'package:zamer_app/widgets/zamer_fan_profiles_v2.dart';

class _CounterCommand implements WorkspaceCommand {
  _CounterCommand(this.value);

  final List<int> value;

  @override
  String get description => 'counter';

  @override
  void execute() => value.add(1);

  @override
  void undo() {
    if (value.isNotEmpty) value.removeLast();
  }
}

void main() {
  test('workspace session resets transient state when changing domain', () {
    final session = WorkspaceSession();
    addTearDown(session.dispose);

    session.selectTask(2);
    session.setSelection('wall', id: 'w-1');
    session.setQuickAction('nodes');
    session.selectDomain(WorkspaceDomain.electrical);

    expect(session.domain, WorkspaceDomain.electrical);
    expect(session.taskIndex, 0);
    expect(session.taskActivated, isFalse);
    expect(session.selection, isNull);
    expect(session.quickAction, 'select');
    expect(session.stage, WorkspaceOperationStage.idle);
  });

  test('canonical fan vocabulary does not expose upper-ribbon duplicates', () {
    final plan = ZamerFanProfilesV2.canonicalForDomain(
      0,
      enabledActions: {'select', 'nodes', 'arc', 'measure'},
    );
    final planIds = <String>{
      'select',
      plan.first.id,
      plan.second.id,
      ...plan.outer.where((item) => item.enabled).map((item) => item.id),
    };
    expect(planIds, containsAll(<String>{'select', 'nodes', 'arc', 'measure'}));
    expect(planIds, isNot(contains('wall')));
    expect(planIds, isNot(contains('opening')));

    final electrical = ZamerFanProfilesV2.canonicalForDomain(
      3,
      enabledActions: {'select', 'point', 'line', 'route'},
    );
    expect(
      <String>{
        'select',
        electrical.first.id,
        electrical.second.id,
        ...electrical.outer
            .where((item) => item.enabled)
            .map((item) => item.id),
      },
      isNot(contains('socket')),
    );
  });

  test('workspace action registry has one visible owner per command', () {
    for (final domain in WorkspaceDomain.values.take(4)) {
      for (final location in WorkspaceActionLocation.values) {
        for (final action in WorkspaceActionRegistry.actions(domain, location)) {
          expect(
            WorkspaceActionRegistry.hasDuplicate(domain, action),
            isFalse,
            reason: '$domain exposes $action in more than one location',
          );
        }
      }
    }
  });

  test('command history executes, undoes and redoes one edit', () {
    final values = <int>[];
    final history = WorkspaceCommandHistory();
    history.execute(_CounterCommand(values));
    expect(values, [1]);
    expect(history.canUndo, isTrue);
    history.undo();
    expect(values, isEmpty);
    expect(history.canRedo, isTrue);
    history.redo();
    expect(values, [1]);
  });
}
