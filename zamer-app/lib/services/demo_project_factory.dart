import '../models/models.dart';
import 'geometry_service.dart';

class DemoProjectFactory {
  static const buildTag = '1.5.6+77';
  static const projectId = '__zamer_demo_1_5_6_77__';
  static const demoPrefix = '__zamer_demo_';

  static MeasureProject create() {
    final floor = FloorPlan(
      id: 'demo-floor',
      name: 'Этаж 1',
      defaultHeightMm: 2700,
      nodes: [
        PlanNode(id: 'n1', xMm: 0, yMm: 0),
        PlanNode(id: 'n2', xMm: 3000, yMm: 0),
        PlanNode(id: 'n3', xMm: 6100, yMm: 0),
        PlanNode(id: 'n4', xMm: 6100, yMm: 4700),
        PlanNode(id: 'n5', xMm: 6100, yMm: 6500),
        PlanNode(id: 'n6', xMm: 6100, yMm: 9350),
        PlanNode(id: 'n7', xMm: 3000, yMm: 9350),
        PlanNode(id: 'n8', xMm: 3000, yMm: 6500),
        PlanNode(id: 'n9', xMm: 0, yMm: 6500),
        PlanNode(id: 'n10', xMm: 0, yMm: 3500),
        PlanNode(id: 'n11', xMm: 3000, yMm: 3500),
        PlanNode(id: 'n12', xMm: 3000, yMm: 4700),
        PlanNode(id: 'n13', xMm: 4300, yMm: 4700),
        PlanNode(id: 'n14', xMm: 4300, yMm: 6500),
      ],
      walls: [
        _outer('w1', 'n1', 'n2', openings: [
          _window('win-bed-top', 1200, 1050),
        ]),
        _outer('w2', 'n2', 'n3', openings: [
          _window('win-living-top', 1400, 850),
        ]),
        _outer('w3', 'n3', 'n4', openings: [
          _window('win-living-right', 1400, 1900),
        ]),
        _outer('w4', 'n4', 'n5', openings: [
          _window('win-bath', 800, 500),
        ]),
        _outer('w5', 'n5', 'n6'),
        _outer('w6', 'n6', 'n7', openings: [
          WallOpening(
            id: 'entry-door',
            type: OpeningType.door,
            widthMm: 950,
            heightMm: 2100,
            offsetFromStartMm: 900,
            doorSwing: DoorSwing.rightIn,
          ),
        ]),
        _outer('w7', 'n7', 'n8'),
        _outer('w8', 'n8', 'n9'),
        _outer('w9', 'n9', 'n10', openings: [
          _window('win-kitchen-left', 1500, 700),
        ]),
        _outer('w10', 'n10', 'n1'),

        _partition('w11', 'n2', 'n11'),
        _partition('w12', 'n11', 'n12'),
        _partition('w13', 'n12', 'n8', openings: [
          _door('door-kitchen', 900, 650),
        ]),
        _partition('w14', 'n10', 'n11', openings: [
          _door('door-bedroom', 900, 1850),
        ]),
        _partition('w15', 'n12', 'n13', openings: [
          _door('door-living', 1000, 120),
        ]),
        _partition('w16', 'n13', 'n4'),
        _partition('w17', 'n13', 'n14', openings: [
          _door('door-bath', 800, 450),
        ]),
        _partition('w18', 'n8', 'n14', openings: [
          _door('door-entry', 900, 180),
        ]),
        _partition('w19', 'n14', 'n5'),
      ],
      planObjects: [
        PlanObject(
          id: 'bed',
          type: PlanObjectType.furniture,
          catalogId: 'bed-160',
          xMm: 1500,
          yMm: 1850,
          widthMm: 1700,
          depthMm: 2100,
          heightMm: 950,
          label: 'Кровать 160×200',
        ),
        PlanObject(
          id: 'bed-wardrobe',
          type: PlanObjectType.furniture,
          catalogId: 'wardrobe-2',
          xMm: 450,
          yMm: 700,
          widthMm: 1000,
          depthMm: 600,
          heightMm: 2200,
          rotationDeg: 90,
          label: 'Шкаф',
        ),
        PlanObject(
          id: 'sofa',
          type: PlanObjectType.furniture,
          catalogId: 'sofa-3',
          xMm: 5480,
          yMm: 2350,
          widthMm: 2200,
          depthMm: 900,
          heightMm: 850,
          rotationDeg: 90,
          label: 'Диван',
        ),
        PlanObject(
          id: 'living-table',
          type: PlanObjectType.furniture,
          catalogId: 'table-round',
          xMm: 4350,
          yMm: 2450,
          widthMm: 900,
          depthMm: 900,
          heightMm: 450,
          label: 'Журнальный стол',
        ),
        PlanObject(
          id: 'living-tv',
          type: PlanObjectType.furniture,
          catalogId: 'tv',
          xMm: 3150,
          yMm: 2350,
          widthMm: 1230,
          depthMm: 120,
          heightMm: 720,
          rotationDeg: 90,
          elevationMm: 900,
          label: 'TV',
        ),
        PlanObject(
          id: 'kitchen-sink',
          type: PlanObjectType.furniture,
          catalogId: 'kitchen-sink',
          xMm: 420,
          yMm: 4300,
          widthMm: 600,
          depthMm: 600,
          heightMm: 900,
          rotationDeg: 90,
          label: 'Мойка',
        ),
        PlanObject(
          id: 'kitchen-oven',
          type: PlanObjectType.furniture,
          catalogId: 'kitchen-oven',
          xMm: 420,
          yMm: 5000,
          widthMm: 600,
          depthMm: 600,
          heightMm: 900,
          rotationDeg: 90,
          label: 'Плита',
        ),
        PlanObject(
          id: 'fridge',
          type: PlanObjectType.furniture,
          catalogId: 'fridge',
          xMm: 420,
          yMm: 5800,
          widthMm: 600,
          depthMm: 650,
          heightMm: 1900,
          rotationDeg: 90,
          label: 'Холодильник',
        ),
        PlanObject(
          id: 'dining-table',
          type: PlanObjectType.furniture,
          catalogId: 'table-rect',
          xMm: 1850,
          yMm: 5200,
          widthMm: 1400,
          depthMm: 800,
          heightMm: 750,
          rotationDeg: 90,
          label: 'Стол',
        ),
        ..._chairs(),
        PlanObject(
          id: 'toilet',
          type: PlanObjectType.sanitary,
          catalogId: 'toilet',
          xMm: 5600,
          yMm: 5150,
          widthMm: 390,
          depthMm: 700,
          heightMm: 760,
          rotationDeg: 90,
          label: 'Унитаз',
        ),
        PlanObject(
          id: 'sink',
          type: PlanObjectType.sanitary,
          catalogId: 'sink',
          xMm: 4700,
          yMm: 5050,
          widthMm: 600,
          depthMm: 500,
          heightMm: 850,
          label: 'Раковина',
        ),
        PlanObject(
          id: 'shower',
          type: PlanObjectType.sanitary,
          catalogId: 'shower',
          xMm: 5350,
          yMm: 6020,
          widthMm: 900,
          depthMm: 900,
          heightMm: 2100,
          label: 'Душ',
        ),
        PlanObject(
          id: 'entry-wardrobe',
          type: PlanObjectType.furniture,
          catalogId: 'wardrobe-3',
          xMm: 5480,
          yMm: 8000,
          widthMm: 1500,
          depthMm: 600,
          heightMm: 2200,
          rotationDeg: 90,
          label: 'Шкаф',
        ),
        PlanObject(
          id: 'entry-console',
          type: PlanObjectType.furniture,
          catalogId: 'kitchen-base-800',
          xMm: 3550,
          yMm: 8500,
          widthMm: 800,
          depthMm: 420,
          heightMm: 900,
          label: 'Консоль',
        ),
      ],
    );

    GeometryService.syncRoomMetadata(floor);
    final faces = GeometryService.roomFaces(floor);
    for (final face in faces) {
      final meta = floor.roomMetas.firstWhere((m) => m.faceKey == face.key);
      final c = face.centroid;
      meta.ceilingHeightMm = 2700;
      meta.materials.wallMaterialId = 'paint-warm-white';
      meta.materials.wallPaint = true;
      meta.materials.floorMode = 'laminate';
      meta.materials.floorMaterialId = 'oak-natural';
      meta.materials.laminatePlankLengthMm = 1380;
      meta.materials.laminatePlankWidthMm = 193;
      meta.materials.laminateOffsetMode = 'half';

      if (c.x < 3000 && c.y < 3500) {
        meta.name = 'Спальня';
        meta.materials.floorMaterialId = 'oak-light';
      } else if (c.x < 3000 && c.y >= 3500) {
        meta.name = 'Кухня';
        meta.materials.floorMode = 'tile';
        meta.materials.floorMaterialId = 'tile-light-stone';
      } else if (c.x >= 3000 && c.y < 4700) {
        meta.name = 'Гостиная';
        meta.materials.floorMaterialId = 'oak-natural';
      } else if (c.x >= 4300 && c.y >= 4700 && c.y < 6500) {
        meta.name = 'С/У';
        meta.materials.floorMode = 'tile';
        meta.materials.floorMaterialId = 'tile-dark';
        meta.materials.wallTile = true;
        meta.materials.wallTileMaterialId = 'tile-light-stone';
      } else if (c.y >= 6500) {
        meta.name = 'Прихожая';
        meta.materials.floorMaterialId = 'oak-honey';
      } else {
        meta.name = 'Коридор';
        meta.materials.floorMaterialId = 'oak-natural';
      }
    }

    return MeasureProject(
      id: projectId,
      name: 'Квартира, Калининград',
      address: '',
      floors: [floor],
    );
  }

