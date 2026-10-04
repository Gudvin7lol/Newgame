import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: objects electrical and engineering share one CAD canvas', () {
    final workspace =
        File('lib/screens/measure_unified_workspace_screen.dart').readAsStringSync();
    final canvas =
        File('lib/widgets/measure_shared_layer_canvas.dart').readAsStringSync();

    for (final required in const [
      'MeasureSharedLayerCanvas(',
      '_usesSharedCanvas',
      'MeasureSharedLayer.objects',
      'MeasureSharedLayer.electrical',
      'MeasureSharedLayer.engineering',
      '_openSharedLayerEditor(',
      'Offstage(',
    ]) {
      expect(
        workspace.contains(required),
        isTrue,
        reason: 'Missing shared Measure workspace contract: $required',
      );
    }

    for (final required in const [
      'TransformationController',
      'InteractiveViewer(',
      'CadPlanPainter(',
      'EquipmentPlacementService.moveBy(',
      'EquipmentPlacementService.rotateBy(',
      'EquipmentPlacementService.duplicateObject(',
      'GeometryService.nearestWallProjection(',
      "point.id.startsWith('fixture:')",
      'point.isWallDevice',
      'wallOffsetMm = offset',
      '_drawElectrical(',
      '_drawEngineering(',
      '_selectedRunVertex',
      'widget.onChanged()',
    ]) {
      expect(
        canvas.contains(required),
        isTrue,
        reason: 'Missing shared CAD layer contract: $required',
      );
    }

    expect(
      canvas.contains('point.wallId = null;\n      point.wallOffsetMm = null;'),
      isTrue,
      reason: 'Free electrical points must clear stale wall binding.',
    );
    expect(
      canvas.contains("связан со светильником, двигай в «Объектах»"),
      isTrue,
      reason: 'Fixture electrical points must not drift away from lighting objects.',
    );
  });
}
