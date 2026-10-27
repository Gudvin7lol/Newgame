import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/budget_service.dart';
import 'package:zamer_app/services/geometry_service.dart';

FloorPlan room() {
  final floor = FloorPlan(
    id: 'f', name: 'Этаж',
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  test('new budget ledger defaults to empty and survives project JSON', () {
    final project = MeasureProject(id: 'p', name: 'Квартира');
    expect(BudgetService.review(project).actualTotal, 0);
    expect(BudgetService.review(project).completeEstimate, isFalse);
    expect(BudgetService.review(project).remainingIfFullyPriced, isNull);
    final paid = BudgetService.record(
      project,
      category: CostCategory.materials,
      amount: 4780,
      description: 'Плитка 2 коробки',
      at: DateTime(2026, 10, 28),
    );
    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.costEntries, hasLength(1));
    expect(restored.costEntries.single.id, paid.id);
    expect(restored.costEntries.single.description, 'Плитка 2 коробки');
    expect(restored.costEntries.single.at, DateTime(2026, 10, 28));
    expect(BudgetService.review(restored).actualMaterials, 4780);
    expect(MeasureProject.fromJson({
      'id': 'legacy',
      'name': 'Без журнала',
    }).costEntries, isEmpty);
  });

  test('paid labor links to an actual task without mutating its acceptance', () {
    final project = MeasureProject(id: 'p', name: 'Ремонт');
    final task = WorkTask(
      id: 'w1', title: 'Штукатурка', start: DateTime(2026, 10, 28),
      finish: DateTime(2026, 10, 29), quantity: 10,
      unit: 'м²', hours: 8, accepted: 4, done: 4,
    );
    project.workBoard.tasks.add(task);
    final entry = BudgetService.record(project,
      category: CostCategory.labor, description: 'Аванс мастеру',
      taskId: task.id, amount: 3200);
    expect(entry.taskId, task.id);
    expect(BudgetService.actualForTask(project, task.id), 3200);
    expect(BudgetService.review(project).actualLabor, 3200);
    expect(task.accepted, 4);
    expect(task.done, 4);
    expect(() => BudgetService.record(project,
      category: CostCategory.labor, description: 'Без работы',
      taskId: 'missing', amount: 500), throwsArgumentError);
  });

  test('cancel expense via compensation; preserve original audit record', () {
    final project = MeasureProject(id: 'p', name: 'Ремонт');
    final entry = BudgetService.record(project,
      category: CostCategory.materials,
      description: 'Ошибочный чек', amount: 2100,
      at: DateTime(2026, 10, 28, 10));
    final correction = BudgetService.voidRecord(project, entry.id,
        at: DateTime(2026, 10, 28, 11));
    expect(project.costEntries, hasLength(2));
    expect(project.costEntries.first.isReversal, isFalse);
    expect(correction.reversesId, entry.id);
    expect(correction.signedAmount, -2100);
    expect(BudgetService.review(project).actualTotal, 0);
    expect(() => BudgetService.voidRecord(project, entry.id),
      throwsStateError);
    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.costEntries.singleWhere(
        (entry) => entry.isReversal).reversesId, entry.id);
    expect(BudgetService.review(restored).actualTotal, 0);
  });

  test('reject zero negative NaN infinite costs and empty description', () {
    final project = MeasureProject(id: 'p', name: 'Проверка');
    for (final value in [0.0, -10.0, double.nan, double.infinity]) {
      expect(() => BudgetService.record(
        project, category: CostCategory.materials,
        description: 'Некорректно', amount: value), throwsArgumentError);
    }
    expect(() => BudgetService.record(
      project, category: CostCategory.materials,
      description: '  ', amount: 100), throwsArgumentError);
    expect(project.costEntries, isEmpty);
  });

  test('plan uses purchasing rather than material demand and marks missing prices', () {
    final floor = room();
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor],
      unitPrices: {
        'Ламинат / SPC|м²': 100,
      },
      workRates: {
        'Укладка ламината|м²': 500,
      },
    );
    final review = BudgetService.review(project);
    expect(review.plannedMaterials, greaterThan(0));
    expect(review.plannedLabor, greaterThan(0));
    expect(review.derivedPackagePrices, greaterThan(0));
    expect(review.completeEstimate, isFalse);
    expect(review.remainingIfFullyPriced, isNull);
    BudgetService.record(
      project, category: CostCategory.materials,
      amount: 300, description: 'Предоплата материалов');
    expect(BudgetService.review(project).actualTotal, 300);
  });
}
