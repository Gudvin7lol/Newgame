import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/plan_viewport_link.dart';

void main() {
  test('different CAD canvas origins reconstruct one world-space camera', () {
    const screen = Size(400, 700);
    const planOrigin = Offset(16000, 16000);
    const floorOrigin = Offset(3300, 1100);
    const saved = PlanViewportSnapshot(
      centerXMm: 4000, centerYMm: 2500, pixelsPerMm: .18);
    final planMatrix = saved.toCanvasTransform(
      viewport: screen, origin: planOrigin, mmToPx: .1)!;
    final floorMatrix = saved.toCanvasTransform(
      viewport: screen, origin: floorOrigin, mmToPx: .1)!;
    final fromPlan = PlanViewportSnapshot.capture(
      viewport: screen, origin: planOrigin,
      mmToPx: .1, transform: planMatrix)!;
    final fromFloor = PlanViewportSnapshot.capture(
      viewport: screen, origin: floorOrigin,
      mmToPx: .1, transform: floorMatrix)!;
    expect(fromPlan.centerXMm, closeTo(4000, .01));
    expect(fromPlan.centerYMm, closeTo(2500, .01));
    expect(fromFloor.centerXMm, closeTo(4000, .01));
    expect(fromFloor.centerYMm, closeTo(2500, .01));
    expect(fromFloor.pixelsPerMm, closeTo(.18, .00001));
    expect(fromPlan.nearlyEquals(fromFloor), isTrue);
  });

  test('viewport snapshot rejects invalid camera values', () {
    const invalid = PlanViewportSnapshot(
      centerXMm: double.nan, centerYMm: 0, pixelsPerMm: .2);
    expect(invalid.valid, isFalse);
    expect(invalid.toCanvasTransform(
      viewport: const Size(300, 600),
      origin: Offset.zero, mmToPx: .1), isNull);
    expect(PlanViewportSnapshot.capture(
      viewport: Size.zero, origin: Offset.zero,
      mmToPx: .1, transform: Matrix4.identity()), isNull);
  });

  test('live Measure links only Plan Floor and Objects to one camera', () {
    final src = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    expect(src, contains('final ValueNotifier<PlanViewportSnapshot?> _sharedViewport'));
    expect(src, contains('viewportActive: _layer == 0'));
    expect(src, contains('viewportActive: _layer == 1'));
    expect(src, contains('viewportActive: _layer == 2'));
    expect(src, contains('_sharedViewport.dispose()'));
  });

  test('all three editors publish camera and adopt world state on selection', () {
    for (final path in [
      'lib/screens/plan_editor_master_v4_screen.dart',
      'lib/screens/measure_floor_plan_layer_screen.dart',
      'lib/screens/planning_objects_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('void _publishViewport()'), reason: path);
      expect(src, contains('void _adoptViewport()'), reason: path);
      expect(src, contains('widget.viewportActive'), reason: path);
    }
  });
}
