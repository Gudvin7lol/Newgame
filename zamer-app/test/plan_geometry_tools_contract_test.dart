import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure embeds precise wall geometry without separate editor routes', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();

    expect(workspace.contains("import 'plan_geometry_tools_screen.dart';"), isFalse);
    expect(workspace.contains('PlanGeometryToolsScreen('), isFalse);
    expect(measure.contains('PlanGeometryToolsScreen('), isFalse);
    expect(measure.contains('PlanEditorProductionScreen('), isTrue);
    expect(measure.contains('planTool: _planTool'), isTrue);
    expect(measure.contains('MeasurePlanTool.precision'), isTrue);
    expect(measure.contains('embedded: true'), isTrue,
        reason: 'Objects placement stays embedded in Measure');
    expect(workspace.contains("title: 'Расширенный редактор'"), isFalse);
    expect(workspace.contains('_openAdvancedEditor'), isFalse);
  });

  test('geometry production tool keeps real radius and node operations', () {
    final source =
        File('lib/screens/plan_geometry_tools_screen.dart').readAsStringSync();

    expect(source.contains('GeometryService.addArcWallFromNode('), isTrue);
    expect(source.contains('GeometryService.snapMoveTarget('), isTrue);
    expect(source.contains('GeometryService.finalizeNodeMove('), isTrue);
    expect(source.contains("labelText: 'Хорда L'"), isTrue);
    expect(source.contains("labelText: 'Стрела h'"), isTrue);
    expect(source.contains("title: const Text('Геометрия плана')"), isTrue);
  });
}
