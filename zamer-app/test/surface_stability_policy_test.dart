import 'package:flutter_test/flutter_test.dart';
import 'package:zamer/renderer3d/floor_grout_geometry.dart';
import 'package:zamer/renderer3d/surface_stability_policy.dart';
import 'package:zamer/services/object_catalog.dart';

void main() {
  test('floor objects sit above the rendered finish instead of sinking', () {
    final y = ZamerSurfaceStabilityPolicy.objectBaseYM(
      mount: CatalogMount.floor,
      elevationMm: 0,
    );

    expect(y, greaterThan(zamerFloorSurfaceYM));
    expect(
      y,
      closeTo(
        zamerFloorSurfaceYM +
            ZamerSurfaceStabilityPolicy.floorObjectClearanceM,
        1e-9,
      ),
    );
  });

  test('floor elevation remains relative to the finished floor', () {
    final y = ZamerSurfaceStabilityPolicy.objectBaseYM(
      mount: CatalogMount.floor,
      elevationMm: 120,
    );

    expect(
      y,
      closeTo(
        zamerFloorSurfaceYM +
            ZamerSurfaceStabilityPolicy.floorObjectClearanceM +
            0.120,
        1e-9,
      ),
    );
  });

  test('wall and ceiling mounts preserve explicit absolute elevation', () {
    expect(
      ZamerSurfaceStabilityPolicy.objectBaseYM(
        mount: CatalogMount.wall,
        elevationMm: 1650,
      ),
      closeTo(1.650, 1e-9),
    );
    expect(
      ZamerSurfaceStabilityPolicy.objectBaseYM(
        mount: CatalogMount.ceiling,
        elevationMm: 2520,
      ),
      closeTo(2.520, 1e-9),
    );
  });

  test('negative legacy elevation cannot bury floor furniture', () {
    final y = ZamerSurfaceStabilityPolicy.objectBaseYM(
      mount: CatalogMount.floor,
      elevationMm: -80,
    );
    expect(y, greaterThan(zamerFloorSurfaceYM));
  });

  test('wall finish gap is large enough to avoid coplanar depth fighting', () {
    expect(ZamerSurfaceStabilityPolicy.wallFinishGapM, greaterThanOrEqualTo(0.002));
  });
}
