import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/procurement_service.dart';
import 'package:zamer_app/services/budget_service.dart';

FloorPlan floorRoom() {
  final floor = FloorPlan(
    id: 'f', name: 'Первый этаж',
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
  test('buying whole packs reduces remaining and survives a JSON backup', () {
    final project = MeasureProject(
      id: 'p', name: 'Комната', floors: [floorRoom()]);
    final laminate = ProcurementService.coverage(project)
        .singleWhere((row) => row.line.name == 'Ламинат / SPC');
    expect(laminate.line.unit, 'пач.');
    expect(laminate.line.quantity, 5);
    expect(laminate.remaining, 5);

    final purchase = ProcurementService.record(project,
      estimateKey: laminate.line.key, quantity: 3,
      note: 'Первая закупка', at: DateTime(2026, 10, 28));
    expect(purchase.isReversal, isFalse);
    final after = ProcurementService.coverage(project)
        .singleWhere((row) => row.line.key == laminate.line.key);
    expect(after.purchased, 3);
    expect(after.remaining, 2);

    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.materialPurchases, hasLength(1));
    expect(restored.materialPurchases.single.note, 'Первая закупка');
    expect(ProcurementService.purchasedFor(restored, laminate.line.key), 3);
  });

  test('overbuying is visible, cancelling keeps audit history', () {
    final project = MeasureProject(id: 'p', name: 'Ремонт',
        floors: [floorRoom()]);
    final row = ProcurementService.coverage(project).firstWhere(
        (row) => row.line.name == 'Ламинат / SPC');
    final bought = ProcurementService.record(project,
        estimateKey: row.line.key, quantity: 7);
    var reviewed = ProcurementService.coverage(project)
        .singleWhere((item) => item.line.key == row.line.key);
    expect(reviewed.extra, 2);
    expect(reviewed.remaining, 0);
    expect(reviewed.complete, isTrue);

    final correction = ProcurementService.voidRecord(
        project, bought.id);
    expect(correction.reversesId, bought.id);
    expect(project.materialPurchases, hasLength(2));
    expect(ProcurementService.purchasedFor(project, row.line.key), 0);
    reviewed = ProcurementService.coverage(project)
        .singleWhere((item) => item.line.key == row.line.key);
    expect(reviewed.remaining, 5);
    expect(() => ProcurementService.voidRecord(project, bought.id),
        throwsStateError);
  });

  test('fractional package or unknown estimate key is rejected', () {
    final project = MeasureProject(id: 'p', name: 'Объект',
        floors: [floorRoom()]);
    final row = ProcurementService.coverage(project).firstWhere(
        (row) => row.line.name == 'Ламинат / SPC');
    for (final quantity in [0.0, -1.0, double.nan, double.infinity, 1.5]) {
      expect(() => ProcurementService.record(project,
          estimateKey: row.line.key, quantity: quantity),
          throwsArgumentError);
    }
    expect(() => ProcurementService.record(project,
        estimateKey: 'not-a-real-line', quantity: 1),
        throwsArgumentError);
    expect(project.materialPurchases, isEmpty);
  });

  test('pack specification changes preserve old receipts for reconciliation', () {
    final project = MeasureProject(id: 'p', name: 'Объект',
        floors: [floorRoom()]);
    final previous = ProcurementService.coverage(project).firstWhere(
        (row) => row.line.name == 'Ламинат / SPC').line;
    ProcurementService.record(project,
        estimateKey: previous.key, quantity: 2);
    project.floors.single.roomMetas.single.materials.floorPackageM2 = 2.5;
    final current = ProcurementService.coverage(project).firstWhere(
        (row) => row.line.name == 'Ламинат / SPC');
    expect(current.line.key, isNot(previous.key));
    expect(current.purchased, 0);
    expect(ProcurementService.unlinked(project), hasLength(1));
    expect(project.materialPurchases.single.estimateKey, previous.key);
  });

  test('purchased packs are not double-counted as paid money', () {
    final project = MeasureProject(id: 'p', name: 'Ремонт',
        floors: [floorRoom()]);
    final line = ProcurementService.coverage(project).firstWhere(
        (row) => row.line.name == 'Ламинат / SPC').line;
    ProcurementService.record(project,
        estimateKey: line.key, quantity: 3);
    expect(BudgetService.review(project).actualMaterials, 0);
    BudgetService.record(project,
        category: CostCategory.materials,
        description: 'Оплата ламината', amount: 2400);
    expect(BudgetService.review(project).actualMaterials, 2400);
    expect(ProcurementService.purchasedFor(project, line.key), 3);
    expect(MeasureProject.fromJson({
      'id': 'legacy', 'name': 'Old',
    }).materialPurchases, isEmpty);
  });
}
