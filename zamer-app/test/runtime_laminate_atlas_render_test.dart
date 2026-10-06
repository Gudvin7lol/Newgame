import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/floor_grout_geometry.dart';
import 'package:zamer_app/services/runtime_material_pack_v4.dart';

void main() {
  test('one-third stagger moves vertical plank seams by one third per row', () {
    final quads = buildFloorTileGroutQuads(
      polygonMm: const <math.Point<double>>[
        math.Point<double>(0, 0),
        math.Point<double>(3000, 0),
        math.Point<double>(3000, 600),
        math.Point<double>(0, 600),
      ],
      anchorXMm: 0,
      anchorYMm: 0,
      directionDeg: 0,
      tileWidthMm: 900,
      tileHeightMm: 200,
      offsetXMm: 0,
      offsetYMm: 0,
      groutMm: 1.2,
      pattern: 'third',
    );

    final verticalCenters = <math.Point<double>>[];
    for (final quad in quads) {
      final xs = quad.pointsMm.map((p) => p.x).toList();
      final ys = quad.pointsMm.map((p) => p.y).toList();
      final width = xs.reduce(math.max) - xs.reduce(math.min);
      final height = ys.reduce(math.max) - ys.reduce(math.min);
      if (width < 5 && height > 40) {
        verticalCenters.add(
          math.Point<double>(
            xs.reduce((a, b) => a + b) / xs.length,
            ys.reduce((a, b) => a + b) / ys.length,
          ),
        );
      }
    }

    bool hasCenter(double x, double y) => verticalCenters.any(
      (p) => (p.x - x).abs() < 2 && (p.y - y).abs() < 2,
    );

    expect(hasCenter(900, 100), isTrue);
    expect(hasCenter(300, 300), isTrue);
    expect(hasCenter(600, 500), isTrue);
  });

  test('runtime laminate atlas names follow the physical stagger mode', () {
    final laminate = RuntimeMaterialPackV4.byId('Laminate_OakSmoked_01');

    expect(
      laminate.plankAtlasMapAsset('basecolor.webp'),
      endsWith('Laminate_OakSmoked_01_plank_atlas_basecolor.webp'),
    );
    expect(
      laminate.plankAtlasMapAsset('normal.png', offsetMode: 'half'),
      endsWith('Laminate_OakSmoked_01_plank_atlas_half_normal.png'),
    );
    expect(
      laminate.plankAtlasMapAsset(
        'metallic_roughness.png',
        offsetMode: 'third',
      ),
      endsWith(
        'Laminate_OakSmoked_01_plank_atlas_third_metallic_roughness.png',
      ),
    );
    expect(laminate.plankAtlasRowsFor('straight'), 4);
    expect(laminate.plankAtlasRowsFor('half'), 6);
    expect(laminate.plankAtlasRowsFor('third'), 6);
  });

  test('GPU floor renderer consumes Runtime v4 atlases and real plank seams', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(source, contains('RuntimeMaterialPackV4.maybeById'));
    expect(source, contains('_runtimeLaminateAtlasCandidates'));
    expect(source, contains('plankAtlasMapAsset('));
    expect(source, contains("'basecolor.webp'"));
    expect(source, contains("'normal.png'"));
    expect(source, contains("'floor-laminate-seams:"));
    expect(source, contains('tileWidthMm: surface.plankLengthMm'));
    expect(source, contains('tileHeightMm: surface.plankWidthMm'));
    expect(source, contains('pattern: surface.laminateOffsetMode'));
  });
}
