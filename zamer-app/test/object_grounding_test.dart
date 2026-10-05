import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/object_grounding.dart';

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
      expect(
        zamerFallbackObjectRenderedHeightM(heightMm: 0),
        closeTo(0.05, 0.000001),
      );
    });

    test('local centre keeps root elevation separate', () {
      expect(
        zamerFallbackObjectLocalCenterYM(heightMm: 600),
        closeTo(0.3, 0.000001),
      );
    });

    test('invalid persisted dimensions cannot poison GPU transforms', () {
      for (final invalidHeight in <double>[double.nan, double.infinity, -100]) {
        expect(
          zamerFallbackObjectRenderedHeightM(heightMm: invalidHeight),
          closeTo(0.05, 0.000001),
        );
        expect(
          zamerFallbackObjectLocalCenterYM(heightMm: invalidHeight),
          closeTo(0.025, 0.000001),
        );
      }
      expect(
        zamerFallbackObjectCenterYM(
          heightMm: 600,
          elevationMm: double.nan,
        ),
        closeTo(0.3, 0.000001),
      );
    });
  });
}
