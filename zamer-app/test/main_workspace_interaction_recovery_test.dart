import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovered Measure keeps direct object and floor-layout drag', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(source, contains('PlanDirectInteraction.moveObjectByMm'));
    expect(source, contains('PlanDirectInteraction.shiftFloorLayout'));
    expect(source, contains('_objectDragRegions()'));
    expect(source, contains('_layoutDragRegion()'));
  });
}
