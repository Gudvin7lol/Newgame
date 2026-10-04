import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: Measure remains the central editing workspace', () {
    final workspace =
        File('lib/screens/measure_unified_workspace_screen.dart').readAsStringSync();
    final floorLayer =
        File('lib/screens/measure_floor_plan_layer_screen.dart').readAsStringSync();
    final floorOverlay =
        File('lib/widgets/floor_finish_plan_overlay.dart').readAsStringSync();

    for (final required in const [
      "('План', Icons.architecture_outlined)",
      "('Пол', Icons.grid_4x4_outlined)",
      "('Объекты', Icons.chair_alt_outlined)",
      "('Электрика', Icons.electrical_services_outlined)",
      "('Инженерия', Icons.plumbing_outlined)",
      "('Материалы', Icons.inventory_2_outlined)",
      '_openCatalogSheet()',
      'embedded: true',
      'EquipmentPlacementService.addCatalogItem(',
      '_layer = 2',
    ]) {
      expect(
        workspace.contains(required),
        isTrue,
        reason: 'Missing Measure central-workspace contract: $required',
      );
    }

    expect(
      floorLayer.contains('FloorFinishPlanOverlayPainter('),
      isTrue,
      reason: 'Floor finishes must be visible on the measured CAD plan.',
    );
    expect(
      floorLayer.contains('onTapUp: (details) => _selectAt(details.localPosition)'),
      isTrue,
      reason: 'Rooms must remain selectable directly on the measured plan.',
    );

    for (final required in const [
      'GeometryService.roomFaces(floor)',
      "settings.floorMode == 'tile'",
      "settings.laminatePattern == 'herringbone'",
      'settings.floorDirectionDeg',
      'selectedFaceKey',
    ]) {
      expect(
        floorOverlay.contains(required),
        isTrue,
        reason: 'Missing live floor-plan finish contract: $required',
      );
    }
  });
}
