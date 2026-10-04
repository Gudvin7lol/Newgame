import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: elevations expose engineering as a project layer', () {
    final source =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();

    for (final required in const [
      '_showEngineering',
      "label: 'Инженерия'",
      'copy.serviceRuns.clear()',
      '_ElevationEngineeringOverlayPainter(',
      'widget.floor.serviceRuns.length',
      'GeometryService.nearestWallProjection(',
      'ServiceRunType.coldWater',
      'ServiceRunType.hotWater',
      'ServiceRunType.drain',
      'ServiceRunType.heating',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing engineering elevation contract: $required',
      );
    }
  });

  test('release gate: elevation edits real room height and persists it', () {
    final source =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();

    for (final required in const [
      '_editRoomHeight(',
      "title: const Text('Высота помещения')",
      'heightOverrideMm = value',
      'await widget.onChanged()',
      "suffixText: 'мм'",
      'value < 1800',
      'value > 6000',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing elevation height edit contract: $required',
      );
    }
  });
}
