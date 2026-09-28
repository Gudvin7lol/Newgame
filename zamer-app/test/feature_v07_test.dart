import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';

void main() {
  test('v0.7 finish settings survive JSON round trip', () {
    final s = RoomMaterialSettings(
      laminatePattern: 'herringbone',
      laminateOffsetXMm: 125,
      laminateOffsetYMm: -70,
      underlayMode: 'sheet',
      underlaySheetWidthMm: 500,
      underlaySheetHeightMm: 1000,
      underlayOffsetXMm: 35,
      underlayOffsetYMm: 45,
      tilePattern: 'diagonal',
      tileOffsetXMm: 210,
      tileOffsetYMm: 130,
      wallTile: true,
      wallTileWidthMm: 600,
      wallTileHeightMm: 300,
      wallTileOffsetXMm: 75,
      wallTileOffsetYMm: 40,
      wallTileFromMm: 150,
      wallTileToMm: 2400,
      wallPaintColorArgb: 0xFF7A8B9C,
      wallTileTintArgb: 0xFFDDEEFF,
    );

    final copy = RoomMaterialSettings.fromJson(s.toJson());
    expect(copy.laminatePattern, 'herringbone');
    expect(copy.laminateOffsetXMm, 125);
    expect(copy.laminateOffsetYMm, -70);
    expect(copy.underlayMode, 'sheet');
    expect(copy.underlaySheetWidthMm, 500);
    expect(copy.underlaySheetHeightMm, 1000);
    expect(copy.tilePattern, 'diagonal');
    expect(copy.wallTile, isTrue);
    expect(copy.wallTileToMm, 2400);
    expect(copy.wallPaintColorArgb, 0xFF7A8B9C);
    expect(copy.wallTileTintArgb, 0xFFDDEEFF);
  });

  test('electrical frame, heights and wall binding survive JSON', () {
    final floor = FloorPlan(
      id: 'f',
      name: 'Этаж 1',
      defaultSocketHeightMm: 320,
      defaultSwitchHeightMm: 920,
      defaultWallLightHeightMm: 1850,
    );
    floor.electricalPoints.add(ElectricalPoint(
      id: 'ep1',
      type: ElectricalPointType.frame,
      xMm: 1000,
      yMm: 0,
      heightMm: 330,
      wallId: 'w1',
      wallOffsetMm: 1000,
      modules: const [
        ElectricalModuleType.socket220,
        ElectricalModuleType.tv,
        ElectricalModuleType.data,
        ElectricalModuleType.switch1,
      ],
    ));

    final copy = FloorPlan.fromJson(floor.toJson());
    expect(copy.defaultSocketHeightMm, 320);
    expect(copy.defaultSwitchHeightMm, 920);
    expect(copy.defaultWallLightHeightMm, 1850);
    final p = copy.electricalPoints.single;
    expect(p.type, ElectricalPointType.frame);
    expect(p.wallId, 'w1');
    expect(p.wallOffsetMm, 1000);
    expect(p.modules, [
      ElectricalModuleType.socket220,
      ElectricalModuleType.tv,
      ElectricalModuleType.data,
      ElectricalModuleType.switch1,
    ]);
  });

  test('demolition wall flag survives JSON', () {
    final wall = PlanWall(
      id: 'w1',
      startNodeId: 'a',
      endNodeId: 'b',
      demolition: true,
      thicknessMm: 120,
    );
    final copy = PlanWall.fromJson(wall.toJson());
    expect(copy.demolition, isTrue);
    expect(copy.thicknessMm, 120);
  });
}
