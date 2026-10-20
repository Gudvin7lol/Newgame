import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/door_floor_bridge.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';

ZamerFloorSurface surface(String key, double minY, double maxY,
    {bool shared = false}) => ZamerFloorSurface(
  roomKey: key,
  sharedFloorGroup: shared,
  polygonMm: [
    math.Point<double>(0, minY),
    math.Point<double>(3000, minY),
    math.Point<double>(3000, maxY),
    math.Point<double>(0, maxY),
  ],
  materialMode: 'laminate',
  materialId: 'oak-natural',
  tintArgb: 0,
  ceilingMaterialId: '',
  ceilingColorArgb: 0,
  directionDeg: 0,
  tileWidthMm: 600,
  tileHeightMm: 600,
  plankLengthMm: 1200,
  plankWidthMm: 200,
  laminatePattern: 'straight',
  laminateOffsetMode: 'center',
  laminateOffsetXMm: 0,
  laminateOffsetYMm: 0,
  tilePattern: 'straight',
  tileOffsetXMm: 0,
  tileOffsetYMm: 0,
  groutMm: 2,
  anchorXMm: 0,
  anchorYMm: 0,
  ceilingHeightMm: 2700,
);

ZamerOpeningPlacement door(DoorSwing swing) => ZamerOpeningPlacement(
  id: 'd', wallId: 'w', type: OpeningType.door,
  xMm: 1500, yMm: 0,
  widthMm: 800, heightMm: 2100, sillHeightMm: 0,
  wallThicknessMm: 100, rotationRad: 0, doorSwing: swing,
);

void main() {
  final pos = surface('positive', 30, 1200);
  final neg = surface('negative', -1200, -30);

  test('3D threshold runs 20mm beyond positive-side face for inward swing', () {
    final results = buildDoorFloorBridgeSegments(
      opening: door(DoorSwing.leftIn), floors: [pos, neg],
    );
    expect(results, hasLength(1));
    expect(results.single.surface.roomKey, 'negative');
    expect(results.single.pointsMm.map((e) => e.y).reduce(math.min), -50);
    expect(results.single.pointsMm.map((e) => e.y).reduce(math.max), 70);
  });

  test('3D threshold direction reverses for outward swing', () {
    final results = buildDoorFloorBridgeSegments(
      opening: door(DoorSwing.rightOut), floors: [pos, neg],
    );
    expect(results, hasLength(1));
    expect(results.single.surface.roomKey, 'positive');
    expect(results.single.pointsMm.map((e) => e.y).reduce(math.min), -70);
    expect(results.single.pointsMm.map((e) => e.y).reduce(math.max), 50);
  });

  test('explicitly joined finish group has no second-room threshold patch', () {
    final joined = buildDoorFloorBridgeSegments(
      opening: door(DoorSwing.rightIn),
      floors: [
        surface('positive', 30, 1200, shared: true),
        surface('negative', -1200, -30, shared: true),
      ],
    );
    expect(joined, hasLength(1));
    expect(joined.single.surface.sharedFloorGroup, isTrue);
  });
}
