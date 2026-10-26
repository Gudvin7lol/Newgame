import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/screens/works_screen.dart';

void main() {
  testWidgets('work controls switch floor without editing geometry', (tester) async {
    final first = FloorPlan(id: 'floor-1', name: 'Этаж 1');
    final second = FloorPlan(id: 'floor-2', name: 'Этаж 2');
    final project = MeasureProject(
      id: 'test-object',
      name: 'Тестовый объект',
      floors: [first, second],
    );

    await tester.pumpWidget(MaterialApp(
      home: WorksScreen(
        project: project,
        onChanged: () async {},
      ),
    ));

    expect(find.text('План работ'), findsOneWidget);
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();

    final selector = find.byType(DropdownButton<String>);
    expect(selector, findsOneWidget);
    expect(tester.widget<DropdownButton<String>>(selector).value, 'floor-1');

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Этаж 2').last);
    await tester.pumpAndSettle();

    expect(tester.widget<DropdownButton<String>>(selector).value, 'floor-2');
    expect(project.floors.first.id, 'floor-1');
    expect(project.floors.last.id, 'floor-2');
  });

  testWidgets('single floor has no redundant selector', (tester) async {
    final project = MeasureProject(
      id: 'only',
      name: 'Один этаж',
      floors: [FloorPlan(id: 'f', name: 'Этаж 1')],
    );
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, onChanged: () async {},
    )));
    await tester.tap(find.text('Контроль'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('overcapacity is visible and crew capacity is editable',
      (tester) async {
    final project = MeasureProject(id: 'crew', name: 'Объект');
    final day = DateTime(2026, 11, 2);
    for (var i = 0; i < 2; i++) {
      project.workBoard.tasks.add(WorkTask(
        id: 'task-$i',
        title: 'Работа $i',
        start: day,
        finish: day,
        quantity: 10,
        unit: 'м²',
        hours: 8,
        assignee: 'Бригада А',
      ));
    }
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, onChanged: () async {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Перегрузка: 1'), findsOneWidget);
    await tester.tap(find.text('Подробнее').first);
    await tester.pumpAndSettle();
    expect(find.text('Загрузка бригад'), findsOneWidget);
    expect(find.text('Бригада А'), findsOneWidget);

    await tester.tap(find.text('Бригада А'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '16');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(project.workBoard.crewDailyHours['бригада а'], 16);
  });


  testWidgets('work library can search and select a specialized operation',
      (tester) async {
    final project = MeasureProject(
      id: 'catalogue', name: 'Каталог работ',
      floors: [FloorPlan(id: 'f', name: 'Этаж 1')],
    );
    await tester.pumpWidget(MaterialApp(
      home: WorksScreen(project: project, onChanged: () async {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить работу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать операцию из библиотеки'));
    await tester.pumpAndSettle();
    expect(find.text('Библиотека работ'), findsOneWidget);
    expect(find.text('Стены'), findsOneWidget);
    expect(find.text('Пол'), findsOneWidget);
    expect(find.text('Потолок'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Электрика'), 120.0,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Электрика'));
    await tester.pumpAndSettle();
    expect(find.text('Найдено: 34'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'УЗО');
    await tester.pumpAndSettle();
    expect(find.text('Проверка УЗО и дифавтоматов'), findsOneWidget);
    await tester.tap(find.text('Проверка УЗО и дифавтоматов'));
    await tester.pumpAndSettle();
    // The selected operation is shown both on the picker button and
    // in the editable task-title field.
    expect(find.text('Проверка УЗО и дифавтоматов'), findsWidgets);
    expect(project.workBoard.tasks, isEmpty);
  });

}
