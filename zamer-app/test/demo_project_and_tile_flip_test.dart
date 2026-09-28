import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/demo_project_factory.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('demo build contains one ready-to-test measured room', () {
    final project = DemoProjectFactory.create();
    expect(project.id, DemoProjectFactory.projectId);
    expect(project.floors, hasLength(1));
    final floor = project.floors.single;
    expect(GeometryService.roomFaces(floor), hasLength(1));
    expect(floor.walls, hasLength(4));
    expect(floor.planObjects.any((o) => o.catalogId == 'bed-160'), isTrue);
    expect(floor.planObjects.any((o) => o.catalogId == 'chandelier-ring'), isTrue);
  });

  test('tile mirror and grout survive serialization and reach 3D', () {
    final project = DemoProjectFactory.create();
    final room = project.floors.single.roomMetas.single;
    room.materials.wallTileGroutMm = 2.0;
    room.materials.wallTileRunMirrored['wC'] = true;

    final restored = MeasureProject.fromJson(project.toJson());
    final floor = restored.floors.single;
    final materials = floor.roomMetas.single.materials;
    expect(materials.wallTileGroutMm, 2.0);
    expect(materials.wallTileMirroredFor('wC'), isTrue);

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final tiled = scene.walls.where((w) => w.wallId == 'wC' && w.tileEnabled);
    expect(tiled, isNotEmpty);
    expect(tiled.every((w) => w.tileMirrored), isTrue);
  });
}
