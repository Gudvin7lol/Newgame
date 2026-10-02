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
    final quad = quads.first;
    final a = quad.pointsMm[0];
    final b = quad.pointsMm[1];
    final d = quad.pointsMm[3];
    final sideAb = math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    final sideAd = math.sqrt(math.pow(a.x - d.x, 2) + math.pow(a.y - d.y, 2));
    expect(math.min(sideAb, sideAd), closeTo(4, 0.0001));
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

  test('grout overlay keeps a mobile-safe depth separation from floor', () {
    expect(zamerFloorSurfaceYM, greaterThan(0));
    expect(zamerFloorGroutYM, greaterThan(zamerFloorSurfaceYM));
    expect(zamerFloorGroutSeparationM, greaterThanOrEqualTo(0.002));
    expect(zamerFloorGroutSeparationM, lessThanOrEqualTo(0.003));
  });
}
