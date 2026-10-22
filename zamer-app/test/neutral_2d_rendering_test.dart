import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/imported_top_view_assets.dart';
import 'package:zamer_app/services/plan_visibility_service.dart';
import 'package:zamer_app/widgets/cad_plan_painter_v2.dart';
import 'package:zamer_app/widgets/cad_plan_painter_v3.dart';
import 'package:zamer_app/widgets/cad_wall_join_geometry.dart';
import 'package:zamer_app/widgets/top_view_object_renderer.dart';

PlanObject object(
  String id,
  String catalogId,
  double x,
  double y,
  double width,
  double depth, {
  double rotation = 0,
}) => PlanObject(
  id: id,
  catalogId: catalogId,
  type: PlanObjectType.furniture,
  xMm: x,
  yMm: y,
  widthMm: width,
  depthMm: depth,
  rotationDeg: rotation,
);

Future<ui.Image> render(
  void Function(Canvas) draw,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  draw(
    Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble())),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

int pixel(ByteData rgba, int width, int x, int y) =>
    rgba.getUint32((y * width + x) * 4);

FloorPlan previewFloor() {
  final floor = FloorPlan(id: 'neutral-review', name: 'Стены и мебель');
  const points = <String, (double, double)>{
    'a': (0, 0),
    'b': (4800, 0),
    'c': (8000, 0),
    'd': (8000, 3300),
    'e': (8000, 5600),
    'f': (4800, 5600),
    'g': (0, 5600),
    'h': (4800, 3300),
  };
  for (final p in points.entries) {
    floor.nodes.add(PlanNode(id: p.key, xMm: p.value.$1, yMm: p.value.$2));
  }
  void wall(
    String id,
    String a,
    String b, {
    double width = 280,
    OpeningType? opening,
    double offset = 0,
    double openingWidth = 900,
  }) {
    floor.walls.add(
      PlanWall(
        id: id,
        startNodeId: a,
        endNodeId: b,
        thicknessMm: width,
        openings: opening == null
            ? []
            : [
                WallOpening(
                  id: '$id-opening',
                  type: opening,
                  widthMm: openingWidth,
                  heightMm: opening == OpeningType.door ? 2100 : 1400,
                  offsetFromStartMm: offset,
                ),
              ],
      ),
    );
  }

  wall(
    'ab',
    'a',
    'b',
    opening: OpeningType.window,
    offset: 1000,
    openingWidth: 2200,
  );
  wall(
    'bc',
    'b',
    'c',
    opening: OpeningType.window,
    offset: 800,
    openingWidth: 1600,
  );
  wall('cd', 'c', 'd');
  wall('de', 'd', 'e');
  wall('ef', 'e', 'f');
  wall('fg', 'f', 'g', opening: OpeningType.door, offset: 600);
  wall('ga', 'g', 'a');
  wall('bh', 'b', 'h', width: 120, opening: OpeningType.door, offset: 2250);
  wall('hf', 'h', 'f', width: 120, opening: OpeningType.door, offset: 250);
  wall('hd', 'h', 'd', width: 120);
  for (final face in GeometryService.roomFaces(floor)) {
    floor.roomMetas.add(
      RoomMeta(
        id: face.key,
        faceKey: face.key,
        name: '',
        // A neutral existing preset isolates the wall/furniture review.
        materials: RoomMaterialSettings(floorMaterialId: 'paint-greige'),
      ),
    );
  }
  floor.planObjects.addAll([
    object('sofa', 'sofa-3', 1650, 900, 2200, 950),
    object('coffee', 'coffee-table-oval', 1650, 2050, 1050, 600),
    object('chair', 'armchair', 3350, 2050, 920, 900, rotation: 90),
    object('table', 'table-round', 3000, 4200, 1100, 1100),
    object('dining1', 'chair', 3000, 3400, 480, 520),
    object('dining2', 'chair', 3000, 5000, 480, 520, rotation: 180),
    object('storage', 'wardrobe-3', 450, 4200, 1500, 600, rotation: 90),
    object('bed', 'bed-180', 6400, 1450, 1800, 2200),
    object('nightstand1', 'nightstand', 5150, 650, 430, 430),
    object('nightstand2', 'nightstand', 7650, 650, 430, 430),
    object('bath', 'bath', 6900, 5000, 1700, 700),
    object('sink', 'sink', 7450, 3850, 600, 500),
    object('toilet', 'toilet', 6000, 3900, 400, 650),
    // Intentionally added last to exercise the floor-object stacking rule.
    object('rug', 'rug-gray', 1900, 2000, 3000, 2200),
  ]);
  return floor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('joined wall outline has one contour and no internal seams', () {
    for (final reverse in [false, true]) {
      final floor = FloorPlan(
        id: 'l',
        name: 'L',
        nodes: [
          PlanNode(id: 'j', xMm: 0, yMm: 0),
          PlanNode(id: 'a', xMm: 2000, yMm: 0),
          PlanNode(id: 'b', xMm: 0, yMm: 2000),
        ],
        walls: [
          PlanWall(
            id: 'a',
            startNodeId: reverse ? 'a' : 'j',
            endNodeId: reverse ? 'j' : 'a',
            thicknessMm: 100,
          ),
          PlanWall(id: 'b', startNodeId: 'j', endNodeId: 'b', thicknessMm: 300),
        ],
      );
      final body = CadWallJoinGeometry.bodies(
        floor: floor,
        mmToPx: 1,
        origin: Offset.zero,
        visibleLayers: ProjectLayer.values.toSet(),
      )[ProjectLayer.existing]!;
      expect(body.computeMetrics().length, 1);
      expect(body.contains(const Offset(-140, -40)), isTrue);
      expect(body.contains(const Offset(40, 40)), isTrue);
      expect(body.contains(const Offset(-160, -60)), isFalse);
    }
  });

  test('rugs stay below furniture without changing saved order', () {
    final floor = FloorPlan(
      id: 'f',
      name: 'Order',
      planObjects: [
        object('sofa', 'sofa-3', 0, 0, 2200, 950),
        object('bed', 'bed-180', 0, 0, 1800, 2200),
        object('rug', 'rug-gray', 0, 0, 3000, 2000),
      ],
    );
    final before = floor.toJson().toString();
    final painted = <String>[];
    final recorder = ui.PictureRecorder();
    CadPlanPainterV2(
      floor: floor,
      mmToPx: .1,
      origin: const Offset(200, 200),
      showDimensions: false,
      showGrid: false,
      drawTopView: (_, obj, _, _) {
        painted.add(obj.id);
        return true;
      },
    ).paint(Canvas(recorder), const Size(400, 400));
    recorder.endRecording().dispose();
    expect(painted, ['rug', 'sofa', 'bed']);
    expect(floor.toJson().toString(), before);
  });

  test(
    'solid walls remain above intersecting furniture and cast no shadow',
    () async {
      final floor = FloorPlan(
        id: 'f',
        name: 'Wall',
        nodes: [
          PlanNode(id: 'a', xMm: 50, yMm: 100),
          PlanNode(id: 'b', xMm: 250, yMm: 100),
        ],
        walls: [
          PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 20),
        ],
        planObjects: [object('s', 'sofa-3', 100, 100, 80, 80)],
      );
      final image = await render(
        (canvas) {
          CadPlanPainterV2(
            floor: floor,
            mmToPx: 1,
            origin: Offset.zero,
            showGrid: false,
            showDimensions: false,
            drawTopView: (canvas, _, center, _) {
              canvas.drawRect(
                Rect.fromCenter(center: center, width: 80, height: 80),
                Paint()..color = Colors.red,
              );
              return true;
            },
          ).paint(canvas, const Size(300, 200));
        },
        300,
        200,
      );
      final pixels = (await image.toByteData())!;
      expect(pixel(pixels, 300, 100, 100), 0xF0F1EDFF);
      expect(pixel(pixels, 300, 100, 70), 0xF44336FF);
      final bg = ZamerColors.background.toARGB32();
      expect(pixel(pixels, 300, 200, 111), ((bg & 0xffffff) << 8) | 0xff);
      image.dispose();
    },
  );

  test('vector fallback adds no shadow outside its footprint', () async {
    final image = await render(
      (canvas) {
        TopViewObjectRenderer.draw(
          canvas,
          object('w', 'wardrobe-3', 100, 100, 100, 60),
          center: const Offset(100, 100),
          mmToPx: 1,
        );
      },
      200,
      180,
    );
    final pixels = (await image.toByteData())!;
    expect(pixel(pixels, 200, 100, 131) & 0xff, 0);
    image.dispose();
  });

  test('neutral sofa keeps its physical footprint when rotated', () async {
    await ImportedTopViewAssets.instance.ensureLoaded();
    for (final angle in [0.0, 90.0]) {
      final floor = FloorPlan(
        id: 'f',
        name: 'Rotation',
        planObjects: [object('s', 'sofa-3', 0, 0, 2200, 950, rotation: angle)],
      );
      final image = await render(
        (canvas) {
          CadPlanPainterV3(
            floor: floor,
            mmToPx: .1,
            origin: const Offset(160, 160),
            showGrid: false,
            showDimensions: false,
          ).paint(canvas, const Size(320, 320));
        },
        320,
        320,
      );
      final bytes = (await image.toByteData())!;
      var left = 320, right = 0, top = 320, bottom = 0;
      for (var y = 0; y < 320; y++) {
        for (var x = 0; x < 320; x++) {
          final offset = (y * 320 + x) * 4;
          // Furniture is neutral and light; ignore almost-transparent fringe.
          if (bytes.getUint8(offset) < 65) continue;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      expect(right - left + 1, closeTo(angle == 0 ? 220 : 95, 4));
      expect(bottom - top + 1, closeTo(angle == 0 ? 95 : 220, 4));
      expect((left + right) / 2, closeTo(159.5, 2));
      expect((top + bottom) / 2, closeTo(159.5, 2));
      image.dispose();
    }
  });

  test('neutral furniture decodes and real plan preview renders', () async {
    final assets = ImportedTopViewAssets.instance;
    await assets.ensureLoaded();
    var decodedBytes = 0;
    for (final id in ['sofa-3', 'bed-180']) {
      final sprite = assets.neutralForCatalog(id);
      expect(
        sprite,
        isNotNull,
        reason: '$id must not silently use the old atlas',
      );
      expect(sprite!.sourceRect.width, greaterThan(700));
      expect(sprite.sourceRect.right, lessThanOrEqualTo(sprite.image.width));
      decodedBytes += sprite.image.width * sprite.image.height * 4;
    }
    expect(decodedBytes, lessThan(5 * 1024 * 1024));
    final floor = previewFloor();
    final before = floor.toJson().toString();
    final image = await render(
      (canvas) {
        CadPlanPainterV3(
          floor: floor,
          mmToPx: .11,
          origin: const Offset(95, 85),
          showGrid: false,
          showDimensions: false,
          visibleCategories: PlanDisplayLayer.values.toSet()
            ..remove(PlanDisplayLayer.roomLabels),
        ).paint(canvas, const Size(1080, 800));
      },
      1080,
      800,
    );
    expect(floor.toJson().toString(), before);
    if (const bool.fromEnvironment('ZAMER_WRITE_PREVIEW')) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('docs/previews/neutral-2d-pass1.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    }
    image.dispose();
  });
}
