import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';

void main() {
  test('versions keep floor snapshots and do not recursively copy history', () {
    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    final project = MeasureProject(id: 'p', name: 'Квартира', floors: [floor]);
    project.revisions.add(
      ProjectRevision(
        label: 'До ремонта',
        createdAt: DateTime.utc(2026, 9, 27),
        floors: [FloorPlan.fromJson(floor.toJson())],
      ),
    );
    floor.name = 'Этаж после ремонта';
    final restored = MeasureProject.fromJson(project.toJson());
    expect(restored.revisions.single.floors.single.name, 'Этаж 1');
    expect(restored.floors.single.name, 'Этаж после ремонта');
    expect(
      restored.revisions.single.toJson().containsKey('revisions'),
      isFalse,
    );
  });
}
