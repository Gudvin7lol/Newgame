import 'package:flutter_test/flutter_test.dart';
import 'package:zamer/renderer3d/object_grounding.dart';

void main() {
  group('fallback object grounding', () {
    test('floor object is lifted by half of its rendered height', () {
      expect(
        zamerFallbackObjectCenterYM(heightMm: 800, elevationMm: 0),
        closeTo(0.4, 0.000001),
      );
    });

    test('explicit elevation remains below the half-height lift', () {
      expect(
        zamerFallbackObjectCenterYM(heightMm: 600, elevationMm: 250),
        closeTo(0.55, 0.000001),
      );
    });

    test('matches fallback cuboid minimum height', () {
      expect(
        zamerFallbackObjectCenterYM(heightMm: 0, elevationMm: 0),
        closeTo(0.025, 0.000001),
      );
    });
  });
}
