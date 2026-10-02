import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/camera_gesture_policy.dart';

void main() {
  test('left swipe turns camera left and right swipe turns camera right', () {
    const yaw = 0.0;
    const sensitivity = 0.01;

    final afterLeft = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: yaw,
      deltaX: -30,
      sensitivity: sensitivity,
    );
    final afterRight = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: yaw,
      deltaX: 30,
      sensitivity: sensitivity,
    );

    expect(afterLeft, greaterThan(yaw));
    expect(afterRight, lessThan(yaw));
  });

  test('yaw stays normalized after large gestures', () {
    final yaw = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: 3.1,
      deltaX: -500,
      sensitivity: 0.02,
    );
    expect(yaw, inInclusiveRange(-3.141592653589793, 3.141592653589793));
  });

  test('pathological pointer spikes are capped without reversing direction', () {
    final yaw = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: 0,
      deltaX: -10000,
      sensitivity: 0.01,
    );

    expect(yaw, closeTo(2.4, 0.0001));
  });

  test('invalid gesture samples never poison camera yaw', () {
    final fromNanDelta = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: 0.75,
      deltaX: double.nan,
      sensitivity: 0.01,
    );
    final fromInfiniteSensitivity = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: -0.5,
      deltaX: 20,
      sensitivity: double.infinity,
    );
    final fromNanYaw = CameraGesturePolicy.applyHorizontalSwipe(
      yaw: double.nan,
      deltaX: 20,
      sensitivity: 0.01,
    );

    expect(fromNanDelta, closeTo(0.75, 0.0001));
    expect(fromInfiniteSensitivity, closeTo(-0.5, 0.0001));
    expect(fromNanYaw, isFinite);
  });
}
