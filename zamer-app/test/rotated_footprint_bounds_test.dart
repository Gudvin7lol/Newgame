import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/rotated_footprint_bounds.dart';

void main() {
  test('unrotated footprint keeps local half extents', () {
    final bounds = zamerRotatedFootprintHalfExtentsMm(
      widthMm: 2000,
      depthMm: 500,
      rotationDeg: 0,
    );
    expect(bounds.halfX, closeTo(1000, 0.0001));
    expect(bounds.halfY, closeTo(250, 0.0001));
  });

  test('90 degree rotation swaps long and short footprint axes', () {
    final bounds = zamerRotatedFootprintHalfExtentsMm(
      widthMm: 2000,
      depthMm: 500,
      rotationDeg: 90,
    );
    expect(bounds.halfX, closeTo(250, 0.0001));
    expect(bounds.halfY, closeTo(1000, 0.0001));
  });

  test('45 degree rotation expands both world axes correctly', () {
    final bounds = zamerRotatedFootprintHalfExtentsMm(
      widthMm: 2000,
      depthMm: 500,
      rotationDeg: 45,
    );
    final expected = (1000 + 250) / math.sqrt(2);
    expect(bounds.halfX, closeTo(expected, 0.0001));
    expect(bounds.halfY, closeTo(expected, 0.0001));
  });

  test('negative imported dimensions cannot invert scene bounds', () {
    final bounds = zamerRotatedFootprintHalfExtentsMm(
      widthMm: -2000,
      depthMm: -500,
      rotationDeg: 90,
    );
    expect(bounds.halfX, closeTo(250, 0.0001));
    expect(bounds.halfY, closeTo(1000, 0.0001));
  });
}
