import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: elevation exposes inline electrical editor', () {
    final elevation =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final editor =
        File('lib/widgets/elevation_electrical_editor.dart').readAsStringSync();

    expect(elevation.contains('ElevationElectricalEditor('), isTrue);
    expect(elevation.contains('run: sourceRun'), isTrue);
    expect(elevation.contains('onChanged: _changed'), isTrue);

    for (final required in const [
      'point.isWallDevice',
      'point.wallSide == insideSide',
      "labelText: 'От угла стены'",
      "labelText: 'Высота от чистого пола'",
      'point.wallOffsetMm = offset',
      'point.heightMm = height',
      'point.xMm =',
      'point.yMm =',
      'await onChanged()',
    ]) {
      expect(
        editor.contains(required),
        isTrue,
        reason: 'Missing inline electrical edit contract: $required',
      );
    }
  });
}
