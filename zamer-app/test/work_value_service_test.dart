import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/services/budget_service.dart';
import 'package:zamer_app/services/work_value_service.dart';

WorkTask work(
  String id, String title, String code, {
  double quantity = 10,
  double done = 0,
  double accepted = 0,
  bool needsReview = false,
}) => WorkTask(
  id: id, title: title, operationCode: code,
  start: DateTime(2026, 10, 28),
  finish: DateTime(2026, 10, 29),
  unit: 'м²', hours: 10, quantity: quantity,
  done: done, accepted: accepted,
  needsQuantityReview: needsReview,
);

void main() {
  test('accepted amounts are priced by existing labor rates, not paid cash', () {
    final project = MeasureProject(
      id: 'p', name: 'Объект',
      workRates: {
        'Укладка ламината|м²': 500,
        'Покраска стен|м²': 300,
      },
    );
    project.workBoard.tasks.addAll([
      work('laminate', 'Укладка ламината', 'floor_laminate',
          quantity: 10, done: 7, accepted: 5),
      work('paint', 'Окраска стен', 'wall_paint',
          quantity: 20, done: 8, accepted: 3),
      work('misc', 'Ручная работа', 'manual',
          quantity: 2, done: 1, accepted: 1),
    ]);
    BudgetService.record(project,
        category: CostCategory.labor,
        description: 'Аванс мастеру', amount: 1200);
    var result = WorkValueService.review(project);
    expect(result.acceptedPricedValue, 3400);
    expect(result.completedPricedValue, 5900);
    expect(result.paidLabor, 1200);
    expect(result.unpricedAcceptedTasks, 1);
    expect(result.allAcceptedPriced, isFalse);
    expect(result.acceptedMinusPayments, isNull);

    // An explicit task rate can price an otherwise unpriced manual task.
    project.workRates['task:misc|м²'] = 200;
    result = WorkValueService.review(project);
    expect(result.acceptedPricedValue, 3600);
    expect(result.unpricedAcceptedTasks, 0);
    expect(result.acceptedMinusPayments, 2400);
    expect(result.paidLabor, 1200);
    expect(project.workBoard.tasks[0].accepted, 5);
  });

  test('accepted quantities never exceed planned scope in valuation', () {
    final project = MeasureProject(id: 'p', name: 'Ремонт',
        workRates: {'Укладка плитки пола|м²': 1000});
    final task = work('tile', 'Укладка плитки пола', 'floor_tile',
        quantity: 8, done: 12, accepted: 9, needsReview: true);
    project.workBoard.tasks.add(task);
    final result = WorkValueService.review(project);
    expect(result.acceptedPricedValue, 8000);
    expect(result.completedPricedValue, 8000);
    expect(result.flaggedAcceptedTasks, 1);
    expect(task.accepted, 9); // Never silently rewrite recorded facts.
    expect(task.done, 12);
  });

  test('labor payment reversal affects cash without changing acceptance', () {
    final project = MeasureProject(
        id: 'p', name: 'Объект',
        workRates: {'Укладка ламината|м²': 400});
    final task = work('t', 'Укладка ламината', 'floor_laminate',
        accepted: 4, done: 4);
    project.workBoard.tasks.add(task);
    final paid = BudgetService.record(project,
        category: CostCategory.labor,
        description: 'Оплата работ', amount: 500);
    expect(WorkValueService.review(project).acceptedPricedValue, 1600);
    expect(WorkValueService.review(project).paidLabor, 500);
    BudgetService.voidRecord(project, paid.id);
    expect(WorkValueService.review(project).paidLabor, 0);
    expect(WorkValueService.review(project).acceptedPricedValue, 1600);
    expect(task.accepted, 4);
  });
}
