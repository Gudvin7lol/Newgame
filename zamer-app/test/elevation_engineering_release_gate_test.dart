import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: elevations expose engineering as a project layer', () {
    final screen =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final overlay =
        File('lib/widgets/elevation_engineering_overlay.dart').readAsStringSync();

    for (final required in const [
      '_showEngineering',
      "label: 'Инженерия'",
      'copy.serviceRuns.clear()',
      'ElevationEngineeringOverlayPainter(',
      'widget.floor.serviceRuns.length',
    ]) {
      expect(
        screen.contains(required),
        isTrue,
        reason: 'Missing engineering elevation screen contract: $required',
      );
    }

    for (final required in const [
      'GeometryService.nearestWallProjection(',
      'ServiceRunType.coldWater',
      'ServiceRunType.hotWater',
      'ServiceRunType.drain',
      'ServiceRunType.heating',
      "ServiceRunType.coldWater => 'ХВС'",
      "ServiceRunType.hotWater => 'ГВС'",
    ]) {
      expect(
        overlay.contains(required),
        isTrue,
        reason: 'Missing engineering projection contract: $required',
      );
    }
  });

  test('release gate: elevation edits real room height and persists it', () {
    final source =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();

    for (final required in const [
      '_editRoomHeight(',
      "title: const Text('Высота помещения')",
      'meta.ceilingHeightMm = value',
      "final key = 'room:\${meta.id}:height'",
      'DimensionRecord(',
      'DimensionSource.manual',
      'old.revise(',
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
