import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/measurement_review_service.dart';
import 'package:zamer_app/services/plan_visibility_service.dart';
import 'package:zamer_app/services/room_interior_dimensions_service.dart';
import 'package:zamer_app/widgets/cad_plan_painter_v2.dart';

FloorPlan rectangle({
  double top = 200,
  double right = 200,
  double bottom = 200,
  double left = 200,
  bool splitTop = false,
}) {
  final f = FloorPlan(id: 'f', name: 'Комната');
  f.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
    if (splitTop) PlanNode(id: 'middle', xMm: 2000, yMm: 0),
  ]);
  f.walls.addAll([
    if (splitTop) ...[
      PlanWall(id: 'top1', startNodeId: 'a', endNodeId: 'middle',
        thicknessMm: top),
      PlanWall(id: 'top2', startNodeId: 'middle', endNodeId: 'b',
        thicknessMm: top),
    ] else
      PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b',
        thicknessMm: top),
    PlanWall(id: 'right', startNodeId: 'b', endNodeId: 'c',
      thicknessMm: right),
    PlanWall(id: 'bottom', startNodeId: 'c', endNodeId: 'd',
      thicknessMm: bottom),
    PlanWall(id: 'left', startNodeId: 'd', endNodeId: 'a',
      thicknessMm: left),
  ]);
  return f;
}

