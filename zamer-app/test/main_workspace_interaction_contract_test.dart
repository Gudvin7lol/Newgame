import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project cards enter the workspace without the legacy floors gateway', () {
    final source = File('lib/screens/projects_screen.dart').readAsStringSync();
    expect(source, contains('FloorWorkspaceScreen('));
    expect(source, isNot(contains('FloorsScreen(project: project')));
  });

  test('master measure canvas keeps direct object and layout manipulation', () {
    final source = File(
      'lib/screens/plan_editor_master_v4_screen.dart',
    ).readAsStringSync();
    expect(source, contains('PlanDirectInteraction.moveObjectByMm'));
    expect(source, contains('PlanDirectInteraction.shiftFloorLayout'));
    expect(source, contains('_objectDragRegions()'));
    expect(source, contains('_layoutDragRegion()'));
  });
}
