import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/cutaway_geometry.dart';

void main() {
  test('cutaway hides a wall that crosses the camera-target corridor', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point(-1.0, 2.0),
      end: const math.Point(1.0, 2.0),
      target: const math.Point(0.0, 0.0),
      camera: const math.Point(0.0, 6.0),
      corridorHalfWidth: 3.0,
    );

    expect(hidden, isTrue);
  });

  test('cutaway keeps a side wall near the orbit target visible', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point(1.25, 0.25),
      end: const math.Point(1.25, 1.25),
      target: const math.Point(0.0, 0.0),
      camera: const math.Point(0.0, 6.0),
      corridorHalfWidth: 3.0,
      lateralMargin: 0.10,
    );

    expect(hidden, isFalse);
  });

  test('cutaway remains stable for a diagonal segment crossing the view axis', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point(-2.0, 1.0),
      end: const math.Point(2.0, 4.0),
      target: const math.Point(0.0, 0.0),
      camera: const math.Point(0.0, 7.0),
      corridorHalfWidth: 3.2,
    );

    expect(hidden, isTrue);
  });
}
