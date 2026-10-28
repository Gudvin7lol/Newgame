import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/estimate_service.dart';
import 'package:zamer_app/services/geometry_service.dart';

FloorPlan sampleFloor(String id, {double packageM2 = 2.2}) {
  final floor = FloorPlan(
    id: id, name: 'Этаж',
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  floor.roomMetas.single.materials.floorPackageM2 = packageM2;
  return floor;
}

void main() {
  test('round compatible purchases after aggregation across rooms', () {
    final project = MeasureProject(
      id: 'p', name: 'Квартира',
      floors: [sampleFloor('f1'), sampleFloor('f2')],
      unitPrices: {'Ламинат / SPC|м²': 100},
    );
    final consumption = EstimateService.build(project);
    final purchases = EstimateService.buildPurchases(project);
    final demand = consumption.lines.singleWhere(
        (line) => line.name == 'Ламинат / SPC');
    final packs = purchases.lines.singleWhere(
        (line) => line.name == 'Ламинат / SPC');
    final expected = (demand.quantity / 2.2 - 1e-9).ceil();

    expect(packs.unit, 'пач.');
    expect(packs.quantity, expected);
    expect(packs.quantity, 9);
    expect(packs.detail, contains('2.20'));
    expect(packs.derivedPrice, isTrue);
    expect(packs.unitPrice, closeTo(220, 0.001));
    expect(packs.total, closeTo(1980, 0.001));
    expect(packs.total, greaterThan(demand.total));
    // Per-room rounding would have yielded 10 packs.
    expect(packs.quantity, lessThan(10));
  });

  test('different package capacities are never mixed into one purchase', () {
    final project = MeasureProject(
      id: 'p', name: 'Два этажа',
      floors: [sampleFloor('f1'), sampleFloor('f2', packageM2: 2.5)],
    );
    final purchases = EstimateService.buildPurchases(project).lines
        .where((line) => line.name == 'Ламинат / SPC').toList();
    expect(purchases, hasLength(2));
    expect(purchases.map((line) => line.key).toSet().length, 2);
    expect(purchases.map((line) => line.quantity), containsAll([5, 4]));
  });

  test('explicit package price overrides derived source-unit price', () {
    final project = MeasureProject(
      id: 'p', name: 'Квартира',
      floors: [sampleFloor('f1'), sampleFloor('f2')],
      unitPrices: {'Ламинат / SPC|м²': 100},
    );
    final initial = EstimateService.buildPurchases(project).lines
        .singleWhere((line) => line.name == 'Ламинат / SPC');
    expect(initial.derivedPrice, isTrue);
    project.unitPrices[initial.key] = 350;
    final restored = MeasureProject.fromJson(project.toJson());
    final priced = EstimateService.buildPurchases(restored).lines
        .singleWhere((line) => line.name == 'Ламинат / SPC');
    expect(priced.derivedPrice, isFalse);
    expect(priced.unitPrice, 350);
    expect(priced.quantity, 9);
    expect(priced.total, 3150);
    expect(EstimateService.build(restored).lines
        .singleWhere((line) => line.name == 'Ламинат / SPC')
        .unitPrice, 100);
  });

  test('unconfigured package size does not invent a pack count', () {
    final project = MeasureProject(
      id: 'p', name: 'Проект',
      floors: [sampleFloor('f1', packageM2: 0)],
    );
    final purchases = EstimateService.buildPurchases(project).lines
        .singleWhere((line) => line.name == 'Ламинат / SPC');
    final demand = EstimateService.build(project).lines
        .singleWhere((line) => line.name == 'Ламинат / SPC');
    expect(purchases.unit, 'м²');
    expect(purchases.quantity, closeTo(demand.quantity, 0.001));
    expect(purchases.detail, contains('упаковка не задана'));
  });
}
