import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/demo_project_factory.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('demo floor keeps the same laminate phase settings for 2D and 3D', () {
    final floor = DemoProjectFactory.create().floors.single;
    final scene = ZamerSceneGeometry.fromFloor(floor);
    final bedroom = floor.roomMetas.firstWhere((m) => m.name == 'Спальня');
    final surface = scene.floors.firstWhere((s) => s.roomKey == bedroom.faceKey);
    final settings = bedroom.materials;

    expect(surface.laminatePattern, settings.laminatePattern);
    expect(surface.laminateOffsetMode, settings.laminateOffsetMode);
    expect(surface.laminateOffsetXMm, settings.laminateOffsetXMm);
    expect(surface.laminateOffsetYMm, settings.laminateOffsetYMm);
    expect(surface.plankLengthMm, settings.laminatePlankLengthMm);
    expect(surface.plankWidthMm, settings.laminatePlankWidthMm);
  });

  test('tile finish is exported only on the bathroom side of a shared wall', () {
    final floor = DemoProjectFactory.create().floors.single;
    final scene = ZamerSceneGeometry.fromFloor(floor);
    final wallPieces = scene.walls.where((w) => w.wallId == 'w19').toList();

    expect(wallPieces, isNotEmpty);
    for (final wall in wallPieces) {
      expect(wall.finishes.where((f) => f.tileEnabled), hasLength(1));
    }
  });

  test('v1.5.5 library contains at least 79 installable objects', () {
    expect(ObjectCatalog.items.length, greaterThanOrEqualTo(79));
  });
}
