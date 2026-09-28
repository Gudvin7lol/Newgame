import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/widgets/floor_3d_painter.dart';

FloorPlan _offsetRoom() {
  final floor = FloorPlan(id: 'raster', name: 'Raster');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 10000, yMm: 20000),
    PlanNode(id: 'b', xMm: 13000, yMm: 20000),
    PlanNode(id: 'c', xMm: 13000, yMm: 23000),
    PlanNode(id: 'd', xMm: 10000, yMm: 23000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
  ]);
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

Future<int> _laminatePixels(FloorPlan floor) async {
  const size = Size(480, 480);
  final recorder = ui.PictureRecorder();
  Floor3DPainter(
    floor: floor,
    rotation: 0,
    tilt: 0.82,
    zoom: 0.92,
    cutaway: true,
  ).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 480);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(bytes, isNotNull);
  final data = bytes!.buffer.asUint8List();
  var wood = 0;
  for (var y = 0; y < 480; y++) {
    for (var x = 0; x < 480; x++) {
      final i = (y * 480 + x) * 4;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      // The plank fills have these beige RGB channels, unlike the floor
      // fallback. Count actual rasterized planks, not successful paint calls.
      if ((r == 0xE2 && g == 0xD3 && b == 0xBE) ||
          (r == 0xD9 && g == 0xC8 && b == 0xB0) ||
          (r == 0xE8 && g == 0xDA && b == 0xC8) ||
          (r == 0xE3 && g == 0xD7 && b == 0xC5) ||
          (r == 0xD4 && g == 0xC6 && b == 0xB3)) {
        wood++;
      }
    }
  }
  image.dispose();
  picture.dispose();
  return wood;
}

Future<List<int>> _pixels(FloorPlan floor, double rotation) async {
  const size = Size(480, 480);
  final recorder = ui.PictureRecorder();
  Floor3DPainter(
    floor: floor,
    rotation: rotation,
    tilt: 0.82,
    zoom: 0.92,
  ).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 480);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final data = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return data;
}

void main() {
  testWidgets('3D laminate covers a room far from the plan origin', (
    tester,
  ) async {
    final floor = _offsetRoom();
    final settings = floor.roomMetas.first.materials;
    settings.floorMode = 'laminate';
    expect(
      await tester.runAsync(() => _laminatePixels(floor)),
      greaterThan(500),
    );

    settings.laminatePattern = 'herringbone';
    expect(
      await tester.runAsync(() => _laminatePixels(floor)),
      greaterThan(500),
    );
  });

  testWidgets('furniture stays visible from multiple camera angles', (
    tester,
  ) async {
    final floor = _offsetRoom();
    for (final angle in [-0.65, 0.7]) {
      final background = (await tester.runAsync(() => _pixels(floor, angle)))!;
      floor.planObjects.add(
        PlanObject(
          id: 'sofa',
          type: PlanObjectType.furniture,
          catalogId: 'sofa-3',
          xMm: 11500,
          yMm: 21500,
          widthMm: 2100,
          depthMm: 900,
          heightMm: 850,
        ),
      );
      final withSofa = (await tester.runAsync(() => _pixels(floor, angle)))!;
      floor.planObjects.clear();
      var changed = 0;
      for (var i = 0; i < withSofa.length; i += 4) {
        if (withSofa[i] != background[i] ||
            withSofa[i + 1] != background[i + 1] ||
            withSofa[i + 2] != background[i + 2]) {
          changed++;
        }
      }
      expect(changed, greaterThan(100), reason: 'angle: $angle');
    }
  });
}
