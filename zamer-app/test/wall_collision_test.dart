import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/space_check_service.dart';

void main() {
  test(
    'rotated furniture intersecting wall is found; nearby object is clear',
    () {
      final floor = FloorPlan(id: 'f', name: 'F');
      floor.nodes.addAll([
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
      ]);
      floor.walls.add(
        PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 120),
      );
      final sofa = PlanObject(
        id: 'sofa',
        type: PlanObjectType.furniture,
        xMm: 1200,
        yMm: 150,
        widthMm: 1500,
        depthMm: 600,
        rotationDeg: 12,
      );
      floor.planObjects.add(sofa);
      expect(SpaceCheckService.intersectsWall(floor, sofa), true);
      expect(
        SpaceCheckService.inspect(floor).single.description,
        contains('стену'),
      );
      sofa.yMm = 900;
      expect(SpaceCheckService.intersectsWall(floor, sofa), false);
    },
  );
}
