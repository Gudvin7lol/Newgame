import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
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
}
