import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/opening_alignment_service.dart';

WallOpening opening(String id, double position, double width) => WallOpening(
  id: id, type: OpeningType.door, widthMm: width,
  heightMm: 2100, offsetFromStartMm: position,
);

void main() {
  test('opening options allow exact centre and opposite-door alignment', () {
    final plan = FloorPlan(id: 'f', name: 'Floor', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 5000, yMm: 0),
      PlanNode(id: 'c', xMm: 0, yMm: 2000),
      PlanNode(id: 'd', xMm: 5000, yMm: 2000),
    ], walls: [
      PlanWall(id: 'host', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'across', startNodeId: 'c', endNodeId: 'd',
        openings: [opening('other', 2500, 800)]),
    ]);
    final options = OpeningAlignmentService.targets(
      plan, plan.walls.first,
      desiredOffsetMm: 400, openingWidthMm: 900,
      toleranceMm: 5000,
    );
    expect(options.any((x) =>
      x.label == 'Центр стены' && x.offsetMm == 2050), isTrue);
    expect(options.any((x) =>
      x.label == 'По оси двери напротив' && x.offsetMm == 2450), isTrue);
  });

  test('a real intermediate wall junction creates a segment midpoint', () {
    final plan = FloorPlan(id: 'f', name: 'Floor', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 6000, yMm: 0),
      PlanNode(id: 'junction', xMm: 2000, yMm: 0),
      PlanNode(id: 'far', xMm: 2000, yMm: 2500),
      PlanNode(id: 'down', xMm: 2000, yMm: -1600),
    ], walls: [
      PlanWall(id: 'host', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'j1', startNodeId: 'junction', endNodeId: 'far'),
      PlanWall(id: 'j2', startNodeId: 'junction', endNodeId: 'down'),
    ]);
    final options = OpeningAlignmentService.targets(
      plan, plan.walls.first,
      desiredOffsetMm: 510, openingWidthMm: 900,
    );
    expect(options.any((x) =>
      x.label == 'Центр участка стены' && x.offsetMm == 550), isTrue);
  });
}
