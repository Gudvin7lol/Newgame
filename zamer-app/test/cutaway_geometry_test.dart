import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/cutaway_geometry.dart';

void main() {
  const target = math.Point<double>(0, 0);
  const camera = math.Point<double>(0, 5);

  test(
    'long wall is cut even when its centre is outside the view corridor',
    () {
      final hidden = zamerWallSegmentOccludesCutaway(
        start: const math.Point<double>(-5, 2),
        end: const math.Point<double>(1, 2),
        target: target,
        camera: camera,
        corridorHalfWidth: 0.75,
      );
      expect(hidden, isTrue);
    },
  );

  test('side wall outside corridor remains visible', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(3, 0.5),
      end: const math.Point<double>(3, 4),
      target: target,
      camera: camera,
      corridorHalfWidth: 0.75,
    );
    expect(hidden, isFalse);
  });

  test('wall behind the orbit target remains visible', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(-1, -1),
      end: const math.Point<double>(1, -1),
      target: target,
      camera: camera,
      corridorHalfWidth: 0.75,
    );
    expect(hidden, isFalse);
  });

  test('wall almost at camera is outside the cutaway band', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(-1, 4.8),
      end: const math.Point<double>(1, 4.8),
      target: target,
      camera: camera,
      corridorHalfWidth: 0.75,
    );
    expect(hidden, isFalse);
  });

  test('segment entering the axial band is detected', () {
    final hidden = zamerWallSegmentOccludesCutaway(
      start: const math.Point<double>(0.2, -1),
      end: const math.Point<double>(0.2, 2),
      target: target,
      camera: camera,
      corridorHalfWidth: 0.30,
      lateralMargin: 0,
    );
    expect(hidden, isTrue);
  });
}
