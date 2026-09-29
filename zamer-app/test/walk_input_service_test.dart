import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/walk_input_service.dart';

void main() {
  test('stick dead zone suppresses accidental drift', () {
    final input = WalkInputService.fromStick(0.03, -0.04);
    expect(input.forward, 0);
    expect(input.sideways, 0);
  });

  test('stick maps screen directions to walk axes', () {
    final forward = WalkInputService.fromStick(0, -1);
    expect(forward.forward, closeTo(1, 0.0001));
    expect(forward.sideways, closeTo(0, 0.0001));

    final right = WalkInputService.fromStick(1, 0);
    expect(right.forward, closeTo(0, 0.0001));
    expect(right.sideways, closeTo(1, 0.0001));
  });

  test('stick response stays linear instead of squaring its magnitude', () {
    final input = WalkInputService.fromStick(0, -0.54);
    final expected =
        (0.54 - WalkInputService.deadZone) / (1 - WalkInputService.deadZone);
    expect(input.forward, closeTo(expected, 0.0001));
    expect(input.forward, greaterThan(0.45));
  });
}