void main() {
  test('inner dimensions measure exactly 3800 x 2800, not axes 4000 x 3000', () {
    final floor = rectangle();
    final faces = GeometryService.roomFaces(floor);
    expect(faces.length, 1);
    final lengths = RoomInteriorDimensionsService.forFloor(floor)
        .map((x) => x.lengthMm.round())
        .toList()..sort();
    expect(lengths, [2800, 2800, 3800, 3800]);
    expect(faces.single.areaM2, closeTo(10.64, .0000001));

    final first = RoomInteriorDimensionsService.forFace(faces.single).first;
    expect(first.start.x, closeTo(100, .0001));
    expect(first.start.y, closeTo(100, .0001));
    expect(first.end.x, closeTo(3900, .0001));
    expect(first.end.y, closeTo(100, .0001));
  });

  test('unequal wall widths shift inside corners by each half thickness', () {
    final floor = rectangle(top: 200, right: 300,
      bottom: 100, left: 200);
    final sides = RoomInteriorDimensionsService.forFloor(floor)
        .map((x) => x.lengthMm.round()).toList()..sort();
    expect(sides, [2850, 2850, 3750, 3750]);
    final pts = GeometryService.roomFaces(floor).single.innerPolygon;
    expect(pts.first.x, closeTo(100, .00001));
    expect(pts.first.y, closeTo(100, .00001));
    expect(pts[1].x, closeTo(3850, .00001));
    expect(pts[2].y, closeTo(2950, .00001));
  });

  test('interior side crossing a T wall ID split is one corner-to-corner dimension', () {
    final floor = rectangle(splitTop: true);
    floor.nodes.add(PlanNode(id: 'branchEnd', xMm: 2000, yMm: -900));
    floor.walls.add(PlanWall(
      id: 'branch', startNodeId: 'middle', endNodeId: 'branchEnd',
      thicknessMm: 100,
    ));
    final faces = GeometryService.roomFaces(floor);
    expect(faces.length, 1);
    expect(faces.single.edges.length, greaterThan(4));
    final sides = RoomInteriorDimensionsService.forFloor(floor)
        .map((x) => x.lengthMm.round()).toList()..sort();
    expect(sides, [2800, 2800, 3800, 3800]);
  });

  test('L-shaped internal room keeps six true corners and multiple lengths', () {
    final floor = FloorPlan(id: 'l', name: 'Г-образная');
    final positions = <math.Point<double>>[
      const math.Point<double>(0, 0),
      const math.Point<double>(4000, 0),
      const math.Point<double>(4000, 1000),
      const math.Point<double>(3000, 1000),
      const math.Point<double>(3000, 3000),
      const math.Point<double>(0, 3000),
    ];
    for (var i = 0; i < positions.length; i++) {
      floor.nodes.add(PlanNode(id: 'n$i',
        xMm: positions[i].x, yMm: positions[i].y));
    }
    for (var i = 0; i < positions.length; i++) {
      floor.walls.add(PlanWall(
        id: 'w$i', startNodeId: 'n$i',
        endNodeId: 'n${(i + 1) % positions.length}', thicknessMm: 200,
      ));
    }
    final dimensions = RoomInteriorDimensionsService.forFloor(floor);
    expect(dimensions.length, 6);
    expect(dimensions.every((d) =>
        d.lengthMm > 100 && d.lengthMm < 4000), isTrue);
  });

  test('stored inside-corner control measures survive JSON round-trip', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final corners = face.innerPolygon;
    final m = ControlMeasure(
      id: 'inside', startNodeId: face.nodeIds[0],
      endNodeId: face.nodeIds[1], measuredMm: 3800,
      label: 'Внутренний размер',
      startXMm: corners[0].x, startYMm: corners[0].y,
      endXMm: corners[1].x, endYMm: corners[1].y,
    );
    floor.measures.add(m);
    final restored = FloorPlan.fromJson(floor.toJson());
    final measure = restored.measures.single;
    expect(measure.isInterior, isTrue);
    expect(measure.measuredMm, 3800);
    expect(measure.interiorStart, const math.Point<double>(100, 100));
    expect(measure.interiorEnd, const math.Point<double>(3900, 100));
    final legacy = ControlMeasure(
      id: 'axis', startNodeId: 'a', endNodeId: 'b', measuredMm: 4000);
    expect(ControlMeasure.fromJson(legacy.toJson()).isInterior, isFalse);
  });

  test('survey review does not compare an inner dimension with centreline nodes', () {
    final floor = rectangle();
    final face = GeometryService.roomFaces(floor).single;
    final pts = face.innerPolygon;
    final m = ControlMeasure(
      id: 'inside', startNodeId: face.nodeIds[0],
      endNodeId: face.nodeIds[1], measuredMm: 3800,
      startXMm: pts[0].x, startYMm: pts[0].y,
      endXMm: pts[1].x, endYMm: pts[1].y,
    );
    floor.measures.add(m);
    final good = MeasurementReviewService.review(floor);
    expect(good.where((x) =>
      x.kind == MeasurementIssueKind.discrepancy &&
      x.description.contains('inside')), isEmpty);

    floor.wallById('right')!.thicknessMm = 300;
    final changed = MeasurementReviewService.review(floor);
    expect(changed.any((x) =>
      x.kind == MeasurementIssueKind.discrepancy &&
      x.description.contains('Внутренний размер') &&
      x.deltaMm != null && x.deltaMm!.abs() >= 50), isTrue);
  });

  test('production CAD renders interior dimensions with construction axes off by default', () {
    final floor = rectangle();
    final painter = CadPlanPainterV2(
      floor: floor, origin: Offset.zero, mmToPx: .1,
    );
    expect(painter.visibleCategories.contains(
      PlanDisplayLayer.dimensions), isTrue);
    expect(painter.visibleCategories.contains(
      PlanDisplayLayer.axisDimensions), isFalse);
    expect(PlanDisplayLayer.axisDimensions.label,
      contains('осям'));
    expect(PlanDisplayLayer.dimensions.label,
      contains('внутри'));
    final before = floor.toJson().toString();
    final layers = PlanDisplayLayer.values.toSet()
      ..remove(PlanDisplayLayer.dimensions)
      ..add(PlanDisplayLayer.axisDimensions);
    expect(layers.contains(PlanDisplayLayer.dimensions), isFalse);
    expect(floor.toJson().toString(), before);
  });
}
