import 'workspace_session.dart';

enum WorkspaceActionLocation { ribbon, fan, inspector, gesture }

/// Single source of truth for where an action is exposed in the workspace.
///
/// The registry deliberately keeps creation tools out of the radial fan and
/// keeps destructive/property actions in the inspector. This prevents the
/// same command from appearing in three different controls.
abstract final class WorkspaceActionRegistry {
  static const _ribbon = <WorkspaceDomain, Set<String>>{
    WorkspaceDomain.plan: {'wall', 'partition', 'opening', 'demolition'},
    WorkspaceDomain.floor: {'cover', 'underlay', 'plinth'},
    WorkspaceDomain.objects: {'catalog', 'check'},
    WorkspaceDomain.electrical: {
      'socket', 'switch', 'light', 'panel',
    },
  };

  static const _fan = <WorkspaceDomain, Set<String>>{
    WorkspaceDomain.plan: {'select', 'nodes', 'arc', 'measure'},
    WorkspaceDomain.floor: {'select'},
    WorkspaceDomain.objects: {'select', 'rotate', 'duplicate'},
    WorkspaceDomain.electrical: {'select', 'point', 'line', 'route'},
  };

  static const _inspector = <WorkspaceDomain, Set<String>>{
    WorkspaceDomain.plan: {'done', 'cancel', 'delete'},
    WorkspaceDomain.floor: {'apply', 'cancel'},
    WorkspaceDomain.objects: {'delete'},
    WorkspaceDomain.electrical: {'done', 'cancel', 'delete'},
  };

  static const _gesture = <WorkspaceDomain, Set<String>>{
    WorkspaceDomain.plan: {'pan', 'zoom', 'drag'},
    WorkspaceDomain.floor: {'pan', 'zoom', 'drag'},
    WorkspaceDomain.objects: {'pan', 'zoom', 'drag'},
    WorkspaceDomain.electrical: {'pan', 'zoom', 'drag'},
  };

  static Set<String> actions(
    WorkspaceDomain domain,
    WorkspaceActionLocation location,
  ) => switch (location) {
    WorkspaceActionLocation.ribbon => _ribbon[domain] ?? const <String>{},
    WorkspaceActionLocation.fan => _fan[domain] ?? const <String>{'select'},
    WorkspaceActionLocation.inspector =>
      _inspector[domain] ?? const <String>{},
    WorkspaceActionLocation.gesture => _gesture[domain] ?? const <String>{},
  };

  static bool hasDuplicate(WorkspaceDomain domain, String action) {
    final locations = <WorkspaceActionLocation>[
      WorkspaceActionLocation.ribbon,
      WorkspaceActionLocation.fan,
      WorkspaceActionLocation.inspector,
      WorkspaceActionLocation.gesture,
    ];
    return locations
        .where((location) => actions(domain, location).contains(action))
        .length > 1;
  }
}
