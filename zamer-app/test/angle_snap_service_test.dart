import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/angle_snap_service.dart';

void main() {
  test(
    'quarter-turn snap keeps free angles outside the magnetic threshold',
    () {
      expect(AngleSnapService.snapQuarterTurn(34), 34);
      expect(AngleSnapService.snapQuarterTurn(54), 54);
      expect(AngleSnapService.snapQuarterTurn(137), 137);
    },
  );

  test('quarter-turn snap catches nearby 0/90/180/270 angles', () {
    expect(AngleSnapService.snapQuarterTurn(6), 0);
    expect(AngleSnapService.snapQuarterTurn(83), 90);
    expect(AngleSnapService.snapQuarterTurn(187), 180);
    expect(AngleSnapService.snapQuarterTurn(263), 270);
    expect(AngleSnapService.snapQuarterTurn(-87), -90);
    expect(AngleSnapService.snapQuarterTurn(354), 360);
  });

  test('custom snap threshold is respected', () {
    expect(AngleSnapService.snapQuarterTurn(84, thresholdDeg: 5), 84);
    expect(AngleSnapService.snapQuarterTurn(86, thresholdDeg: 5), 90);
  });

  test('hysteresis keeps a quarter-turn lock until the release threshold', () {
    final engaged = AngleSnapService.snapQuarterTurnWithLock(84);
    expect(engaged.angleDeg, 90);
    expect(engaged.lockedAngleDeg, 90);

    final held = AngleSnapService.snapQuarterTurnWithLock(
      78,
      lockedAngleDeg: engaged.lockedAngleDeg,
    );
    expect(held.angleDeg, 90);
    expect(held.lockedAngleDeg, 90);

    final released = AngleSnapService.snapQuarterTurnWithLock(
      77,
      lockedAngleDeg: held.lockedAngleDeg,
    );
    expect(released.angleDeg, 77);
    expect(released.lockedAngleDeg, isNull);
  });

  test('snap lock handles equivalent angles across the 0/360 boundary', () {
    final held = AngleSnapService.snapQuarterTurnWithLock(
      -2,
      lockedAngleDeg: 360,
    );
    expect(held.angleDeg, 360);
    expect(held.lockedAngleDeg, 360);
  });
}
