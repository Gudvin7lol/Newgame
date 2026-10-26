import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/application/workspace_session.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/screens/works_screen.dart';

void main() {
  test('Works is a Measure domain and retains the first six legacy indices', () {
    expect(WorkspaceDomain.values.last, WorkspaceDomain.works);
    expect(WorkspaceDomain.values.indexOf(WorkspaceDomain.plan), 0);
    expect(WorkspaceDomain.values.indexOf(WorkspaceDomain.floor), 1);
    expect(WorkspaceDomain.values.indexOf(WorkspaceDomain.objects), 2);
    expect(WorkspaceDomain.values.indexOf(WorkspaceDomain.electrical), 3);
    expect(WorkspaceDomain.values.indexOf(WorkspaceDomain.materials), 5);
    final workspace = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    expect(workspace, contains("('Работы', Icons.handyman_outlined)"));
    expect(workspace, contains('WorksScreen('));
    expect(workspace, contains('embedded: true'));
    expect(workspace, contains('floorId: widget.floor.id'));
    final shell = File('lib/screens/recovered_project_workspace_screen.dart')
        .readAsStringSync();
    expect(shell, isNot(contains("title: 'Работы • календарь и контроль'")));
  });

  testWidgets('small-screen work mode groups tasks and reveals only chosen stage',
      (tester) async {
    tester.view.physicalSize = const Size(393, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'floor', name: 'Этаж 1');
    final project = MeasureProject(id: 'project', name: 'Квартира',
        floors: [floor]);
    final day = DateTime(2026, 11, 2);
    project.workBoard.tasks.addAll([
      WorkTask(
        id: 'wall', title: 'Покраска стен',
        operationCode: 'wall_paint',
        floorId: floor.id, start: day, finish: day,
        quantity: 20, unit: 'м²', hours: 12,
      ),
      WorkTask(
        id: 'elec', title: 'Монтаж электрики',
        operationCode: 'electrical_rough',
        floorId: floor.id, start: day,
        finish: day.add(const Duration(days: 2)),
        quantity: 1, unit: 'компл.', hours: 8,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: floor.id,
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Этапы'), findsOneWidget);
    expect(find.text('График'), findsOneWidget);
    expect(find.text('Контроль'), findsOneWidget);
    expect(find.byKey(const ValueKey('works-group-Стены')), findsOneWidget);
    expect(find.byKey(const ValueKey('works-group-Электрика')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('work-row-wall')), findsNothing);
    expect(find.text('Отделка по отдельным стенам'), findsNothing);
    expect(find.text('Нарисовать зоны пола'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('works-group-Стены')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-row-wall')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-row-elec')), findsNothing);
    await tester.tap(find.text('График'));
    await tester.pumpAndSettle();
    expect(find.text('Неделя'), findsOneWidget);
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();
    expect(find.text('Контроль помещений'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rare work tools are behind one overflow menu', (tester) async {
    final project = MeasureProject(id: 'p', name: 'Объект',
      floors: [FloorPlan(id: 'f', name: 'Этаж 1')]);
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: 'f',
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Сформировать работы'), findsOneWidget);
    expect(find.text('Отделка стен'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('works-tools')));
    await tester.pumpAndSettle();
    expect(find.text('Отделка стен'), findsOneWidget);
    expect(find.text('Зоны пола'), findsOneWidget);
    expect(find.text('Рабочий календарь'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
