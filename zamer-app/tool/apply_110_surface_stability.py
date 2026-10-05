from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'zamer-app'

viewport_path = APP / 'lib/renderer3d/zamer_gpu_viewport.dart'
pubspec_path = APP / 'pubspec.yaml'
policy_path = APP / 'lib/renderer3d/surface_stability_policy.dart'
test_path = APP / 'test/surface_stability_policy_test.dart'

viewport = viewport_path.read_text()

old_import = "import '../services/material_catalog.dart';\n"
new_import = "import '../services/material_catalog.dart';\nimport '../services/object_catalog.dart';\n"
assert old_import in viewport, 'material_catalog import anchor missing'
if "import '../services/object_catalog.dart';" not in viewport:
    viewport = viewport.replace(old_import, new_import, 1)

old_renderer_import = "import 'scene_mesh_winding.dart';\n"
new_renderer_import = "import 'scene_mesh_winding.dart';\nimport 'surface_stability_policy.dart';\n"
assert old_renderer_import in viewport, 'renderer import anchor missing'
if "import 'surface_stability_policy.dart';" not in viewport:
    viewport = viewport.replace(old_renderer_import, new_renderer_import, 1)

old_gap = "finish.sideSign * (wall.thicknessMm / 2000 + thin / 2 + 0.0005),"
new_gap = "finish.sideSign * (wall.thicknessMm / 2000 + thin / 2 + ZamerSurfaceStabilityPolicy.wallFinishGapM),"
assert old_gap in viewport or new_gap in viewport, 'wall finish gap anchor missing'
viewport = viewport.replace(old_gap, new_gap, 1)

old_root = """    root
      ..position = vm.Vector3(
        _mx(object.xMm, bounds),
        object.elevationMm / 1000,
        _mz(object.yMm, bounds),
      )
"""
new_root = """    final catalogItem = ObjectCatalog.byId(object.catalogId);
    final mount = catalogItem.id == object.catalogId
        ? catalogItem.mount
        : CatalogMount.floor;
    root
      ..position = vm.Vector3(
        _mx(object.xMm, bounds),
        ZamerSurfaceStabilityPolicy.objectBaseYM(
          mount: mount,
          elevationMm: object.elevationMm,
        ),
        _mz(object.yMm, bounds),
      )
"""
assert old_root in viewport or new_root in viewport, 'object root anchor missing'
viewport = viewport.replace(old_root, new_root, 1)
viewport_path.write_text(viewport)

policy_path.write_text("""import '../services/object_catalog.dart';
import 'floor_grout_geometry.dart';

/// Small, explicit separations that keep coplanar GPU surfaces from fighting.
///
/// Source geometry remains in real millimetres. These offsets exist only at
/// the renderer boundary, where mobile depth buffers need a little breathing
/// room between the wall core/finish and between the floor mesh and floor-
/// mounted GLBs.
class ZamerSurfaceStabilityPolicy {
  const ZamerSurfaceStabilityPolicy._();

  /// 0.5 mm was visibly unstable at shallow angles on several mobile GPUs.
  /// Two millimetres is still visually negligible but gives the depth buffer a
  /// reliable separation between the wall core and its decorative finish.
  static const double wallFinishGapM = 0.002;

  /// Keeps imported floor objects just above the zero-thickness finish mesh.
  /// The object model is already rebased to its lowest local bound, so this is
  /// a renderer-only anti-z-fighting offset, not a change to measured height.
  static const double floorObjectClearanceM = 0.0005;

  static double objectBaseYM({
    required CatalogMount mount,
    required double elevationMm,
  }) {
    final safeElevationM = elevationMm.isFinite && elevationMm > 0
        ? elevationMm / 1000
        : 0.0;
    if (mount != CatalogMount.floor) return safeElevationM;
    return zamerFloorSurfaceYM + floorObjectClearanceM + safeElevationM;
  }
}
""")

test_path.write_text("""import 'package:flutter_test/flutter_test.dart';
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
""")

pubspec = pubspec_path.read_text()
assert 'version: 1.5.6+109' in pubspec or 'version: 1.5.6+110' in pubspec, 'version anchor missing'
pubspec = pubspec.replace('version: 1.5.6+109', 'version: 1.5.6+110', 1)
pubspec_path.write_text(pubspec)

print('Applied Zamer 1.5.6+110 surface stability patch')
