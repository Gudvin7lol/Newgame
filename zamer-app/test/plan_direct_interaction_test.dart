import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/plan_direct_interaction.dart';

void main() {
  test('direct object drag moves and snaps furniture in plan space', () {
    final object = PlanObject(
      id: 'chair-1',
      type: PlanObjectType.furniture,
      xMm: 1000,
      yMm: 2000,
    );

    PlanDirectInteraction.moveObjectByMm(
      object,
      dxMm: 126,
      dyMm: -84,
    );

    expect(object.xMm, 1130);
    expect(object.yMm, 1920);
  });

  test('laminate layout drag changes physical offsets', () {
    final settings = RoomMaterialSettings(
      floorMode: 'laminate',
      floorDirectionDeg: 0,
      laminatePlankLengthMm: 1380,
      laminatePlankWidthMm: 193,
    );

    PlanDirectInteraction.shiftFloorLayout(
      settings,
      worldDxMm: 140,
      worldDyMm: 50,
    );

    expect(settings.laminateOffsetXMm, 140);
    expect(settings.laminateOffsetYMm, 50);
  });

  test('tile layout drag follows the selected direction', () {
    final settings = RoomMaterialSettings(
      floorMode: 'tile',
      floorTile: true,
      floorDirectionDeg: 90,
      tileWidthMm: 600,
      tileHeightMm: 600,
    );

    PlanDirectInteraction.shiftFloorLayout(
      settings,
      worldDxMm: 100,
      worldDyMm: 0,
    );

    expect(settings.tileOffsetXMm.abs(), lessThan(0.001));
    expect(settings.tileOffsetYMm, closeTo(500, 0.001));
  });
}
