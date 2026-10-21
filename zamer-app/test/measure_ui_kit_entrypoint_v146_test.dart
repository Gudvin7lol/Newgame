import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: +145 shipped the native radial interface but Home still used
/// the legacy FloorWorkspaceScreen, so actual users saw the OLD 2D controls.
/// Both entry paths must reach the same production Measure UI Kit.
void main() {
  test('Home opens new Measure UI Kit route, not legacy workspace', () {
    final home =
        File('lib/screens/production_home_screen.dart').readAsStringSync();
    final shell =
        File('lib/screens/recovered_project_workspace_screen.dart')
            .readAsStringSync();
    final measure =
        File('lib/screens/recovered_measure_workspace_screen.dart')
            .readAsStringSync();

    expect(home, contains("import 'recovered_project_workspace_screen.dart';"));
    expect(home, contains('builder: (_) => RecoveredProjectWorkspaceScreen('));
    expect(home, isNot(contains('FloorWorkspaceScreen(')));
    expect(shell, contains('return RecoveredMeasureWorkspaceScreen('));
    expect(measure, contains('_kitDomains()'));
    expect(measure, contains('_kitTasks()'));
    expect(measure, contains('ZamerKitFan('));
    expect(measure, contains('singleFurnitureView: true'));
  });

  test('Project list opens the same recovered Measure screen', () {
    final projects = File('lib/screens/projects_screen.dart').readAsStringSync();
    final floors = File('lib/screens/floors_screen.dart').readAsStringSync();

    expect(projects, contains('FloorsScreen(project: project, onChanged: _save)'));
    expect(floors, contains('RecoveredProjectWorkspaceScreen('));
    expect(floors, isNot(contains('FloorWorkspaceScreen(')));
  });

  test('home still forwards requested 3D/Elevations modes and save callback', () {
    final home =
        File('lib/screens/production_home_screen.dart').readAsStringSync();
    expect(home, contains('initialMode: mode.clamp(0, 2)'));
    expect(home, contains('onChanged: _save'));
    expect(home, contains('floor: project.floors.first'));
  });
}
