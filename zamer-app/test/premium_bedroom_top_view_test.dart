import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/object_catalog.dart';
import 'package:zamer_app/widgets/top_view_object_renderer.dart';

void main() {
  testWidgets('01.1.2A bedroom and lounge vector symbols render for all sizes',
      (tester) async {
    const ids = <String>[
      'bed-160',
      'bed-180',
      'sofa-2',
      'sofa-3',
      'sofa-corner',
      'armchair',
      'ottoman',
      'wardrobe-2',
      'wardrobe-3',
      'nightstand',
      'dresser-1200',
      'tv-console-1600',
      'shelf',
    ];
    for (final id in ids) {
      final item = ObjectCatalog.byId(id);
      final object = PlanObject(
        id: id,
        type: item.type,
        xMm: 0,
        yMm: 0,
        widthMm: item.widthMm,
        depthMm: item.depthMm,
        heightMm: item.heightMm,
        catalogId: item.id,
      );
      // Fit the actual physical footprint rather than stretching square icons.
      final scale = math.min(150 / item.widthMm, 150 / item.depthMm);
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      TopViewObjectRenderer.draw(
        canvas,
        object,
        center: const Offset(100, 100),
        mmToPx: scale,
      );
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(200, 200);
      try {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(rgba, isNotNull, reason: '$id did not produce pixels');
        final bytes = rgba!.buffer.asUint8List();
        final centerAlpha = bytes[(100 * 200 + 100) * 4 + 3];
        expect(centerAlpha, greaterThan(0),
            reason: '$id must have an actual filled top-view body');
        final cornerAlpha = bytes[(5 * 200 + 5) * 4 + 3];
        expect(cornerAlpha, 0,
            reason: '$id must not paint over the whole CAD workspace');
      } finally {
        image.dispose();
        picture.dispose();
      }
    }
  });

  test('top-view catalogue uses the exact plan painter, never a 3D camera',
      () {
    final source =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();
    final preview = source
        .split('Widget _modelPreview(ObjectCatalogItem item, double size) {')
        .last
        .split('Future<void> _chooseModel()')
        .first;
    expect(preview.contains('painter: _PlanningPainter('), isTrue);
    expect(preview.contains('ZamerModelThumbnail('), isFalse);
    expect(preview.contains('widthMm: item.widthMm'), isTrue);
    expect(preview.contains('depthMm: item.depthMm'), isTrue);
    expect(preview.contains('scale: scale'), isTrue);
  });

  test('shared vector fallback keeps premium material and furniture details',
      () {
    final src =
        File('lib/widgets/top_view_object_renderer.dart').readAsStringSync();
    for (final method in const [
      '_softCushion(',
      '_fabricPaint(',
      '_woodPaint(',
      '_woodGrain(',
      '_hardware(',
      '_cornerSofa(',
      '_storage(',
    ]) {
      expect(src.contains(method), isTrue, reason: 'Missing detail: $method');
    }
  });
}
