import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/screens/budget_screen.dart';
import 'package:zamer_app/services/work_value_service.dart';

void main() {
  testWidgets('accepted work can receive its own price from budget screen',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = MeasureProject(id: 'p', name: 'Ремонт');
    final task = WorkTask(
      id: 'custom-1', title: 'Ручная работа', roomName: 'Комната',
      start: DateTime(2026, 10, 28),
      finish: DateTime(2026, 10, 29),
      quantity: 10, unit: 'м²', hours: 10,
      done: 4, accepted: 4,
    );
    project.workBoard.tasks.add(task);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: BudgetScreen(
        project: project,
        onChanged: () async { saves++; },
      ),
    ));

    expect(WorkValueService.review(project).unpricedAcceptedTasks, 1);
    await tester.tap(find.text('Задать расценки принятых работ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ручная работа · Комната'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('accepted-task-rate')), '600');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(project.workRates['task:custom-1|м²'], 600);
    expect(WorkValueService.review(project).unpricedAcceptedTasks, 0);
    expect(WorkValueService.review(project).acceptedPricedValue, 2400);
    expect(task.accepted, 4);
    expect(saves, 1);
  });
}
