import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/scene_fingerprint.dart';
import 'package:zamer_app/services/demo_project_factory.dart';

void main() {
  FloorPlan freshFloor() => DemoProjectFactory.create().floors.single;

  void expectMutationChanges(void Function(FloorPlan floor) mutate) {
    final floor = freshFloor();
    final before = ZamerSceneFingerprint.of(floor);
    mutate(floor);
    expect(ZamerSceneFingerprint.of(floor), isNot(before));
  }

  test('opening sill and door swing invalidate the GPU scene', () {
    expectMutationChanges((floor) {
      final window = floor.walls
          .expand((wall) => wall.openings)
          .firstWhere((opening) => opening.type == OpeningType.window);
      window.sillHeightMm += 75;
    });
    expectMutationChanges((floor) {
      final door = floor.walls
          .expand((wall) => wall.openings)
          .firstWhere((opening) => opening.type == OpeningType.door);
      door.doorSwing = door.doorSwing == DoorSwing.leftIn
          ? DoorSwing.rightIn
          : DoorSwing.leftIn;
    });
  });

  test('room height and floor phase anchor invalidate the GPU scene', () {
    expectMutationChanges((floor) {
      final room = floor.roomMetas.first;
      room.ceilingHeightMm = (room.ceilingHeightMm ?? floor.defaultHeightMm) + 50;
    });
    expectMutationChanges((floor) {
      floor.carpetAnchorX += 125;
      floor.carpetAnchorY -= 80;
      floor.carpetRoomIds
        ..clear()
        ..addAll(floor.roomMetas.take(2).map((room) => room.id));
    });
  });

  test('wall layer and curve metadata invalidate the GPU scene', () {
    expectMutationChanges((floor) {
      floor.walls.first.projectLayer = ProjectLayer.demolition;
    });
    expectMutationChanges((floor) {
      final wall = floor.walls.first;
      wall.curveGroupId = 'fingerprint-curve';
      wall.curveRadiusMm = 2400;
      wall.curveSagittaMm = 180;
      wall.curveArcLengthMm = 1500;
    });
  });

  test('object type and layer invalidate the GPU scene', () {
    expectMutationChanges((floor) {
      final object = floor.planObjects.first;
      object.layer = ProjectLayer.demolition;
    });
    expectMutationChanges((floor) {
      final object = floor.planObjects.first;
      object.type = PlanObjectType.lighting;
    });
  });

  test('electrical placement and module state invalidate the GPU scene', () {
    expectMutationChanges((floor) {
      final point = floor.electricalPoints.first;
      point.xMm += 100;
      point.heightMm += 50;
      point.wallSide *= -1;
    });
    expectMutationChanges((floor) {
      final point = floor.electricalPoints.first;
      point.modules.add(ElectricalModuleType.data);
      point.frameVertical = !point.frameVertical;
    });
  });
}
