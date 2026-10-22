import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('floor entry takes a real point and stores phase for both materials', () {
    final src = File('lib/screens/measure_floor_plan_layer_screen.dart')
        .readAsStringSync();
    expect(src, contains('_placingLayoutStart'));
    expect(src, contains('Future<void> _selectAt(Offset canvasPoint)'));
    expect(src, contains('settings.laminateOffsetXMm ='));
    expect(src, contains('settings.laminateOffsetYMm ='));
    expect(src, contains('settings.tileOffsetXMm ='));
    expect(src, contains('settings.tileOffsetYMm ='));
    expect(src, contains('layoutStartMm: _layoutStartMm'));
    expect(src, contains("tooltip: _placingLayoutStart"));
    expect(src, contains('showDimensions: false'));
  });

  test('floor highlight uses saved installation marker, not room centre', () {
    final src = File('lib/widgets/floor_finish_plan_overlay.dart')
        .readAsStringSync();
    expect(src, contains('final math.Point<double>? layoutStartMm'));
    expect(src, contains('_toCanvas(startMm)'));
    expect(src, contains('canvas.drawCircle(marker'));
  });
}
