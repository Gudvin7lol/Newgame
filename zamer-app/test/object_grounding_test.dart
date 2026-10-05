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
      for (final invalidDimension in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -100,
      ]) {
        expect(
          zamerFallbackObjectDimensionM(dimensionMm: invalidDimension),
          closeTo(0.05, 0.000001),
        );
        expect(
          zamerFallbackObjectRenderedHeightM(heightMm: invalidDimension),
          closeTo(0.05, 0.000001),
        );
        expect(
          zamerFallbackObjectLocalCenterYM(heightMm: invalidDimension),
          closeTo(0.025, 0.000001),
        );
      }
      expect(
        zamerFallbackObjectDimensionM(dimensionMm: 1200),
        closeTo(1.2, 0.000001),
      );
      expect(
        zamerFallbackObjectCenterYM(
          heightMm: 600,
          elevationMm: double.nan,
        ),
        closeTo(0.3, 0.000001),
      );
    });

    test('invalid root elevation is sanitised before scene placement', () {
      for (final invalidElevation in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(zamerObjectElevationM(elevationMm: invalidElevation), 0.0);
        expect(
          zamerFallbackObjectCenterYM(
            heightMm: 600,
            elevationMm: invalidElevation,
          ),
          closeTo(0.3, 0.000001),
        );
      }
      expect(
        zamerObjectElevationM(elevationMm: 250),
        closeTo(0.25, 0.000001),
      );
    });
  });
}