import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/budget_service.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/procurement_service.dart';
import 'package:zamer_app/services/project_financial_report_service.dart';

MeasureProject site() {
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
  return MeasureProject(
    id: 'p', name: 'Квартира', floors: [floor],
    workRates: {'Укладка ламината|м²': 500},
  );
}

void main() {
  test('site report totals count a paid purchase once and isolate accepted work', () {
    final project = site();
    project.workBoard.tasks.add(WorkTask(
      id: 'w1', title: 'Укладка ламината',
      operationCode: 'floor_laminate',
      start: DateTime(2026, 10, 28),
      finish: DateTime(2026, 10, 29),
      quantity: 8, unit: 'м²', hours: 10,
      done: 6, accepted: 4,
    ));
    final row = ProcurementService.coverage(project).firstWhere(
        (item) => item.line.name == 'Ламинат / SPC');
    final purchase = ProcurementService.recordWithPayment(
      project, estimateKey: row.line.key,
      quantity: 2, paidAmount: 2400,
      at: DateTime(2026, 10, 28, 10),
    );
    final payment = BudgetService.record(
      project, category: CostCategory.labor, taskId: 'w1',
      description: 'Аванс работнику', amount: 1300,
      at: DateTime(2026, 10, 28, 11),
    );
    BudgetService.voidRecord(project, payment.id,
        at: DateTime(2026, 10, 28, 12));

    final report = ProjectFinancialReportService.build(
        project, at: DateTime(2026, 10, 28, 13));
    expect(report.budget.actualMaterials, 2400);
    expect(report.budget.actualLabor, 0);
    expect(report.budget.actualTotal, 2400);
    expect(report.workValue.acceptedPricedValue, 2000);
    expect(report.works.single.accepted, 4);
    expect(report.works.single.paid, 0);
    expect(report.purchaseEntries, hasLength(1));
    expect(report.cashEntries, hasLength(3));
    expect(report.unpaidLinkedPurchases, 0);
    expect(report.underboughtPositions, greaterThan(0));

    final csv = report.toCsv();
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('ЖУРНАЛ ОПЛАТ'));
    expect(csv, contains('ЖУРНАЛ КОЛИЧЕСТВ'));
    expect(csv, contains(purchase.id));
    expect(csv, contains(payment.id));
    expect(csv, contains('-1300.00'));
    expect(csv, contains('Принято работ по известным ставкам;2000.00'));
    // No second financial charge for the quantity record.
    expect(csv, contains('Оплачено всего;2400.00'));
  });

  test('missing rates and changing pack sizes are flagged, not settled', () {
    final project = site();
    final line = ProcurementService.coverage(project).firstWhere(
        (item) => item.line.name == 'Ламинат / SPC').line;
    final receipt = ProcurementService.record(
        project, estimateKey: line.key, quantity: 3);
    project.floors.single.roomMetas.single.materials.floorPackageM2 = 2.5;
    project.workBoard.tasks.add(WorkTask(
      id: 'manual', title: 'Спецработа', start: DateTime(2026, 10, 28),
      finish: DateTime(2026, 10, 29), quantity: 4,
      unit: 'м²', hours: 5, accepted: 2, done: 2,
      needsQuantityReview: true,
    ));
    var report = ProjectFinancialReportService.build(project);
    expect(report.unlinkedActivePurchases, 1);
    expect(report.workValue.unpricedAcceptedTasks, 1);
    expect(report.workValue.flaggedAcceptedTasks, 1);
    expect(report.budget.completeEstimate, isFalse);
    expect(report.budget.remainingIfFullyPriced, isNull);
    expect(report.toCsv(), contains('Не определена: смета неполная'));
    ProcurementService.voidRecord(project, receipt.id);
    report = ProjectFinancialReportService.build(project);
    expect(report.unlinkedActivePurchases, 0);
  });

  test('CSV quotes semicolons and neutralizes spreadsheet injection', () {
    final project = site();
    project.name = '=HYPERLINK("https://evil.invalid")';
    BudgetService.record(
      project, category: CostCategory.materials,
      description: '+2;"Плитка"\nпокупка',
      amount: 1800,
    );
    final csv = ProjectFinancialReportService.build(project).toCsv();
    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains('"\'+2;""Плитка""\nпокупка"'));
    expect(csv, contains('1800.00'));
  });

  test('export snapshot does not change after new project entries', () {
    final project = site();
    final report = ProjectFinancialReportService.build(
        project, at: DateTime(2026, 10, 28, 9));
    final original = report.toCsv();
    BudgetService.record(
      project, category: CostCategory.materials,
      description: 'Клей', amount: 500,
    );
    expect(report.toCsv(), original);
    expect(report.budget.actualTotal, 0);
    final next = ProjectFinancialReportService.build(project);
    expect(next.budget.actualTotal, 500);
    expect(next.toCsv(), contains('500.00'));
  });

  test('empty object produces a preliminary, not balanced, report', () {
    final project = MeasureProject(id: 'empty', name: 'Пустой объект');
    final report = ProjectFinancialReportService.build(project);
    expect(report.budget.completeEstimate, isFalse);
    expect(report.budget.plannedPositions, 0);
    expect(report.purchases, isEmpty);
    expect(report.works, isEmpty);
    expect(report.budget.actualTotal, 0);
    expect(report.toCsv(), contains('Предварительный'));
  });
}
