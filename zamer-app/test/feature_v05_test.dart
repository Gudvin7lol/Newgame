import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('radius wall is generated as connected structural segments', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.nodes.add(PlanNode(id: 'a', xMm: 0, yMm: 0));
    final end = GeometryService.addArcWallFromNode(
      f,
      startNodeId: 'a',
      endPoint: const math.Point<double>(4000, 0),
      sagittaMm: 1000,
      type: WallType.exterior,
      thicknessMm: 300,
      material: WallMaterial.gasBlock,
    );
    expect(f.walls.length, greaterThanOrEqualTo(4));
    expect(end.xMm, closeTo(4000, 90));
    expect(end.yMm, closeTo(0, 90));
    for (final w in f.walls) {
      expect(f.nodeById(w.startNodeId), isNotNull);
      expect(f.nodeById(w.endNodeId), isNotNull);
    }
  });

  test('electrical data survives floor json round trip', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.electricalPoints.add(ElectricalPoint(
      id: 'p1',
      type: ElectricalPointType.switchPoint,
      xMm: 100,
      yMm: 200,
      circuit: 'Свет 1',
      heightMm: 900,
    ));
    f.electricalPoints.add(ElectricalPoint(
      id: 'p2',
      type: ElectricalPointType.ceilingLight,
      xMm: 1000,
      yMm: 1200,
      circuit: 'Свет 1',
      heightMm: 2700,
    ));
    f.electricalRuns.add(ElectricalRun(id: 'r1', startPointId: 'p1', endPointId: 'p2'));
    final copy = FloorPlan.fromJson(f.toJson());
    expect(copy.electricalPoints.length, 2);
    expect(copy.electricalRuns.length, 1);
    expect(copy.electricalPoints.first.circuit, 'Свет 1');
  });
}
