import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/cutaway_corridor_policy.dart';
import 'package:zamer_app/renderer3d/cutaway_geometry.dart';

void main() {
  test('normal orbit keeps cutaway focused around the camera-target line', () {
    final width = ZamerCutawayCorridorPolicy.halfWidth(
      cameraDistanceM: 5,
      fovDegrees: 46,
    );
    expect(width, greaterThan(0.8));
    expect(width, lessThan(1.1));
  });

  test('large rooms cannot inflate cutaway across unrelated side walls', () {
    final width = ZamerCutawayCorridorPolicy.halfWidth(
      cameraDistanceM: 20,
      fovDegrees: 70,
    );
    expect(width, ZamerCutawayCorridorPolicy.maxHalfWidthM);
  });

  test('close camera still gets a useful minimum cutaway corridor', () {
    final width = ZamerCutawayCorridorPolicy.halfWidth(
      cameraDistanceM: 1.2,
      fovDegrees: 35,
    );
    expect(width, ZamerCutawayCorridorPolicy.minHalfWidthM);
  });

  test('side wall stays visible while central wall still cuts away', () {
    const target = math.Point<double>(0, 0);
    const camera = math.Point<double>(0, 5);
    final corridor = ZamerCutawayCorridorPolicy.halfWidth(
      cameraDistanceM: 5,
      fovDegrees: 46,
    );

    final central = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(-2, 2),
      end: const math.Point<double>(2, 2),
      target: target,
      camera: camera,
      corridorHalfWidth: corridor,
    );
    final side = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(1.8, 0.4),
      end: const math.Point<double>(1.8, 4.0),
      target: target,
      camera: camera,
      corridorHalfWidth: corridor,
    );

    expect(central, isTrue);
    expect(side, isFalse);
  });

  test('invalid camera data falls back to a bounded corridor', () {
    expect(
      ZamerCutawayCorridorPolicy.halfWidth(
        cameraDistanceM: double.nan,
        fovDegrees: 46,
      ),
      ZamerCutawayCorridorPolicy.fallbackHalfWidthM,
    );
  });
}
