import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/demo_project_factory.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('demo floor keeps the same laminate phase settings for 2D and 3D', () {
    final floor = DemoProjectFactory.create().floors.single;
    final scene = ZamerSceneGeometry.fromFloor(floor);
    final surface = scene.floors.single;

    expect(surface.laminatePattern, 'straight');
    expect(surface.laminateOffsetMode, 'half');
    expect(surface.laminateOffsetXMm, 180);
    expect(surface.laminateOffsetYMm, 70);
    expect(surface.plankLengthMm, 1380);
    expect(surface.plankWidthMm, 193);
  });

  test('tile finish is exported only on the selected side of the demo wall', () {
    final floor = DemoProjectFactory.create().floors.single;
    final scene = ZamerSceneGeometry.fromFloor(floor);
    final wallPieces = scene.walls.where((w) => w.wallId == 'wC').toList();

    expect(wallPieces, isNotEmpty);
    for (final wall in wallPieces) {
      expect(wall.finishes.where((f) => f.tileEnabled), hasLength(1));
    }
  });

  test('v1.5.5 library contains at least 79 installable objects', () {
    expect(ObjectCatalog.items.length, greaterThanOrEqualTo(79));
  });
}
