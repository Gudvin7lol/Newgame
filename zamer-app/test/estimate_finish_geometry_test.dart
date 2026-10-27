import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/estimate_service.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/work_floor_surface_service.dart';
import 'package:zamer_app/services/work_generation_service.dart';
import 'package:zamer_app/services/work_surface_service.dart';

FloorPlan _room() {
  final floor = FloorPlan(
    id: 'floor-1',
    name: 'Первый этаж',
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b',
        openings: [
          WallOpening(
            id: 'door', type: OpeningType.door,
            offsetFromStartMm: 900, widthMm: 900, heightMm: 2100,
          ),
        ]),
      PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
    ],
  );
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

double _quantity(ProjectEstimate estimate, String name) =>
    estimate.lines.singleWhere((line) => line.name == name).quantity;

bool _has(ProjectEstimate estimate, String name) =>
    estimate.lines.any((line) => line.name == name);

void main() {
  test('all-tile floor never receives laminate or underlay costs', () {
    final floor = _room();
    final face = GeometryService.roomFaces(floor).single;
    final materials = floor.roomMetaByKey(face.key)!.materials
      ..floorMode = 'tile'
      ..floorTile = true;
    final project = MeasureProject(
      id: 'tile-only', name: 'Санузел', floors: [floor]);

    final labor = EstimateService.buildWork(project);
    final takeoff = EstimateService.build(project);

    expect(_quantity(labor, 'Укладка плитки пола'),
        closeTo(face.areaM2, 0.001));
    expect(_has(labor, 'Укладка ламината'), isFalse);
    expect(_has(labor, 'Укладка подложки'), isFalse);
    expect(_has(takeoff, 'Ламинат / SPC'), isFalse);
    expect(_has(takeoff, 'Подложка'), isFalse);
    expect(_quantity(takeoff, 'Плитка на пол'), closeTo(
        face.areaM2 * (1 + materials.floorTileWastePct / 100), 0.001));
    // Tile wastage is a purchase allowance, not additional glued area.
    expect(_quantity(takeoff, 'Плиточный клей (пол)'), closeTo(
        face.areaM2 * materials.tileGlueKgM2, 0.001));
  });

  test('floor zones and opening-aware wall finishes drive the same estimate', () {
    final floor = _room();
    final face = GeometryService.roomFaces(floor).single;
    final project = MeasureProject(
      id: 'mixed', name: 'Смешанная отделка', floors: [floor]);
    final board = project.workBoard;
    final b = WorkFloorSurfaceService.bounds(face, 'x');
    WorkFloorSurfaceService.save(board, floor, face, WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'x', cutMm: (b.min + b.max) / 2,
      tileBeforeCut: true,
    ));
    WorkSurfaceService.save(board, floor, face, {
      'w1': 1350.0, 'w2': 2700.0, 'w3': 0.0, 'w4': 0.0,
    });

    final work = EstimateService.buildWork(project);
    final materials = EstimateService.build(project);
    final floorParts = WorkFloorSurfaceService.areas(board, floor, face);
    final wallTile = WorkSurfaceService.areaForCode(
        board, floor, face, 'wall_tile');
    final wallPaint = WorkSurfaceService.areaForCode(
        board, floor, face, 'wall_paint');
    final settings = floor.roomMetas.single.materials;

    expect(_quantity(work, 'Укладка плитки пола'),
        closeTo(floorParts.tileM2, .001));
    expect(_quantity(work, 'Укладка ламината'),
        closeTo(floorParts.laminateM2, .001));
    expect(_quantity(work, 'Укладка подложки'),
        closeTo(floorParts.laminateM2, .001));
    expect(floorParts.tileM2 + floorParts.laminateM2,
        closeTo(face.areaM2, .001));
    expect(_quantity(materials, 'Ламинат / SPC'), closeTo(
        floorParts.laminateM2 * (1 + settings.floorWastePct / 100), .001));
    expect(_quantity(materials, 'Плитка на пол'), closeTo(
        floorParts.tileM2 * (1 + settings.floorTileWastePct / 100), .001));

    expect(_quantity(work, 'Укладка плитки стен'),
        closeTo(wallTile, .001));
    expect(_quantity(work, 'Покраска стен'),
        closeTo(wallPaint, .001));
    final net = WorkSurfaceService.walls(board, floor, face).fold<double>(
        0, (sum, wall) => sum + wall.netAreaM2);
    expect(wallPaint + wallTile, closeTo(net, .001));
    expect(_quantity(materials, 'Плитка на стены'), closeTo(
        wallTile * (1 + settings.wallTileWastePct / 100), .001));
    expect(_quantity(materials, 'Плиточный клей (стены)'),
        closeTo(wallTile * settings.tileGlueKgM2, .001));
    expect(_quantity(materials, 'Краска для стен'), closeTo(
        wallPaint * settings.paintCoats / settings.paintCoverageM2L, .001));
    expect(_quantity(materials, 'Шпаклёвка'), closeTo(
        wallPaint * settings.puttyCoats * settings.puttyKgM2Coat, .001));
    expect(_quantity(work, 'Шпаклёвка стен'), closeTo(wallPaint, .001));

    // The schedule generator must use the very same scoped quantities.
    final plan = WorkGenerationService.preview(
        project, begin: DateTime(2026, 11, 2));
    final putty = plan.tasks.firstWhere(
        (task) => task.operationCode == 'wall_putty');
    expect(putty.quantity, closeTo(wallPaint, .01));
  });

  test('creating a new estimate does not rewrite accepted work quantities', () {
    final floor = _room();
    final project = MeasureProject(
      id: 'accepted', name: 'Ремонт', floors: [floor]);
    final board = project.workBoard;
    final face = GeometryService.roomFaces(floor).single;
    final plan = WorkGenerationService.preview(project);
    expect(WorkGenerationService.apply(board, plan), isNull);
    final laminate = board.tasks.firstWhere(
        (task) => task.operationCode == 'floor_laminate');
    laminate.done = laminate.quantity;
    laminate.accepted = laminate.quantity;
    final recorded = laminate.quantity;
    final b = WorkFloorSurfaceService.bounds(face, 'x');
    WorkFloorSurfaceService.save(board, floor, face, WorkFloorFinishSplit(
      floorId: floor.id, roomId: floor.roomMetas.single.id,
      axis: 'x', cutMm: (b.min + b.max) / 2, tileBeforeCut: true,
    ));

    final work = EstimateService.buildWork(project);
    final takeoff = EstimateService.build(project);
    expect(_quantity(work, 'Укладка ламината'), lessThan(recorded));
    expect(_has(takeoff, 'Плитка на пол'), isTrue);
    expect(laminate.quantity, recorded);
    expect(laminate.done, recorded);
    expect(laminate.accepted, recorded);
  });
}
