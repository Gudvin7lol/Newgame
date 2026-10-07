import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/door_floor_bridge.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';

void main() {
  ZamerFloorSurface floorSurface({
    required String roomKey,
    required double minY,
    required double maxY,
    required String materialId,
  }) {
    return ZamerFloorSurface(
      roomKey: roomKey,
      polygonMm: <math.Point<double>>[
        math.Point<double>(-2000, minY),
        math.Point<double>(2000, minY),
        math.Point<double>(2000, maxY),
        math.Point<double>(-2000, maxY),
      ],
      materialMode: 'laminate',
      materialId: materialId,
      directionDeg: 0,
      tileWidthMm: 600,
      tileHeightMm: 600,
      plankLengthMm: 1380,
      plankWidthMm: 193,
      laminatePattern: 'straight',
      laminateOffsetMode: 'none',
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
  }

  ZamerOpeningPlacement opening(OpeningType type) {
    return ZamerOpeningPlacement(
      id: 'opening-1',
      wallId: 'wall-1',
      type: type,
      xMm: 0,
      yMm: 0,
      widthMm: 900,
      heightMm: 2100,
      sillHeightMm: 0,
      wallThicknessMm: 100,
      rotationRad: 0,
      doorSwing: DoorSwing.leftIn,
    );
  }

  test('door threshold splits wall depth between different room finishes', () {
    final lower = floorSurface(
      roomKey: 'lower',
      minY: -2000,
      maxY: -50,
      materialId: 'oak-natural',
    );
    final upper = floorSurface(
      roomKey: 'upper',
      minY: 50,
      maxY: 2000,
      materialId: 'tile-marble',
    );

    final segments = buildDoorFloorBridgeSegments(
      opening: opening(OpeningType.door),
      floors: <ZamerFloorSurface>[lower, upper],
    );

    expect(segments, hasLength(2));
    final lowerSegment = segments.firstWhere(
      (segment) => segment.surface.roomKey == 'lower',
    );
    final upperSegment = segments.firstWhere(
      (segment) => segment.surface.roomKey == 'upper',
    );

    expect(lowerSegment.pointsMm.map((p) => p.x).reduce(math.min), -450);
    expect(lowerSegment.pointsMm.map((p) => p.x).reduce(math.max), 450);
    expect(lowerSegment.pointsMm.map((p) => p.y).reduce(math.min), -50);
    expect(lowerSegment.pointsMm.map((p) => p.y).reduce(math.max), 0);
    expect(upperSegment.pointsMm.map((p) => p.y).reduce(math.min), 0);
    expect(upperSegment.pointsMm.map((p) => p.y).reduce(math.max), 50);
  });

  test('same nearby finish covers the complete exterior threshold', () {
    final inside = floorSurface(
      roomKey: 'inside',
      minY: 50,
      maxY: 2000,
      materialId: 'oak-natural',
    );

    final segments = buildDoorFloorBridgeSegments(
      opening: opening(OpeningType.door),
      floors: <ZamerFloorSurface>[inside],
    );

    expect(segments, hasLength(1));
    expect(segments.single.surface.roomKey, 'inside');
    expect(segments.single.pointsMm.map((p) => p.y).reduce(math.min), -50);
    expect(segments.single.pointsMm.map((p) => p.y).reduce(math.max), 50);
  });

  test('window never receives a floor threshold bridge', () {
    final room = floorSurface(
      roomKey: 'room',
      minY: 50,
      maxY: 2000,
      materialId: 'oak-natural',
    );

    expect(
      buildDoorFloorBridgeSegments(
        opening: opening(OpeningType.window),
        floors: <ZamerFloorSurface>[room],
      ),
      isEmpty,
    );
  });
}
