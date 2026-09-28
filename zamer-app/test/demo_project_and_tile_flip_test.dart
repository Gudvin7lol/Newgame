import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/demo_project_factory.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('BUILD47 demo contains two ready-to-test rooms', () {
    final project = DemoProjectFactory.create();
    expect(project.id, DemoProjectFactory.projectId);
    expect(project.floors, hasLength(1));

    final floor = project.floors.single;
    final faces = GeometryService.roomFaces(floor);
    expect(faces, hasLength(2));
    expect(floor.roomMetas.any((m) => m.name == 'Гостиная'), isTrue);
    expect(floor.roomMetas.any((m) => m.name == 'Спальня'), isTrue);
    expect(
      floor.electricalPoints.any(
        (p) => p.type == ElectricalPointType.wallLight,
      ),
      isTrue,
    );
    expect(
      floor.walls.any(
        (w) => w.openings.any((o) => o.id == 'door-between'),
      ),
      isTrue,
    );
  });

  test('tile quarter-turn survives serialization', () {
    final project = DemoProjectFactory.create();
    final room = project.floors.single.roomMetas.firstWhere(
      (m) => m.name == 'Гостиная',
    );

    room.materials.wallTileGroutMm = 2.0;
    room.materials.wallTileRunQuarterTurns['test-wall'] = 1;

    final restored = MeasureProject.fromJson(project.toJson());
    final restoredRoom = restored.floors.single.roomMetas.firstWhere(
      (m) => m.name == 'Гостиная',
    );
    final materials = restoredRoom.materials;

    expect(materials.wallTileGroutMm, 2.0);
    expect(materials.wallTileQuarterTurnsFor('test-wall'), 1);
  });
}
