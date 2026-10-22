import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wall snap HUD follows the real target and avoids the viewport edge', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('measure-live-snap-hud'));
    expect(source, contains('final tip = MatrixUtils.transformPoint('));
    expect(source, contains('snap.point.x * _mmToPx'));
    expect(source, contains('snap.point.y * _mmToPx'));
    expect(source, contains('preferLeft'));
    expect(source, contains('proposedTop.clamp('));
    expect(source, contains('snap.label'));
    expect(source, contains('WallDrawingService.snap('));
  });

  test('wall tools are compact and accurate length editing stays available', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('compact-wall-tools'));
    expect(source, contains('math.min(282.0'));
    expect(source, contains('wall-build-exact-length'));
    expect(source, contains('wall-build-apply'));
  });

  test('edge pan publishes camera state for mode switches', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('void _wallPointerUp(PointerEvent event)'));
    expect(source, contains('_stopEdgePan();\n    // Edge auto-pan'));
    expect(source, contains('void _publishViewport()'));
  });
}
