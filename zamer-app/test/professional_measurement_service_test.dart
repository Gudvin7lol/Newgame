import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/professional_measurement_service.dart';

FloorPlan _floorWithOpening({double offsetMm = 700, double widthMm = 900}) {
  final floor = FloorPlan(id: 'f1', name: 'Этаж 1');
  floor.nodes.addAll([
    PlanNode(id: 'n1', xMm: 0, yMm: 0),
    PlanNode(id: 'n2', xMm: 4000, yMm: 0),
  ]);
  floor.walls.add(
    PlanWall(
      id: 'w1',
      startNodeId: 'n1',
      endNodeId: 'n2',
      openings: [
        WallOpening(
          id: 'o1',
          type: OpeningType.door,
          widthMm: widthMm,
          heightMm: 2100,
          offsetFromStartMm: offsetMm,
        ),
      ],
    ),
  );
  return floor;
}

DimensionRecord _record(
  double value,
  DimensionSource source, {
  String author = 'Замерщик',
}) =>
    DimensionRecord(
      valueMm: value,
      source: source,
      author: author,
      recordedAt: DateTime(2026, 10, 4),
    );

void main() {
  test('opening chain exposes distances from both wall corners', () {
    final floor = _floorWithOpening();
    final chain = ProfessionalMeasurementService.openingChains(floor).single;

    expect(chain.fromStartMm, 700);
    expect(chain.widthMm, 900);
    expect(chain.toEndMm, 2400);
    expect(chain.wallLengthMm, 4000);
    expect(chain.valid, isTrue);
  });

  test('audit distinguishes confirmed, calculated and missing dimensions', () {
    final floor = _floorWithOpening();
    floor.dimensionRecords['wall:w1:length'] =
        _record(4000, DimensionSource.rangefinder);
    floor.dimensionRecords['opening:o1:offset'] =
        _record(700, DimensionSource.rangefinder);
    floor.dimensionRecords['opening:o1:width'] =
        _record(900, DimensionSource.calculated, author: 'Замер');

    final summary = ProfessionalMeasurementService.audit(floor);

    expect(summary.expectedDimensions, 4);
    expect(summary.confirmedDimensions, 2);
    expect(summary.calculatedDimensions, 1);
    expect(summary.completion, .5);
    expect(
      summary.checks.any(
        (check) =>
            check.kind ==
            ProfessionalMeasureCheckKind.unconfirmedOpeningWidth,
      ),
      isTrue,
    );
    expect(
      summary.checks.any(
        (check) =>
            check.kind ==
            ProfessionalMeasureCheckKind.unconfirmedOpeningHeight,
      ),
      isTrue,
    );
    expect(
      summary.checks.any(
        (check) =>
            check.kind ==
            ProfessionalMeasureCheckKind.unconfirmedWallLength,
      ),
      isFalse,
    );
  });

  test('audit marks an opening outside its wall as critical', () {
    final floor = _floorWithOpening(offsetMm: 3500, widthMm: 900);
    final summary = ProfessionalMeasurementService.audit(floor);

    expect(summary.criticalCount, 1);
    final issue = summary.checks.firstWhere(
      (check) =>
          check.kind == ProfessionalMeasureCheckKind.openingOutsideWall,
    );
    expect(issue.wallId, 'w1');
    expect(issue.openingId, 'o1');
    expect(issue.critical, isTrue);
  });

  test('opposite reference returns the opposite logical wall length', () {
    final floor = FloorPlan(id: 'f2', name: 'Этаж 1');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 4000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ]);

    final opposite = ProfessionalMeasurementService.oppositeReferenceLength(
      floor,
      floor.walls.first,
    );

    expect(opposite, isNotNull);
    expect(opposite!, closeTo(4000, 1));
  });
}
