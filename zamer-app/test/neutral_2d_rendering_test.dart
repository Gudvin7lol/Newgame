import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/imported_top_view_assets.dart';
import 'package:zamer_app/services/object_catalog.dart';
import 'package:zamer_app/services/plan_visibility_service.dart';
import 'package:zamer_app/services/top_view_contact_shadow.dart';
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
  wall('fg', 'f', 'g', opening: OpeningType.door, offset: 2600);
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
        materials: RoomMaterialSettings(floorMaterialId: 'paint-warm-white'),
      ),
    );
  }
  floor.planObjects.addAll([
    object('sofa', 'sofa-3', 1650, 900, 2200, 950),
    object('coffee', 'coffee-table-oval', 1650, 2050, 1100, 650),
    object('chair', 'armchair', 3350, 2050, 920, 900, rotation: 90),
    object('table', 'dining-table-1800', 3000, 4200, 1800, 900),
    object('dining1', 'chair', 2550, 3400, 480, 520),
    object('dining2', 'chair', 3450, 3400, 480, 520),
    object('dining3', 'chair', 2550, 5000, 480, 520, rotation: 180),
    object('dining4', 'chair', 3450, 5000, 480, 520, rotation: 180),
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

FloorPlan livingRoomPreview() {
  final source = previewFloor();
  const nodes = {'a', 'b', 'f', 'g'};
  const walls = {'ab', 'fg', 'ga'};
  final floor = FloorPlan(
    id: 'living-room-review',
    name: 'Гостиная — проверка деталей',
    nodes: source.nodes.where((node) => nodes.contains(node.id)).toList(),
    walls: [
      ...source.walls.where((wall) => walls.contains(wall.id)),
      PlanWall(
        id: 'right', startNodeId: 'b', endNodeId: 'f', thicknessMm: 160,
        openings: [WallOpening(
          id: 'right-door', type: OpeningType.door, widthMm: 900,
          heightMm: 2100, offsetFromStartMm: 2950,
        )],
      ),
    ],
    planObjects: source.planObjects.where((object) => object.xMm < 4800).toList(),
  );
  for (final face in GeometryService.roomFaces(floor)) {
    floor.roomMetas.add(RoomMeta(
      id: face.key, faceKey: face.key, name: '',
      materials: RoomMaterialSettings(floorMaterialId: 'paint-warm-white'),
    ));
  }
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
    'solid walls remain above furniture without an exterior scene shadow',
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
      expect(pixel(pixels, 300, 100, 100), 0x353B3CFF);
      expect(pixel(pixels, 300, 100, 70), 0xF44336FF);
      final bg = ZamerColors.background.toARGB32();
      expect(pixel(pixels, 300, 200, 111), ((bg & 0xffffff) << 8) | 0xff);
      image.dispose();
    },
  );

  test('contact masks follow alpha and keep rugs close to the floor', () async {
    final atlas = await render((canvas) {
      canvas.drawOval(const Rect.fromLTWH(16, 8, 64, 80),
          Paint()..color = Colors.white);
      // An opaque neighboring sprite must not leak into this mask.
      canvas.drawRect(const Rect.fromLTWH(96, 0, 96, 96),
          Paint()..color = Colors.red);
    }, 192, 96);
    final shadows = <TopViewContactShadow>[];
    final samples = <ByteData>[];
    for (final rug in [false, true]) {
      final shadow = await TopViewContactShadow.create(
        source: atlas, sourceRect: const Rect.fromLTWH(0, 0, 96, 96),
        widthMm: 960, depthMm: 960, isRug: rug,
      );
      shadows.add(shadow);
      final image = await render((canvas) {
        shadow.paint(canvas, const Rect.fromLTWH(48, 48, 96, 96));
      }, 192, 192);
      samples.add((await image.toByteData())!);
      image.dispose();
    }
    int alpha(int layer, int x, int y) => pixel(samples[layer], 192, x, y) & 255;
    expect(alpha(0, 96, 96), greaterThan(80));
    expect(alpha(0, 127, 96), greaterThan(15));
    expect(alpha(0, 49, 49), lessThanOrEqualTo(1));
    expect(alpha(0, 144, 96), lessThanOrEqualTo(1));
    expect(alpha(1, 96, 96), lessThan(alpha(0, 96, 96)));
    expect(alpha(1, 131, 96), lessThan(alpha(0, 131, 96)));
    for (final shadow in shadows) {
      shadow.image.dispose();
    }
    atlas.dispose();
  });

  test('wall depth stays inside rooms and leaves doorways clear', () async {
    final floor = FloorPlan(id: 'depth', name: 'Depth', nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 0),
      PlanNode(id: 'c', xMm: 2000, yMm: 2000),
      PlanNode(id: 'd', xMm: 0, yMm: 2000),
    ], walls: [
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b', thicknessMm: 200,
        openings: [WallOpening(id: 'door', type: OpeningType.door,
          widthMm: 800, heightMm: 2100, offsetFromStartMm: 600)]),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c', thicknessMm: 200),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd', thicknessMm: 200),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a', thicknessMm: 200),
    ]);
    for (final face in GeometryService.roomFaces(floor)) {
      floor.roomMetas.add(RoomMeta(id: face.key, faceKey: face.key, name: '',
        materials: RoomMaterialSettings(floorMaterialId: 'paint-warm-white')));
    }
    Future<ByteData> pixels(bool depth, {bool walls = true}) async {
      final categories = PlanDisplayLayer.values.toSet()
        ..remove(PlanDisplayLayer.roomLabels);
      if (!walls) categories.remove(PlanDisplayLayer.walls);
      final image = await render((canvas) {
        CadPlanPainterV3(floor: floor, mmToPx: .1,
          origin: const Offset(30, 30), showGrid: false, showDimensions: false,
          showDepth: depth, visibleCategories: categories,
        ).paint(canvas, const Size(260, 260));
      }, 260, 260);
      final bytes = (await image.toByteData())!;
      image.dispose();
      return bytes;
    }
    final flat = await pixels(false);
    final depth = await pixels(true);
    expect(pixel(depth, 260, 43, 130) >> 24,
        lessThan(pixel(flat, 260, 43, 130) >> 24));
    for (final point in [const Offset(130, 42), const Offset(130, 130),
      const Offset(12, 130)]) {
      expect(pixel(depth, 260, point.dx.toInt(), point.dy.toInt()),
          pixel(flat, 260, point.dx.toInt(), point.dy.toInt()));
    }
    final hiddenFlat = await pixels(false, walls: false);
    final hiddenDepth = await pixels(true, walls: false);
    expect(hiddenDepth.buffer.asUint8List(), hiddenFlat.buffer.asUint8List());
  });

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

  test('neutral furniture keeps its physical footprint when rotated', () async {
    await ImportedTopViewAssets.instance.ensureLoaded();
    for (final id in [
      'sofa-3',
      'bed-180',
      'armchair',
      'dining-table-1800',
      'coffee-table-oval',
      'wardrobe-3',
      'chair',
      'rug-gray',
    ]) {
      final item = ObjectCatalog.byId(id);
      for (final angle in [0.0, 90.0]) {
        final floor = FloorPlan(
          id: 'f',
          name: 'Rotation',
          planObjects: [
            object('s', id, 0, 0, item.widthMm, item.depthMm, rotation: angle),
          ],
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
        final width = (angle == 0 ? item.widthMm : item.depthMm) * .1;
        final depth = (angle == 0 ? item.depthMm : item.widthMm) * .1;
        expect(right - left + 1, closeTo(width, 4), reason: '$id at $angle');
        expect(bottom - top + 1, closeTo(depth, 4), reason: '$id at $angle');
        expect((left + right) / 2, closeTo(159.5, 2));
        expect((top + bottom) / 2, closeTo(159.5, 2));
        image.dispose();
      }
    }
  });

  test('neutral furniture decodes and real plan preview renders', () async {
    final assets = ImportedTopViewAssets.instance;
    await assets.ensureLoaded();
    var decodedBytes = 0;
    for (final id in [
      'sofa-3',
      'bed-180',
      'armchair',
      'dining-table-1800',
      'coffee-table-oval',
      'wardrobe-3',
      'chair',
      'rug-gray',
    ]) {
      expect(ImportedTopViewAssets.hasNeutralTopView(id), isTrue);
      final sprite = assets.neutralForCatalog(id);
      expect(
        sprite,
        isNotNull,
        reason: '$id must not silently use the old atlas',
      );
      expect(sprite!.sourceRect.width, greaterThan(id == 'chair' ? 400 : 650));
      expect(sprite.sourceRect.right, lessThanOrEqualTo(sprite.image.width));
      decodedBytes += sprite.image.width * sprite.image.height * 4;
      expect(assets.contactShadowForCatalog(id), isNotNull,
          reason: '$id must have a cached contact mask');
    }
    expect(decodedBytes, lessThan(16 * 1024 * 1024));
    expect(assets.contactShadowBytes, lessThanOrEqualTo(8 * 1024 * 1024));
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
      final detail = await render(
        (canvas) {
          CadPlanPainterV3(
            floor: livingRoomPreview(),
            mmToPx: .21,
            origin: const Offset(96, 100),
            showGrid: false,
            showDimensions: false,
            visibleCategories: PlanDisplayLayer.values.toSet()
              ..remove(PlanDisplayLayer.roomLabels),
          ).paint(canvas, const Size(1200, 1420));
        },
        1200,
        1420,
      );
      final detailPng =
          (await detail.toByteData(format: ui.ImageByteFormat.png))!;
      await File('docs/previews/living-room-review.png').writeAsBytes(
        detailPng.buffer.asUint8List(
          detailPng.offsetInBytes, detailPng.lengthInBytes,
        ),
      );
      detail.dispose();
    }
    image.dispose();
  });
}
