import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/application/workspace_session.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/work_status_service.dart';
import 'package:zamer_app/screens/works_screen.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';

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
    // Overflow contains supplementary domains only: primary five modes
    // already have large touch targets in the top strip.
    expect(workspace, contains('items: [_layers[4], _layers[5]]'));
  });

  testWidgets('all five primary Measure modes fit narrow mobile width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const labels = ['План', 'Пол', 'Объекты', 'Электрика', 'Работы'];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Align(alignment: Alignment.topCenter,
        child: SizedBox(width: 360, child: Row(children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(child: ZamerKitSegment(
              label: labels[index],
              icon: Icons.architecture_outlined,
              stacked: true,
              selected: index == 4,
              onTap: () {},
            )),
        ]))),
    )));
    await tester.pumpAndSettle();
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
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
    // One visible shortcut replaces searching through all collapsed stages.
    expect(find.byKey(const ValueKey('works-current-task')), findsOneWidget);
    expect(find.textContaining('Далее по плану:'), findsOneWidget);
    expect(find.text('Отделка по отдельным стенам'), findsNothing);
    expect(find.text('Нарисовать зоны пола'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('works-group-Стены')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-row-wall')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-row-elec')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('works-group-Электрика')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-row-wall')), findsNothing);
    expect(find.byKey(const ValueKey('work-row-elec')), findsOneWidget);
    await tester.tap(find.text('График'));
    await tester.pumpAndSettle();
    expect(find.text('Неделя'), findsOneWidget);
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();
    expect(find.text('Контроль помещений'), findsOneWidget);
    expect(find.byKey(const ValueKey('works-map-toggle')), findsOneWidget);
    expect(find.text('Показать загрузку бригад'), findsOneWidget);
    // Large panels do not take over a small screen unless explicitly opened.
    await tester.tap(find.byKey(const ValueKey('works-map-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Контроль помещений'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current work shortcut opens existing task without extra navigation',
      (tester) async {
    final project = MeasureProject(id: 'shortcut', name: 'Объект',
      floors: [FloorPlan(id: 'f', name: 'Этаж')]);
    final date = DateTime(2026, 10, 26);
    project.workBoard.tasks.add(WorkTask(
      id: 'active', title: 'Штукатурка спальни', start: date,
      finish: date.add(const Duration(days: 4)), quantity: 40,
      done: 7, unit: 'м²', hours: 16, floorId: 'f',
    ));
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: 'f',
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('В работе:'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('works-current-task')));
    await tester.pumpAndSettle();
    expect(find.textContaining('В работе: Штукатурка спальни'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-inline-active')), findsOneWidget);
    expect(find.text('Подробнее'), findsOneWidget);
    expect(find.text('Сроки и зависимости'), findsNothing);
    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    expect(find.text('Параметры'), findsOneWidget);
    expect(find.text('Сроки и зависимости'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('work-options-active')));
    await tester.pumpAndSettle();
    expect(find.text('Сроки и зависимости'), findsOneWidget);
    expect(find.text('Созависимые этапы'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage task expands inside its group with one primary action',
      (tester) async {
    tester.view.physicalSize = const Size(393, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Этаж');
    final project = MeasureProject(id: 'inline', name: 'Объект',
      floors: [floor]);
    project.workBoard.tasks.add(WorkTask(
      id: 'plaster', title: 'Штукатурка стен',
      operationCode: 'wall_plaster_gypsum',
      floorId: floor.id, start: DateTime(2026, 10, 26),
      finish: DateTime(2026, 10, 30), quantity: 20,
      unit: 'м²', hours: 30,
    ));
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: floor.id,
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('works-group-Стены')));
    await tester.pumpAndSettle();
    final work = find.byKey(const ValueKey('work-row-plaster'));
    await tester.ensureVisible(work);
    await tester.tap(work);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-inline-plaster')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-primary-plaster')), findsOneWidget);
    expect(find.text('Добавить объём'), findsOneWidget);
    expect(find.text('Сроки и зависимости'), findsNothing);
    await tester.tap(work);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-inline-plaster')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked work shows dependency instead of fake start button',
      (tester) async {
    final floor = FloorPlan(id: 'f', name: 'Этаж');
    final project = MeasureProject(id: 'blocks', name: 'Объект',
      floors: [floor]);
    final day = DateTime(2026, 10, 27);
    project.workBoard.tasks.addAll([
      WorkTask(id: 'rough', title: 'Черновые работы',
        floorId: floor.id, start: day, finish: day,
        quantity: 1, unit: 'шт', hours: 8),
      WorkTask(id: 'finish', title: 'Отделка стен',
        operationCode: 'wall_paint', floorId: floor.id,
        start: day, finish: day, quantity: 10, unit: 'м²',
        predecessorId: 'rough', hours: 14),
    ]);
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: floor.id,
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('works-group-Стены')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('work-row-finish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сначала примите'), findsOneWidget);
    expect(find.byKey(const ValueKey('work-primary-finish')), findsNothing);
    expect(find.text('Ожидает предыдущие этапы'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new task starts with essentials, advanced fields open inline',
      (tester) async {
    final project = MeasureProject(id: 'simple', name: 'Объект',
      floors: [FloorPlan(id: 'floor', name: 'Этаж')]);
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: 'floor',
      embedded: true, onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('works-add')));
    await tester.pumpAndSettle();
    expect(find.text('Новая работа'), findsOneWidget);
    expect(find.text('Выбрать операцию из библиотеки'), findsOneWidget);
    expect(find.text('Дополнительные параметры'), findsOneWidget);
    expect(find.text('Трудоёмкость, чел·ч'), findsNothing);
    await tester.ensureVisible(find.byKey(
      const ValueKey('works-more-details')));
    await tester.tap(find.byKey(const ValueKey('works-more-details')));
    await tester.pumpAndSettle();
    expect(find.text('Трудоёмкость, чел·ч'), findsOneWidget);
    expect(find.text('Исполнитель / бригада'), findsOneWidget);
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

  testWidgets('compact Control closes and reopens issues inline without duplicate defect',
      (tester) async {
    tester.view.physicalSize = const Size(393, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f1', name: 'Этаж 1');
    final project = MeasureProject(id: 'work-demo', name: 'Квартира',
      floors: [floor]);
    final work = WorkTask(
      id: 'tile-task', title: 'Укладка плитки',
      operationCode: 'floor_tile',
      floorId: floor.id,
      start: DateTime(2026, 10, 26),
      finish: DateTime(2026, 10, 30),
      quantity: 12, unit: 'м²', hours: 20);
    project.workBoard.tasks.add(work);
    project.workBoard.issues.add(WorkIssue(
      id: 'defect-1', title: 'Исправить уклон',
      taskId: work.id, createdAt: DateTime(2026, 10, 27)));
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: floor.id, embedded: true,
      onChanged: () async { saves++; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();
    expect(find.text('Исправить уклон'), findsOneWidget);
    // A linked defect is shown once, rather than as a second task card.
    expect(find.byKey(const ValueKey('work-row-tile-task')),
      findsNothing);
    await tester.tap(find.byKey(
      const ValueKey('works-issue-action-defect-1')));
    await tester.pumpAndSettle();
    expect(project.workBoard.issues.single.open, isFalse);
    expect(saves, 1);
    expect(find.text('Устранённые: 1'), findsOneWidget);
    expect(find.text('Исправить уклон'), findsNothing);
    await tester.tap(find.byKey(
      const ValueKey('works-closed-issues-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Исправить уклон'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('works-issue-action-defect-1')));
    await tester.pumpAndSettle();
    expect(project.workBoard.issues.single.open, isTrue);
    expect(saves, 2);
    expect(find.text('Устранённые: 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Control add button opens issue editor without another menu',
      (tester) async {
    final project = MeasureProject(id: 'p', name: 'Объект',
      floors: [FloorPlan(id: 'f', name: 'Этаж')]);
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, floorId: 'f', embedded: true,
      onChanged: () async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('works-add')));
    await tester.pumpAndSettle();
    expect(find.text('Новое замечание'), findsOneWidget);
    expect(find.text('Добавить работу'), findsNothing);
    expect(tester.takeException(), isNull);
  });


  test('a partially completed late job remains visible as overdue', () {
    final task = WorkTask(
      id: 'late', title: 'Шпаклёвка',
      start: DateTime(2026, 10, 1),
      finish: DateTime(2026, 10, 10),
      quantity: 30, unit: 'м²', hours: 20, done: 8,
    );
    final board = WorkBoard(tasks: [task]);
    expect(WorkStatusService.state(board, task,
      at: DateTime(2026, 10, 12)), WorkState.overdue);
    expect(WorkStatusService.state(board, task,
      at: DateTime(2026, 10, 9)), WorkState.inProgress);
    task.done = task.quantity;
    expect(WorkStatusService.state(board, task,
      at: DateTime(2026, 10, 12)), WorkState.awaitingAcceptance);
  });

}
