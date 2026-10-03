import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure routes advanced wall work to production geometry', () {
    final workspace =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();

    expect(workspace.contains("import 'plan_geometry_tools_screen.dart';"), isTrue);
    expect(workspace.contains('PlanGeometryToolsScreen('), isTrue);
    expect(measure.contains('onOpenAdvanced: widget.onOpenGeometry'), isTrue);
    expect(workspace.contains("title: 'Радиусы и узлы'"), isTrue);
    expect(workspace.contains("title: 'Расширенный редактор'"), isTrue);
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
