import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/measurement_review_service.dart';

void main() {
  test('review locates open contour and reports exact wall discrepancy', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(
        id: 'ab',
        startNodeId: 'a',
        endNodeId: 'b',
        type: WallType.exterior,
      ),
      PlanWall(
        id: 'bc',
        startNodeId: 'b',
        endNodeId: 'c',
        type: WallType.exterior,
      ),
    ]);
    floor.dimensionRecords['wall:ab:length'] = DimensionRecord(
      valueMm: 2980,
      source: DimensionSource.rangefinder,
      author: 'Дима',
      recordedAt: DateTime.utc(2026, 9, 27),
    );
    final before = floor.toJson().toString();
    final issues = MeasurementReviewService.review(floor);
    expect(
      issues.where((e) => e.kind == MeasurementIssueKind.openContour).length,
      2,
    );
    final mismatch = issues.singleWhere((e) => e.deltaMm != null);
    expect(mismatch.deltaMm, 20);
    expect(mismatch.position.x, 1500);
    expect(floor.toJson().toString(), before);
  });

  test(
    'provenance history survives JSON and review flags unconfirmed openings',
    () {
      final floor = FloorPlan(id: 'f', name: 'F');
      floor.nodes.addAll([
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 3000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ]);
      floor.walls.addAll([
        PlanWall(
          id: 'ab',
          startNodeId: 'a',
          endNodeId: 'b',
          openings: [
            WallOpening(
              id: 'door',
              type: OpeningType.door,
              widthMm: 900,
              heightMm: 2100,
              offsetFromStartMm: 1000,
            ),
          ],
        ),
        PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
      ]);
      GeometryService.syncRoomMetadata(floor);
      final record = DimensionRecord(
        valueMm: 2990,
        source: DimensionSource.bti,
        author: 'Автор',
        recordedAt: DateTime.utc(2026, 9, 20),
      );
      record.revise(3000, DimensionSource.manual, 'Дима');
      floor.dimensionRecords['wall:ab:length'] = record;
      final copy = FloorPlan.fromJson(floor.toJson());
      expect(
        copy.dimensionRecords['wall:ab:length']!.history.single.source,
        DimensionSource.bti,
      );
      final issues = MeasurementReviewService.review(copy);
      expect(
        issues.any((e) => e.kind == MeasurementIssueKind.missingOffset),
        isTrue,
      );
      expect(
        issues.any((e) => e.kind == MeasurementIssueKind.missingDiagonal),
        isTrue,
      );
      expect(
        issues.any((e) => e.kind == MeasurementIssueKind.missingHeight),
        isTrue,
      );
    },
  );

  test('free partition is not an unclosed outer boundary', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ]);
    final start = GeometryService.ensureAnchor(
      floor,
      const math.Point(1500, 0),
    );
    GeometryService.addWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: const math.Point(1500, 1000),
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
    );
    expect(
      MeasurementReviewService.review(
        floor,
      ).where((e) => e.kind == MeasurementIssueKind.openContour),
      isEmpty,
    );
  });

  test('split wall sections are compared with an overall measured length', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'm', xMm: 1970, yMm: 0),
      PlanNode(id: 'b', xMm: 4800, yMm: 0),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'am', startNodeId: 'a', endNodeId: 'm'),
      PlanWall(id: 'mb', startNodeId: 'm', endNodeId: 'b'),
    ]);
    floor.measures.add(
      ControlMeasure(
        id: 'overall',
        startNodeId: 'a',
        endNodeId: 'b',
        measuredMm: 4775,
      ),
    );
    final issue = MeasurementReviewService.review(
      floor,
    ).singleWhere((e) => e.deltaMm != null);
    expect(issue.description, contains('Сумма участков'));
    expect(issue.deltaMm, 25);
  });

  test('review flags an acute wall angle below 65 degrees', () {
    final floor = FloorPlan(id: 'acute', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'o', xMm: 0, yMm: 0),
      PlanNode(id: 'a', xMm: 3000, yMm: 0),
      PlanNode(id: 'b', xMm: 2000, yMm: 2000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'oa', startNodeId: 'o', endNodeId: 'a'),
      PlanWall(id: 'ob', startNodeId: 'o', endNodeId: 'b'),
    ]);

    final issues = MeasurementReviewService.review(floor);
    final acute = issues.where(
      (issue) => issue.kind == MeasurementIssueKind.acuteAngle,
    );
    expect(acute, hasLength(1));
    expect(acute.single.description, contains('45.0°'));
  });

  test('review flags walls crossing without a shared node', () {
    final floor = FloorPlan(id: 'crossing', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 3000),
      PlanNode(id: 'c', xMm: 0, yMm: 3000),
      PlanNode(id: 'd', xMm: 3000, yMm: 0),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
    ]);

    final crossing = MeasurementReviewService.review(floor).where(
      (issue) => issue.kind == MeasurementIssueKind.intersection,
    );
    expect(crossing, hasLength(1));
    expect(crossing.single.position.x, 1500);
    expect(crossing.single.position.y, 1500);
  });
}
