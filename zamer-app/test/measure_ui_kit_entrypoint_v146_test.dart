import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/recovered_measure_workspace_screen.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';

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
  testWidgets('UI Kit renders actual Measure canvas on narrow Android viewport',
      (tester) async {
    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor]);
    await tester.pumpWidget(MaterialApp(
      home: RecoveredMeasureWorkspaceScreen(
        project: project,
        floor: floor,
        onChanged: () async {},
        onUndo: null,
        onRedo: null,
        canUndo: false,
        canRedo: false,
        onMore: () {},
        onOpen3D: () {},
        onOpenPhoto: () {},
        onOpenReview: () {},
        onOpenGeometry: () {},
        onOpenFloors: () {},
        onHome: () {},
        onProfile: () {},
        onPrimaryMode: (_) {},
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('zamer-native-v2-fan')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('kit-v2-domain-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('kit-v2-tasks')),
        findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'No infinite-width task button layout on TECNO');

    await tester.tap(find.byKey(const ValueKey('kit-v2-task-0')));
    await tester.pump();
    expect(tester.widget<ZamerKitFan>(
        find.byType(ZamerKitFan)).contextId,
        startsWith('plan.wall.create'));
    expect(tester.takeException(), isNull);
  });

}
