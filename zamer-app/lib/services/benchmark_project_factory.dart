import '../models/models.dart';
import 'geometry_service.dart';

/// Stable reference scene used to tune and regression-test the new 3D core.
///
/// It intentionally contains two connected rooms, mixed finishes, warm local
/// light and a bright hallway so lighting/material changes are visible without
/// needing a large user project.
class BenchmarkProjectFactory {
  static const benchmarkPrefix = '__zamer_benchmark_';
  static const projectId = '__zamer_benchmark_render_core_1__';

  static MeasureProject create() {
    final floor = FloorPlan(
      id: 'benchmark-floor',
      name: 'Benchmark',
      defaultHeightMm: 2700,
      nodes: <PlanNode>[
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4300, yMm: 0),
        PlanNode(id: 'c', xMm: 6200, yMm: 0),
        PlanNode(id: 'd', xMm: 6200, yMm: 4200),
        PlanNode(id: 'e', xMm: 4300, yMm: 4200),
        PlanNode(id: 'f', xMm: 0, yMm: 4200),
      ],
      walls: <PlanWall>[
        PlanWall(
          id: 'ab',
          startNodeId: 'a',
          endNodeId: 'b',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'bc',
          startNodeId: 'b',
          endNodeId: 'c',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'cd',
          startNodeId: 'c',
          endNodeId: 'd',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
          openings: <WallOpening>[
            WallOpening(
              id: 'hall-window',
              type: OpeningType.window,
              widthMm: 1250,
              heightMm: 1450,
              offsetFromStartMm: 1250,
              sillHeightMm: 820,
            ),
          ],
        ),
        PlanWall(
          id: 'de',
          startNodeId: 'd',
          endNodeId: 'e',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'ef',
          startNodeId: 'e',
          endNodeId: 'f',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'fa',
          startNodeId: 'f',
          endNodeId: 'a',
          type: WallType.exterior,
          thicknessMm: 180,
          material: WallMaterial.brick,
        ),
        PlanWall(
          id: 'be',
          startNodeId: 'b',
          endNodeId: 'e',
          type: WallType.partition,
          thicknessMm: 120,
          material: WallMaterial.gasBlock,
          openings: <WallOpening>[
            WallOpening(
              id: 'bedroom-door',
              type: OpeningType.door,
              widthMm: 900,
              heightMm: 2100,
              offsetFromStartMm: 2350,
              doorSwing: DoorSwing.leftIn,
            ),
          ],
        ),
      ],
      planObjects: <PlanObject>[
        PlanObject(
          id: 'benchmark-bed',
          type: PlanObjectType.furniture,
          catalogId: 'bed-sand',
          xMm: 1200,
          yMm: 2000,
          widthMm: 1800,
          depthMm: 2200,
          heightMm: 1130,
          rotationDeg: 90,
          label: 'Кровать Sand',
        ),
        PlanObject(
          id: 'benchmark-nightstand',
          type: PlanObjectType.furniture,
          catalogId: 'nightstand',
          xMm: 470,
          yMm: 3250,
          widthMm: 500,
          depthMm: 450,
          heightMm: 550,
          rotationDeg: 90,
          label: 'Прикроватная тумба',
        ),
        PlanObject(
          id: 'benchmark-rug',
          type: PlanObjectType.furniture,
          catalogId: 'rug-textile-2300',
          xMm: 2250,
          yMm: 2100,
          widthMm: 2300,
          depthMm: 3000,
          heightMm: 18,
          label: 'Ковёр',
        ),
        PlanObject(
          id: 'benchmark-curtain',
          type: PlanObjectType.furniture,
          catalogId: 'curtain-pair-1800',
          xMm: 90,
          yMm: 3150,
          widthMm: 1800,
          depthMm: 140,
          heightMm: 2550,
          rotationDeg: 90,
          label: 'Шторы',
        ),
        PlanObject(
          id: 'benchmark-table-lamp',
          type: PlanObjectType.lighting,
          catalogId: 'table-lamp-soft',
          xMm: 470,
          yMm: 3250,
          widthMm: 320,
          depthMm: 320,
          heightMm: 520,
          elevationMm: 550,
          rotationDeg: 90,
          label: 'Настольная лампа',
        ),
        PlanObject(
          id: 'benchmark-hall-console',
          type: PlanObjectType.furniture,
          catalogId: 'tv-console-oak',
          xMm: 5250,
          yMm: 850,
          widthMm: 1820,
          depthMm: 468,
          heightMm: 598,
          label: 'ТВ-тумба Oak',
        ),
        PlanObject(
          id: 'benchmark-hall-light',
          type: PlanObjectType.lighting,
          catalogId: 'ceiling-dome',
          xMm: 5250,
          yMm: 2200,
          widthMm: 520,
          depthMm: 520,
          heightMm: 130,
          elevationMm: 2570,
          label: 'Светильник коридора',
        ),
      ],
      electricalPoints: <ElectricalPoint>[
        ElectricalPoint(
          id: 'fixture:benchmark-hall-light',
          type: ElectricalPointType.ceilingLight,
          xMm: 5250,
          yMm: 2200,
          label: 'Свет коридора',
          heightMm: 2665,
          powerW: 40,
        ),
      ],
    );

    GeometryService.syncRoomMetadata(floor);
    final faces = GeometryService.roomFaces(floor);
    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta == null) continue;
      meta.ceilingHeightMm = 2700;
      final materials = meta.materials;
      if (face.centroid.x < 4300) {
        meta.name = 'Спальня benchmark';
        materials.floorMode = 'laminate';
        materials.floorMaterialId = 'oak-smoked';
        materials.laminatePattern = 'herringbone';
        materials.laminatePlankLengthMm = 600;
        materials.laminatePlankWidthMm = 90;
        materials.laminateOffsetMode = 'free';
        materials.laminateOffsetXMm = 40;
        materials.laminateOffsetYMm = 25;
        materials.floorDirectionDeg = 0;
        materials.wallMaterialId = 'paint-warm-white';
        materials.wallPaint = true;
        materials.wallTile = false;
      } else {
        meta.name = 'Светлый коридор';
        materials.floorMode = 'tile';
        materials.floorMaterialId = 'tile-light-stone';
        materials.tileWidthMm = 600;
        materials.tileHeightMm = 600;
        materials.tilePattern = 'straight';
        materials.floorDirectionDeg = 0;
        materials.wallMaterialId = 'paint-warm-white';
        materials.wallPaint = true;
        materials.wallTile = false;
      }
    }

    return MeasureProject(
      id: projectId,
      name: '3D Benchmark • спальня',
      address: 'Эталонная сцена для Performance / Quality / Photo 4K',
      floors: <FloorPlan>[floor],
    );
  }
}
