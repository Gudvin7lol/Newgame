import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/widgets/cad_plan_painter_v2.dart';

void main() {
  testWidgets('raster is painted once; missing images use the vector fallback',
      (tester) async {
    final floor = FloorPlan(
      id: 'floor',
      name: 'Test',
      planObjects: [
        PlanObject(
          id: 'sofa',
          type: PlanObjectType.furniture,
          xMm: 1000,
          yMm: 500,
          widthMm: 2200,
          depthMm: 900,
          catalogId: 'sofa-3',
        ),
      ],
    );
    var calls = 0;
    Offset? center;
    final painter = CadPlanPainterV2(
      floor: floor,
      mmToPx: .1,
      origin: const Offset(120, 140),
      showGrid: false,
      showDimensions: false,
      drawTopView: (canvas, object, position, scale) {
        calls++;
        expect(object.id, 'sofa');
        expect(scale, .1);
        center = position;
        return true;
      },
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(600, 480));
    recorder.endRecording().dispose();
    expect(calls, 1);
    expect(center, const Offset(220, 190));

    var missingCount = 0;
    final fallback = CadPlanPainterV2(
      floor: floor,
      mmToPx: .1,
      origin: const Offset(120, 140),
      showGrid: false,
      showDimensions: false,
      drawTopView: (_, _, _, _) {
        missingCount++;
        return false;
      },
    );
    final backup = ui.PictureRecorder();
    fallback.paint(Canvas(backup), const Size(600, 480));
    backup.endRecording().dispose();
    expect(missingCount, 1);
  });

  test('raster is in CAD object pass below labels and dimensions', () {
    final v2 = File('lib/widgets/cad_plan_painter_v2.dart').readAsStringSync();
    final v3 = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final assets =
        File('lib/services/imported_top_view_assets.dart').readAsStringSync();

    expect(v2.indexOf('_objects(canvas);'),
        lessThan(v2.indexOf('_roomLabels(canvas, faces);')));
    expect(v2.contains('drawTopView?.call(canvas, object, center, mmToPx)'),
        isTrue);
    expect(v3.contains('drawTopView: _drawImportedObject'), isTrue);
    expect(v3.contains('for (final object in floor.planObjects)'), isFalse);
    expect(assets.contains("'bed-160': 'featured_bed_180'"), isTrue);
    expect(assets.contains('decodedByFile'), isTrue);
  });
}
