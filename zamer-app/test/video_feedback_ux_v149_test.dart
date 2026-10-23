import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equipment draws red collision contours from actual footprints', () {
    final src = File('lib/screens/planning_objects_screen.dart')
        .readAsStringSync();
    expect(src, contains('void _drawCollisionContours(Canvas canvas)'));
    expect(src, contains('Path _objectFootprint(PlanObject object)'));
    expect(src, contains('PathOperation.intersect'));
    expect(src, contains('collisionIssues: spaceIssues'));
    expect(src, contains('const Color(0xFFFF435B)'));
  });

  test('equipment defaults to a cleaner canvas and contextual inspector', () {
    final src = File('lib/screens/planning_objects_screen.dart')
        .readAsStringSync();
    expect(src, contains('showDimensions: false'));
    expect(src, contains("ValueKey('floating-object-inspector')"));
    expect(src, contains('Follow the selected furniture'));
    expect(src, contains('width: math.min(155.0, size.width - 16)'));
  });

  test('opening help does not use the full-width editing bar', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains("ValueKey('compact-opening-hint')"));
    expect(src, contains(
        'widget.planTool != MeasurePlanTool.openings)'));
    expect(src, contains('Коснитесь стены, чтобы добавить проём'));
  });
}
