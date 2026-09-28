import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/space_check_service.dart';

void main() {
  test('rotated furniture collision respects height and demolition', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.planObjects.addAll([
      PlanObject(
        id: 'a',
        type: PlanObjectType.furniture,
        xMm: 0,
        yMm: 0,
        widthMm: 800,
        depthMm: 800,
        heightMm: 800,
      ),
      PlanObject(
        id: 'b',
        type: PlanObjectType.furniture,
        xMm: 500,
        yMm: 0,
        widthMm: 500,
        depthMm: 500,
        heightMm: 800,
        rotationDeg: 45,
      ),
    ]);
    expect(SpaceCheckService.inspect(floor).length, 1);
    floor.planObjects.last.elevationMm = 900;
    expect(SpaceCheckService.inspect(floor), isEmpty);
    floor.planObjects.last.elevationMm = 0;
    floor.planObjects.last.layer = ProjectLayer.demolition;
    expect(SpaceCheckService.inspect(floor), isEmpty);
  });

  test('door reports obstruction near threshold, not distant object', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
    ]);
    floor.walls.add(
      PlanWall(
        id: 'w',
        startNodeId: 'a',
        endNodeId: 'b',
        openings: [
          WallOpening(
            id: 'd',
            type: OpeningType.door,
            widthMm: 800,
            heightMm: 2100,
            offsetFromStartMm: 1000,
          ),
        ],
      ),
    );
    final object = PlanObject(
      id: 'chair',
      type: PlanObjectType.furniture,
      xMm: 1400,
      yMm: 400,
      widthMm: 300,
      depthMm: 300,
    );
    floor.planObjects.add(object);
    expect(
      SpaceCheckService.inspect(floor).single.description,
      contains('Проход'),
    );
    object.yMm = 1500;
    expect(SpaceCheckService.inspect(floor), isEmpty);
  });
}
