import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/floor_grout_geometry.dart';
import 'package:zamer_app/renderer3d/herringbone_surface_geometry.dart';

double polygonArea(List<math.Point<double>> points) {
  var area = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area.abs() / 2;
}

bool pointInside(
  math.Point<double> point,
  List<math.Point<double>> polygon,
) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    final crosses = (a.y > point.y) != (b.y > point.y);
    if (!crosses) continue;
    final hitX =
        (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
    if (point.x < hitX) inside = !inside;
  }
  return inside;
}

void main() {
  test('clipped herringbone planks cover a rectangular room without gaps', () {
    const room = <math.Point<double>>[
      math.Point<double>(0, 0),
      math.Point<double>(3200, 0),
      math.Point<double>(3200, 2200),
      math.Point<double>(0, 2200),
    ];

    final pieces = buildHerringboneSurfacePolygons(
      polygonMm: room,
      anchorXMm: 0,
      anchorYMm: 0,
      directionDeg: 17,
      plankLengthMm: 900,
      plankWidthMm: 150,
      offsetXMm: 140,
      offsetYMm: 55,
    );

    expect(pieces, isNotEmpty);
    final coveredArea = pieces.fold<double>(
      0,
      (sum, piece) =>
          sum + polygonArea(piece.vertices.map((e) => e.pointMm).toList()),
    );
    expect(coveredArea, closeTo(3200 * 2200, 3200 * 2200 * .005));

    final variants = pieces.map((e) => e.atlasVariant).toSet();
    expect(variants.length, greaterThanOrEqualTo(8));
    expect(variants.every((e) => e >= 0 && e < 16), isTrue);

    for (final piece in pieces) {
      for (final vertex in piece.vertices) {
        expect(vertex.u, inInclusiveRange(0, 1));
        expect(vertex.v, inInclusiveRange(0, 1));
      }
    }
  });

  test('concave room clips every herringbone piece inside the finish polygon', () {
    const room = <math.Point<double>>[
      math.Point<double>(0, 0),
      math.Point<double>(3000, 0),
      math.Point<double>(3000, 1000),
      math.Point<double>(1600, 1000),
      math.Point<double>(1600, 2400),
      math.Point<double>(0, 2400),
    ];

    final pieces = buildHerringboneSurfacePolygons(
      polygonMm: room,
      anchorXMm: 300,
      anchorYMm: 200,
      directionDeg: 42,
      plankLengthMm: 800,
      plankWidthMm: 140,
      offsetXMm: 70,
      offsetYMm: 40,
    );

    expect(pieces, isNotEmpty);
    for (final piece in pieces) {
      for (final vertex in piece.vertices) {
        final p = vertex.pointMm;
        final onBoundary =
            p.x.abs() < 1e-5 ||
            p.y.abs() < 1e-5 ||
            (p.x - 3000).abs() < 1e-5 ||
            (p.y - 2400).abs() < 1e-5 ||
            (p.y - 1000).abs() < 1e-5 ||
            (p.x - 1600).abs() < 1e-5;
        expect(
          pointInside(p, room) || onBoundary,
          isTrue,
          reason: 'Herringbone vertex escaped room: $p',
        );
      }
    }
  });

  test('GPU uses a separate stable layer between floor base and seams', () {
    expect(zamerFloorPatternYM, greaterThan(zamerFloorSurfaceYM));
    expect(zamerFloorPatternYM, lessThan(zamerFloorGroutYM));

    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();
    expect(source, contains('_buildFloorHerringboneSurfaceNode'));
    expect(source, contains("name: 'floor-herringbone-pbr:"));
    expect(source, contains('buildHerringboneSurfacePolygons('));
    expect(source, contains('zamerFloorPatternYM'));
    expect(source, contains("plankAtlasMapAsset('basecolor.webp')"));
    expect(source, contains("plankAtlasMapAsset('normal.png')"));
    expect(source, contains("plankAtlasMapAsset('metallic_roughness.png')"));
  });
}
