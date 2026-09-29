import '../models/models.dart';
import 'geometry_service.dart';

class DemoProjectFactory {
  static const buildTag = '1.5.6+66';
  static const projectId = '__zamer_demo_1_5_6_66__';
  static const demoPrefix = '__zamer_demo_';

  static MeasureProject create() {
    final floor = FloorPlan(
      id: 'demo-floor',
      name: 'Этаж 1',
      defaultHeightMm: 2700,
      nodes: [
        PlanNode(id: 'n1', xMm: 0, yMm: 0),
        PlanNode(id: 'n2', xMm: 4200, yMm: 0),
        PlanNode(id: 'n3', xMm: 4200, yMm: 3200),
        PlanNode(id: 'n4', xMm: 0, yMm: 3200),
      ],
      walls: [
        PlanWall(
          id: 'wA',
          startNodeId: 'n1',
          endNodeId: 'n2',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
          openings: [
            WallOpening(
              id: 'door-1',
              type: OpeningType.door,
              widthMm: 900,
              heightMm: 2100,
              offsetFromStartMm: 350,
            ),
          ],
        ),
        PlanWall(
          id: 'wB',
          startNodeId: 'n2',
          endNodeId: 'n3',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
          openings: [
            WallOpening(
              id: 'window-1',
              type: OpeningType.window,
              widthMm: 1400,
              heightMm: 1400,
              offsetFromStartMm: 900,
              sillHeightMm: 850,
            ),
          ],
        ),
        PlanWall(
          id: 'wC',
          startNodeId: 'n3',
          endNodeId: 'n4',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'wD',
          startNodeId: 'n4',
          endNodeId: 'n1',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
      ],
      planObjects: [
        PlanObject(
          id: 'demo-bed',
          type: PlanObjectType.furniture,
          catalogId: 'bed-160',
          xMm: 2450,
          yMm: 1850,
          widthMm: 1700,
          depthMm: 2100,
          heightMm: 950,
          rotationDeg: 90,
          label: 'Кровать 160×200',
        ),
        PlanObject(
          id: 'demo-light',
          type: PlanObjectType.lighting,
          catalogId: 'chandelier-ring',
          xMm: 2100,
          yMm: 1600,
          widthMm: 900,
          depthMm: 900,
          heightMm: 180,
          elevationMm: 2520,
          label: 'Люстра-кольцо',
        ),
      ],
      electricalPoints: [
        ElectricalPoint(
          id: 'fixture:demo-light',
          type: ElectricalPointType.ceilingLight,
          xMm: 2100,
          yMm: 1600,
          label: 'Люстра',
          heightMm: 2665,
          powerW: 60,
        ),
      ],
    );

    GeometryService.syncRoomMetadata(floor);
    if (floor.roomMetas.isNotEmpty) {
      final meta = floor.roomMetas.first;
      meta.name = 'Тестовая комната';
      meta.ceilingHeightMm = 2700;
      final materials = meta.materials;
      materials.floorMode = 'laminate';
      materials.floorMaterialId = 'oak-natural';
      materials.laminatePlankLengthMm = 1380;
      materials.laminatePlankWidthMm = 193;
      materials.laminateOffsetMode = 'half';
      materials.laminateOffsetXMm = 180;
      materials.laminateOffsetYMm = 70;
      materials.floorDirectionDeg = 0;
      materials.wallMaterialId = 'paint-warm-white';
      materials.wallPaint = true;
      materials.wallTile = false;
      materials.wallTileMaterialId = 'tile-light-stone';
      materials.wallTileWidthMm = 600;
      materials.wallTileHeightMm = 300;
      materials.wallTileGroutMm = 1.5;
      materials.wallTileRunEnabled['wC'] = true;
      materials.wallTileRunMirrored['wC'] = true;
    }

    return MeasureProject(
      id: projectId,
      name: 'Квартира, Калининград',
      address: '',
      floors: [floor],
    );
  }
}
