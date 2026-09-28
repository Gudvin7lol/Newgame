import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/estimate_service.dart';

void main() {
  test(
    'labor rates are separate from material prices and survive revision',
    () {
      final floor = FloorPlan(id: 'f', name: 'F');
      floor.nodes.addAll([
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 3000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ]);
      floor.walls.addAll([
        PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
      ]);
      final project = MeasureProject(
        id: 'p',
        name: 'P',
        floors: [floor],
        workRates: {'Укладка ламината|м²': 500},
        unitPrices: {'Укладка ламината|м²': 42},
      );
      final result = EstimateService.buildWork(
        MeasureProject.fromJson(project.toJson()),
      );
      final line = result.lines.singleWhere(
        (e) => e.name == 'Укладка ламината',
      );
      expect(line.quantity, closeTo(8.41, .01));
      expect(line.total, closeTo(4205, 1));
      expect(result.unpricedCount, greaterThan(0));
    },
  );
}
