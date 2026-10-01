import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Walk Mode uses measured frame delta and smoothed look', () {
    final source = File('lib/screens/floor_3d_screen.dart').readAsStringSync();

    expect(source, contains('double _walkSpeedMmPerSecond = 2500;'));
    expect(source, contains('Duration(milliseconds: 16)'));
    expect(source, contains('final Stopwatch _frameClock = Stopwatch();'));
    expect(source, contains('int? _lastFrameMicros;'));
    expect(source, contains('final nowMicros = _frameClock.elapsedMicroseconds;'));
    expect(source, contains('nowMicros - previousMicros'));
    expect(source, contains('elapsedMicros / Duration.microsecondsPerSecond'));
    expect(source, contains('.clamp(1 / 240, 0.05)'));
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
    expect(source, isNot(contains('_frameSeconds = 0.016')));
  });
}
