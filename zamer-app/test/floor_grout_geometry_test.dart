import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/floor_grout_geometry.dart';

void main() {
  test('floor grout keeps configured real width in millimetres', () {
    final quads = buildFloorTileGroutQuads(
      polygonMm: const [
        math.Point(0, 0),
        math.Point(1200, 0),
        math.Point(1200, 1200),
        math.Point(0, 1200),
      ],
      anchorXMm: 0,
      anchorYMm: 0,
      directionDeg: 0,
      tileWidthMm: 600,
      tileHeightMm: 600,
      offsetXMm: 0,
      offsetYMm: 0,
      groutMm: 4,
    );

    expect(quads, isNotEmpty);
    final vertical = quads.firstWhere(
      (q) => (q.pointsMm[0].x - q.pointsMm[1].x).abs() > 0.1,
    );
    final width = (vertical.pointsMm[0].x - vertical.pointsMm[1].x).abs();
    expect(width, closeTo(4, 0.0001));
  });

  test('half pattern staggers vertical joints by half a tile', () {
    final quads = buildFloorTileGroutQuads(
      polygonMm: const [
        math.Point(0, 0),
        math.Point(1800, 0),
        math.Point(1800, 1200),
        math.Point(0, 1200),
      ],
      anchorXMm: 0,
      anchorYMm: 0,
      directionDeg: 0,
      tileWidthMm: 600,
      tileHeightMm: 600,
      offsetXMm: 0,
      offsetYMm: 0,
      groutMm: 2,
      pattern: 'half',
    );

    final centers = quads
        .where((q) => (q.pointsMm[0].x - q.pointsMm[1].x).abs() > 0.1)
        .map((q) => (q.pointsMm[0].x + q.pointsMm[1].x) / 2)
        .toSet();
    expect(centers.any((x) => (x - 300).abs() < 0.01), isTrue);
    expect(centers.any((x) => (x - 600).abs() < 0.01), isTrue);
  });
}
