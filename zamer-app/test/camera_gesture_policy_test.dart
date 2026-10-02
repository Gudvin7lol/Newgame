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
}
