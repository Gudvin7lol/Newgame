import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate: openings are editable from the active elevation', () {
    final elevations =
        File('lib/screens/layered_elevations_screen.dart').readAsStringSync();
    final editor =
        File('lib/widgets/elevation_opening_editor.dart').readAsStringSync();

    expect(elevations.contains('ElevationOpeningEditor('), isTrue);
    expect(elevations.contains('face: sourceFace'), isTrue);
    expect(elevations.contains('run: sourceRun'), isTrue);

    for (final required in const [
      'GeometryService.openingOffsetFromFaceStart(',
      'GeometryService.wallFaceStartShiftMm(',
      'opening.offsetFromStartMm',
      'opening.widthMm',
      'opening.heightMm',
      'opening.sillHeightMm',
      'От начала развёртки',
      "DimensionSource.manual",
      "'opening:\${entry.opening.id}:offset'",
      "'opening:\${entry.opening.id}:width'",
      "'opening:\${entry.opening.id}:height'",
      "'opening:\${entry.opening.id}:sill'",
      '_removeDimensionRecords(',
    ]) {
      expect(
        editor.contains(required),
        isTrue,
        reason: 'Missing direct elevation opening contract: $required',
      );
    }
  });
}
