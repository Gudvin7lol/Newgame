import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equipment workspace and plan share the same production CAD painter', () {
    final equipment =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();
    final plan =
        File('lib/screens/plan_editor_master_v4_screen.dart').readAsStringSync();
    final shared = File('lib/widgets/cad_plan_painter.dart').readAsStringSync();
    final raster =
        File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();

    expect(equipment.contains("import '../widgets/cad_plan_painter.dart';"), isTrue);
    expect(plan.contains('painter: CadPlanPainter('), isTrue);
    expect(shared.contains('extends CadPlanPainterV3'), isTrue);
    expect(raster.contains('ImportedTopViewAssets.instance'), isTrue);

    final equipmentPainter = equipment
        .split('class _PlanningPainter extends CustomPainter {')
        .last
        .split('class _ObjTx {')
        .first;
    expect(equipmentPainter.contains('CadPlanPainter('), isTrue);
    expect(equipmentPainter.contains('mmToPx: scale'), isTrue);
    expect(equipmentPainter.contains('origin: origin'), isTrue);
    expect(equipmentPainter.contains('repaint: ImportedTopViewAssets.instance'),
        isTrue);

    // The equipment screen may overlay selection chrome, but it must not
    // independently invent schematic beds, sofas, toilets and kitchen units.
    expect(equipmentPainter.contains("id.startsWith('bed-')"), isFalse);
    expect(equipmentPainter.contains("id.startsWith('sofa-')"), isFalse);
    expect(equipmentPainter.contains("id == 'toilet'"), isFalse);
  });

  test('shared top view uses the stored object size and rotation', () {
    final renderer = File('lib/widgets/cad_plan_painter_v3.dart').readAsStringSync();
    final equipment =
        File('lib/screens/planning_objects_screen.dart').readAsStringSync();

    expect(renderer.contains('object.widthMm * mmToPx'), isTrue);
    expect(renderer.contains('object.depthMm * mmToPx'), isTrue);
    expect(renderer.contains('object.rotationDeg'), isTrue);

    expect(equipment.contains('selected.widthMm * scale'), isTrue);
    expect(equipment.contains('selected.depthMm * scale'), isTrue);
    expect(equipment.contains('selected.rotationDeg'), isTrue);
    expect(equipment.contains('onScaleUpdate: (d) => _objectScaleUpdate(d, size)'),
        isTrue);
    expect(equipment.contains('onScaleEnd: _objectScaleEnd'), isTrue);
    expect(equipment.contains('painter: _PlanningPainter('), isTrue);
  });
}
