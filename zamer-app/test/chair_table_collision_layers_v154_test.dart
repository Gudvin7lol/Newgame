import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/plan_object_paint_order.dart';
import 'package:zamer_app/services/space_check_service.dart';

PlanObject furniture(String id, String catalog, double x, double y,
    double w, double d, double h, {double angle = 0}) => PlanObject(
  id: id, catalogId: catalog, type: PlanObjectType.furniture,
  xMm: x, yMm: y, widthMm: w, depthMm: d,
  heightMm: h, rotationDeg: angle,
);

void main() {
  test('chair can tuck seat below table without colliding', () {
    final table = furniture('table', 'table-rect', 0, 0, 1400, 800, 750);
    final chair = furniture('chair', 'chair', 0, 500, 480, 520, 850,
        angle: 180);
    final floor = FloorPlan(id: 'f', name: 'Dining',
      planObjects: [table, chair]);
    expect(SpaceCheckService.inspect(floor)
        .where((issue) => issue.kind == SpaceIssueKind.objectObject), isEmpty);
    expect(SpaceCheckService.overlappingVolumePairs(table, chair), isEmpty);
  });

  test('chair collides when its raised backrest is pushed into table top', () {
    final table = furniture('table', 'table-rect', 0, 0, 1400, 800, 750);
    final chair = furniture('chair', 'chair', 0, 500, 480, 520, 850);
    final floor = FloorPlan(id: 'f', name: 'Dining',
      planObjects: [table, chair]);
    expect(SpaceCheckService.inspect(floor)
        .any((issue) => issue.kind == SpaceIssueKind.objectObject), isTrue);
    expect(SpaceCheckService.overlappingVolumePairs(table, chair), isNotEmpty);
  });

  test('tables composite over chairs independent of insertion order', () {
    final table = furniture('table', 'table-rect', 0, 0, 1400, 800, 750);
    final chair = furniture('chair', 'chair', 0, 500, 480, 520, 850);
    final rug = furniture('rug', 'rug-gray', 0, 0, 2000, 1400, 35);
    final plan = FloorPlan(id: 'f', name: 'Dining',
      planObjects: [table, rug, chair]);
    final original = plan.toJson().toString();
    final ordered = PlanObjectPaintOrder.ordered(plan.planObjects);
    expect(ordered.map((e) => e.id).toList(), ['rug', 'chair', 'table']);
    expect(plan.toJson().toString(), original);
  });
}
