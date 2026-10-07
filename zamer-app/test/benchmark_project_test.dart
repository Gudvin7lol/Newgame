import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';
import 'package:zamer_app/services/benchmark_project_factory.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('3D benchmark contains two connected material zones', () {
    final project = BenchmarkProjectFactory.create();
    final floor = project.floors.single;
    final scene = ZamerSceneGeometry.fromFloor(floor);

    expect(project.id, BenchmarkProjectFactory.projectId);
    expect(scene.floors, hasLength(2));
    expect(scene.openings.any((o) => o.id == 'bedroom-door'), isTrue);

    final bedroom = scene.floors.firstWhere((s) => s.materialId == 'LAM_03');
    final hallway =
        scene.floors.firstWhere((s) => s.materialId == 'TILE_01');

    expect(bedroom.laminatePattern, 'herringbone');
    expect(bedroom.plankLengthMm, 600);
    expect(bedroom.plankWidthMm, 90);
    expect(hallway.tileWidthMm, 600);
    expect(hallway.tileHeightMm, 600);
  });

  test('benchmark carries the objects needed for the reference shot', () {
    final floor = BenchmarkProjectFactory.create().floors.single;
    final ids = floor.planObjects.map((o) => o.catalogId).toSet();

    expect(ids, contains('bed-sand'));
    expect(ids, contains('nightstand'));
    expect(ids, contains('rug-textile-2300'));
    expect(ids, contains('curtain-pair-1800'));
    expect(ids, contains('table-lamp-soft'));
    expect(ids, contains('ceiling-dome'));
    expect(ids, contains('tv-console-oak'));
  });

  test('simple benchmark decor uses procedural catalog assets', () {
    final proceduralIds = ObjectCatalog.items
        .where((item) => item.procedural)
        .map((item) => item.id)
        .toSet();

    expect(proceduralIds, contains('rug-textile-2300'));
    expect(proceduralIds, contains('curtain-pair-1800'));
    expect(proceduralIds, contains('table-lamp-soft'));
  });
}