  static PlanWall _outer(
    String id,
    String a,
    String b, {
    List<WallOpening> openings = const [],
  }) =>
      PlanWall(
        id: id,
        startNodeId: a,
        endNodeId: b,
        type: WallType.exterior,
        thicknessMm: 180,
        material: WallMaterial.brick,
        openings: openings,
      );

  static PlanWall _partition(
    String id,
    String a,
    String b, {
    List<WallOpening> openings = const [],
  }) =>
      PlanWall(
        id: id,
        startNodeId: a,
        endNodeId: b,
        type: WallType.partition,
        thicknessMm: 120,
        material: WallMaterial.drywall,
        openings: openings,
      );

  static WallOpening _window(String id, double width, double offset) =>
      WallOpening(
        id: id,
        type: OpeningType.window,
        widthMm: width,
        heightMm: 1500,
        offsetFromStartMm: offset,
        sillHeightMm: 900,
      );

  static WallOpening _door(String id, double width, double offset) =>
      WallOpening(
        id: id,
        type: OpeningType.door,
        widthMm: width,
        heightMm: 2100,
        offsetFromStartMm: offset,
        doorSwing: DoorSwing.leftIn,
      );

  static List<PlanObject> _chairs() => [
        PlanObject(
          id: 'chair-1',
          type: PlanObjectType.furniture,
          catalogId: 'chair',
          xMm: 1250,
          yMm: 5200,
          widthMm: 480,
          depthMm: 520,
          heightMm: 850,
          rotationDeg: 90,
        ),
        PlanObject(
          id: 'chair-2',
          type: PlanObjectType.furniture,
          catalogId: 'chair',
          xMm: 2450,
          yMm: 5200,
          widthMm: 480,
          depthMm: 520,
          heightMm: 850,
          rotationDeg: 270,
        ),
        PlanObject(
          id: 'chair-3',
          type: PlanObjectType.furniture,
          catalogId: 'chair',
          xMm: 1850,
          yMm: 4550,
          widthMm: 480,
          depthMm: 520,
          heightMm: 850,
        ),
        PlanObject(
          id: 'chair-4',
          type: PlanObjectType.furniture,
          catalogId: 'chair',
          xMm: 1850,
          yMm: 5850,
          widthMm: 480,
          depthMm: 520,
          heightMm: 850,
          rotationDeg: 180,
        ),
      ];
}
