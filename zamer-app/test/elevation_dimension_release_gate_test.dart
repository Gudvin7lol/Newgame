import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: live elevations dimension devices and engineering', () {
    final overlay =
        File('lib/widgets/elevation_dimension_overlay.dart').readAsStringSync();
    final screen =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final engineering =
        File('lib/widgets/elevation_engineering_overlay.dart').readAsStringSync();

    for (final required in const [
      'ElevationDimensionOverlayPainter',
      '_collectElectrical(',
      '_collectObjects(',
      '_collectEngineering(',
      'EquipmentPlacementService.wallMountForObject(',
      'GeometryService.wallFaceStartShiftMm(',
      'point.heightMm',
      "label: _engineeringLabel(service.type)",
      "label: 'РАД'",
    ]) {
      expect(
        overlay.contains(required),
        isTrue,
        reason: 'Missing live elevation dimension contract: $required',
      );
    }

    expect(
      screen.contains("import '../widgets/elevation_dimension_overlay.dart';"),
      isTrue,
    );
    expect(
      screen.contains('painter: ElevationDimensionOverlayPainter('),
      isTrue,
    );
    expect(
      engineering.contains('projected.offsetMm.round()'),
      isTrue,
      reason: 'Engineering labels must expose measured wall offset.',
    );
  });
}
