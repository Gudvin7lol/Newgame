import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Walk Mode uses frame-rate aware movement and smoothed look', () {
    final source = File('lib/screens/floor_3d_screen.dart').readAsStringSync();

    expect(source, contains('double _walkSpeedMmPerSecond = 2500;'));
    expect(source, contains('Duration(milliseconds: 16)'));
    expect(source, contains('static const double _frameSeconds = 0.016;'));
    expect(
      source,
      contains('forward * _walkSpeedMmPerSecond * deltaSeconds'),
    );
    expect(
      source,
      contains('sideways * _walkSpeedMmPerSecond * deltaSeconds'),
    );
    expect(source, contains("toStringAsFixed(1)} м/с"));

    expect(
      source,
      contains('_walkLookDelta.dx * .55 + rawLook.dx * .45'),
    );
    expect(
      source,
      contains('_walkLookDelta.dy * .55 + rawLook.dy * .45'),
    );
    expect(source, contains('final angle = _rotation + lookDelta.dx'));
    expect(source, contains('_tilt - lookDelta.dy'));

    final resetCount = '_walkLookDelta = Offset.zero'.allMatches(source).length;
    expect(resetCount, greaterThanOrEqualTo(3));

    expect(source, isNot(contains('_walkStepMm')));
    expect(source, isNot(contains('Duration(milliseconds: 48)')));
  });
}
