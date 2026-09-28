import '../models/models.dart';
import 'geometry_service.dart';

class DemoProjectFactory {
  static const buildTag = '1.5.5+49';
  static const projectId = '__zamer_demo_1_5_5_49__';
  static const demoPrefix = '__zamer_demo_';

  static MeasureProject create() {
    final floor = FloorPlan(
      id: 'demo-floor',
      name: 'Этаж 1',
      defaultHeightMm: 2700,
      nodes: [
        PlanNode(id: 'n1', xMm: 0, yMm: 0),
        PlanNode(id: 'n2', xMm: 5400, yMm: 0),
        PlanNode(id: 'n3', xMm: 9400, yMm: 0),
        PlanNode(id: 'n4', xMm: 9400, yMm: 4200),
        PlanNode(id: 'n5', xMm: 5400, yMm: 4200),
        PlanNode(id: 'n6', xMm: 0, yMm: 4200),
      ],
      walls: [
        PlanWall(
          id: 'wA', startNodeId: 'n1', endNodeId: 'n2',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'wB', startNodeId: 'n2', endNodeId: 'n3',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'wC', startNodeId: 'n3', endNodeId: 'n4',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
          openings: [
            WallOpening(
              id: 'window-bedroom', type: OpeningType.window, widthMm: 1600,
              heightMm: 1400, offsetFromStartMm: 1300, sillHeightMm: 850,
            ),
          ],
        ),
        PlanWall(
          id: 'wD', startNodeId: 'n4', endNodeId: 'n5',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'wE', startNodeId: 'n5', endNodeId: 'n6',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
          openings: [
            WallOpening(
              id: 'window-living', type: OpeningType.window, widthMm: 1800,
              heightMm: 1400, offsetFromStartMm: 1600, sillHeightMm: 850,
            ),
          ],
        ),
        PlanWall(
          id: 'wF', startNodeId: 'n6', endNodeId: 'n1',
          type: WallType.exterior, thicknessMm: 180, material: WallMaterial.brick,
          openings: [
            WallOpening(
              id: 'door-entry', type: OpeningType.door, widthMm: 900,
              heightMm: 2100, offsetFromStartMm: 500,
            ),
          ],
        ),
        PlanWall(
          id: 'wP', startNodeId: 'n2', endNodeId: 'n5',
          type: WallType.partition, thicknessMm: 100, material: WallMaterial.drywall,
          openings: [
            WallOpening(
              id: 'door-between', type: OpeningType.door, widthMm: 900,
              heightMm: 2100, offsetFromStartMm: 1650,
            ),
          ],
        ),
      ],
      planObjects: [
        PlanObject(
          id: 'demo-sofa', type: PlanObjectType.furniture, catalogId: 'sofa-3',
          xMm: 2200, yMm: 2900, widthMm: 2200, depthMm: 950,
          heightMm: 850, rotationDeg: 0, label: 'Диван',
        ),
        PlanObject(
          id: 'demo-coffee', type: PlanObjectType.furniture, catalogId: 'coffee-table',
          xMm: 2700, yMm: 1900, widthMm: 1000, depthMm: 600,
          heightMm: 420, rotationDeg: 0, label: 'Журнальный стол',
        ),
        PlanObject(
          id: 'demo-living-light', type: PlanObjectType.lighting,
          catalogId: 'chandelier-ring', xMm: 2700, yMm: 2100,
          widthMm: 900, depthMm: 900, heightMm: 180,
          elevationMm: 2520, label: 'Люстра-кольцо',
        ),
        PlanObject(
          id: 'demo-bed', type: PlanObjectType.furniture, catalogId: 'bed-160',
          xMm: 7450, yMm: 2450, widthMm: 1700, depthMm: 2100,
          heightMm: 950, rotationDeg: 90, label: 'Кровать 160×200',
        ),
        PlanObject(
          id: 'demo-bedroom-light', type: PlanObjectType.lighting,
          catalogId: 'ceiling-dome', xMm: 7400, yMm: 2100,
          widthMm: 520, depthMm: 520, heightMm: 130,
          elevationMm: 2570, label: 'Потолочный светильник',
        ),
      ],
      electricalPoints: [
        ElectricalPoint(
          id: 'fixture:demo-living-light', type: ElectricalPointType.ceilingLight,
          xMm: 2700, yMm: 2100, label: 'Люстра', heightMm: 2665, powerW: 60,
        ),
        ElectricalPoint(
          id: 'fixture:demo-bedroom-light', type: ElectricalPointType.ceilingLight,
          xMm: 7400, yMm: 2100, label: 'Потолочный свет', heightMm: 2665, powerW: 36,
        ),
        ElectricalPoint(
          id: 'demo-wall-sconce', type: ElectricalPointType.wallLight,
          xMm: 5400, yMm: 900, label: 'Бра из электрики', heightMm: 1650,
          powerW: 12, wallId: 'wP', wallOffsetMm: 900, wallSide: -1,
        ),
      ],
    );

    GeometryService.syncRoomMetadata(floor);
    for (final meta in floor.roomMetas) {
      meta.ceilingHeightMm = 2700;
      final materials = meta.materials;
      materials.wallMaterialId = 'paint-warm-white';
      materials.wallPaint = true;
      materials.wallTileMaterialId = 'tile-light-stone';
      materials.wallTileWidthMm = 600;
      materials.wallTileHeightMm = 300;
      materials.wallTileGroutMm = 1.5;

      if (meta.centroidX < 5400) {
        meta.name = 'Гостиная';
        materials.floorMode = 'laminate';
        materials.floorMaterialId = 'oak-natural';
        materials.laminatePlankLengthMm = 1380;
        materials.laminatePlankWidthMm = 193;
        materials.laminateOffsetMode = 'half';
        materials.laminateOffsetXMm = 180;
        materials.laminateOffsetYMm = 70;
        materials.floorDirectionDeg = 0;
        materials.wallTile = false;
      } else {
        meta.name = 'Спальня';
        materials.floorMode = 'laminate';
        materials.floorMaterialId = 'oak-smoked';
        materials.laminatePlankLengthMm = 1380;
        materials.laminatePlankWidthMm = 193;
        materials.laminateOffsetMode = 'third';
        materials.laminateOffsetXMm = 120;
        materials.laminateOffsetYMm = 40;
        materials.floorDirectionDeg = 90;
        materials.wallTile = false;
        materials.wallTileRunEnabled['wC'] = true;
        materials.wallTileRunQuarterTurns['wC'] = 1;
      }
    }

    return MeasureProject(
      id: projectId,
      name: 'Тестовая квартира • $buildTag',
      address: 'Пробный двухкомнатный проект для проверки BUILD49',
      floors: [floor],
    );
  }
}
