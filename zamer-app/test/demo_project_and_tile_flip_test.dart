import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/demo_project_factory.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('demo build contains the furnished concept apartment', () {
    final project = DemoProjectFactory.create();
    expect(project.id, DemoProjectFactory.projectId);
    expect(project.floors, hasLength(1));
    final floor = project.floors.single;
    expect(GeometryService.roomFaces(floor), hasLength(6));
    expect(floor.walls.length, greaterThanOrEqualTo(19));
    expect(floor.planObjects.any((o) => o.catalogId == 'bed-160'), isTrue);
    expect(floor.planObjects.any((o) => o.catalogId == 'sofa-3'), isTrue);
    expect(floor.planObjects.any((o) => o.catalogId == 'shower'), isTrue);
    expect(floor.roomMetas.any((m) => m.name == 'Гостиная'), isTrue);
    expect(floor.roomMetas.any((m) => m.name == 'С/У'), isTrue);
  });

  test('tile mirror and grout survive serialization and reach 3D', () {
    final project = DemoProjectFactory.create();
    final room = project.floors.single.roomMetas.firstWhere((m) => m.name == 'С/У');
    room.materials.wallTile = true;
    room.materials.wallTileGroutMm = 2.0;
    room.materials.wallTileRunEnabled['w16'] = true;
    room.materials.wallTileRunMirrored['w16'] = true;

    final restored = MeasureProject.fromJson(project.toJson());
    final floor = restored.floors.single;
    final materials = floor.roomMetas.firstWhere((m) => m.name == 'С/У').materials;
    expect(materials.wallTileGroutMm, 2.0);
    expect(materials.wallTileMirroredFor('w16'), isTrue);

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final tiled = scene.walls.where((w) => w.wallId == 'w16' && w.tileEnabled);
    expect(tiled, isNotEmpty);
    expect(tiled.any((w) => w.tileMirrored), isTrue);
  });
}
