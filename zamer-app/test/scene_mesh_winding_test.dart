import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/scene_mesh_winding.dart';

void main() {
  test('plan CCW triangles are reversed for an upward GPU floor face', () {
    const plan = <({double x, double y})>[
      (x: 0.0, y: 0.0),
      (x: 4.0, y: 0.0),
      (x: 4.0, y: 3.0),
    ];
    final indices = floorFacingTriangleIndices(const <int>[0, 1, 2]);
    expect(indices, const <int>[2, 1, 0]);

    final a = plan[indices[0]];
    final b = plan[indices[1]];
    final c = plan[indices[2]];
    // GPU mapping is (plan.x, 0, plan.y). For two XZ edges u and v,
    // cross(u, v).y = u.z * v.x - u.x * v.z.
    final ux = b.x - a.x;
    final uz = b.y - a.y;
    final vx = c.x - a.x;
    final vz = c.y - a.y;
    final normalY = uz * vx - ux * vz;
    expect(normalY, greaterThan(0));
  });

  test('winding helper preserves triangle groups and rejects broken lists', () {
    expect(
      floorFacingTriangleIndices(const <int>[0, 1, 2, 0, 2, 3]),
      const <int>[2, 1, 0, 3, 2, 0],
    );
    expect(
      () => floorFacingTriangleIndices(const <int>[0, 1]),
      throwsArgumentError,
    );
  });
}
