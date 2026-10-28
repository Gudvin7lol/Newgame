import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/services/budget_service.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/procurement_service.dart';

MeasureProject sample() {
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
  return MeasureProject(id: 'p', name: 'Квартира', floors: [floor]);
}

String laminateKey(MeasureProject project) =>
    ProcurementService.coverage(project)
        .firstWhere((item) => item.line.name == 'Ламинат / SPC').line.key;

void main() {
  test('a single receipt records quantity and actual payment exactly once', () {
    final project = sample();
    final key = laminateKey(project);
    final bought = ProcurementService.recordWithPayment(
      project,
      estimateKey: key,
      quantity: 3,
      paidAmount: 2600,
      at: DateTime(2026, 10, 28),
    );
    expect(project.materialPurchases, hasLength(1));
    expect(project.costEntries, hasLength(1));
    expect(project.costEntries.single.purchaseId, bought.id);
    expect(project.costEntries.single.estimateKey, key);
    expect(project.costEntries.single.category, CostCategory.materials);
    expect(ProcurementService.purchasedFor(project, key), 3);
    expect(ProcurementService.paidForPurchase(project, bought.id), 2600);
    expect(BudgetService.review(project).actualMaterials, 2600);
    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.costEntries.single.purchaseId, bought.id);
    expect(restored.materialPurchases.single.id, bought.id);
    expect(BudgetService.review(restored).actualMaterials, 2600);
    expect(ProcurementService.paidForPurchase(restored, bought.id), 2600);
  });

  test('unpaid receipt changes quantities but not the financial fact', () {
    final project = sample();
    final purchase = ProcurementService.recordWithPayment(
      project,
      estimateKey: laminateKey(project),
      quantity: 2,
    );
    expect(ProcurementService.paidForPurchase(project, purchase.id), 0);
    expect(project.costEntries, isEmpty);
    expect(BudgetService.review(project).actualTotal, 0);
  });

  test('bad amounts fail before either ledger is mutated', () {
    final project = sample();
    final key = laminateKey(project);
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => ProcurementService.recordWithPayment(
        project,
        estimateKey: key,
        quantity: 2,
        paidAmount: invalid,
      ), throwsArgumentError);
    }
    expect(project.materialPurchases, isEmpty);
    expect(project.costEntries, isEmpty);
  });

  test('linked manual payments are validated and cannot duplicate purchase', () {
    final project = sample();
    final purchase = ProcurementService.record(
      project, estimateKey: laminateKey(project), quantity: 2);
    final payment = BudgetService.record(
      project,
      category: CostCategory.materials,
      amount: 1800,
      description: 'Первый чек',
      purchaseId: purchase.id,
    );
    expect(payment.purchaseId, purchase.id);
    expect(() => BudgetService.record(
      project,
      category: CostCategory.materials,
      amount: 1800,
      description: 'Двойной чек',
      purchaseId: purchase.id,
    ), throwsStateError);
    expect(() => BudgetService.record(
      project,
      category: CostCategory.labor,
      amount: 500,
      description: 'Работа',
      purchaseId: purchase.id,
    ), throwsArgumentError);
    expect(project.costEntries, hasLength(1));
    final cancellation = BudgetService.voidRecord(project, payment.id);
    expect(cancellation.purchaseId, purchase.id);
    expect(ProcurementService.paidForPurchase(project, purchase.id), 0);
    expect(BudgetService.review(project).actualMaterials, 0);
    // An erroneously entered payment can be replaced by another receipt.
    BudgetService.record(
      project,
      category: CostCategory.materials,
      amount: 1900,
      description: 'Исправленный чек',
      purchaseId: purchase.id,
    );
    expect(ProcurementService.paidForPurchase(project, purchase.id), 1900);
  });

  test('cancelling quantity never invents a monetary refund', () {
    final project = sample();
    final purchase = ProcurementService.recordWithPayment(
      project,
      estimateKey: laminateKey(project),
      quantity: 2,
      paidAmount: 1200,
    );
    ProcurementService.voidRecord(project, purchase.id);
    expect(ProcurementService.purchasedFor(
        project, purchase.estimateKey), 0);
    expect(ProcurementService.paidForPurchase(
        project, purchase.id), 1200);
    expect(BudgetService.review(project).actualMaterials, 1200);
    expect(() => BudgetService.record(
      project,
      category: CostCategory.materials,
      amount: 400,
      description: 'Ещё один платёж',
      purchaseId: purchase.id,
    ), throwsArgumentError);
  });
}
