import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_mounting.dart';
import 'package:zamer_app/services/electrical_mounting_service.dart';

FloorPlan mountingFixture() => FloorPlan(
  id: 'f',
  name: 'Этаж',
  nodes: [
    PlanNode(id: 'a', xMm: 100, yMm: 200),
    PlanNode(id: 'b', xMm: 3300, yMm: 200),
  ],
  walls: [PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b')],
  electricalPoints: [
    ElectricalPoint(
      id: 'p',
      type: ElectricalPointType.socket,
      xMm: 700,
      yMm: 200,
      wallId: 'w',
      wallOffsetMm: 600,
    ),
  ],
);
ElectricalMounting dimension(
  FloorPlan f, {
  String node = 'a',
  double inset = 0,
  double distance = 600,
  double height = 300,
  double? slab = 80,
}) => ElectricalMounting(
  wallId: 'w',
  datumNodeId: node,
  datumName: 'База $node',
  datumInsetMm: inset,
  distanceMm: distance,
  heightAboveFinishedFloorMm: height,
  wallSide: 1,
  geometrySnapshot: ElectricalMountingService.snapshot(f, f.walls.single),
  finishedFloorAboveSlabMm: slab,
  source: MountingSource.designed,
);
void main() {
  test('legacy projects have no invented mounting or slab level', () {
    final f = mountingFixture();
    final json = f.toJson();
    (json['electricalPoints'] as List).first.remove('mounting');
    final restored = FloorPlan.fromJson(json);
    expect(restored.electricalPoints.single.mounting, isNull);
    expect(
      ElectricalMountingService.problem(
        restored,
        restored.electricalPoints.single,
      ),
      isNotNull,
    );
  });
  test('600 from A and 2600 from B describe exactly the same centre', () {
    final f = mountingFixture();
    final a = ElectricalMountingService.resolve(f, dimension(f));
    final b = ElectricalMountingService.resolve(
      f,
      dimension(f, node: 'b', distance: 2600),
    );
    expect(a.xMm, 700);
    expect(a.yMm, 200);
    expect(b.xMm, a.xMm);
    expect(b.offsetMm, a.offsetMm);
  });
  test('survey datum inset is added once and displayed separately', () {
    final f = mountingFixture();
    final pos = ElectricalMountingService.resolve(
      f,
      dimension(f, inset: 120, distance: 600),
    );
    expect(pos.offsetMm, 720);
    expect(pos.datumXMm, 220);
    expect(pos.xMm, 820);
    final reverse = ElectricalMountingService.resolve(
      f,
      dimension(f, node: 'b', inset: 120, distance: 600),
    );
    expect(reverse.offsetMm, 2480);
    expect(reverse.datumXMm, 3180);
  });
  test('diagonal walls use world mm without pixel rounding', () {
    final f = mountingFixture();
    f.nodes[1].xMm = 3100;
    f.nodes[1].yMm = 4200;
    final p = ElectricalMountingService.resolve(
      f,
      dimension(f, distance: 1000.25),
    );
    expect(p.xMm, closeTo(700.15, .000001));
    expect(p.yMm, closeTo(1000.2, .000001));
  });
  test('300 above finished floor plus 80 gives 380; unknown stays unknown', () {
    final f = mountingFixture();
    expect(dimension(f).heightAboveSlabMm, 380);
    expect(dimension(f, slab: null).heightAboveSlabMm, isNull);
    expect(dimension(f, slab: 0).heightAboveSlabMm, 300);
  });
  test('JSON and floor undo preserve reference source and precision', () {
    final f = mountingFixture();
    final p = f.electricalPoints.single;
    ElectricalMountingService.apply(f, p, dimension(f, distance: 600.125));
    final snapshot = FloorPlan.fromJson(
      jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>,
    );
    f.nodes[1].xMm = 3500;
    expect(ElectricalMountingService.problem(f, p), isNotNull);
    f.restoreFrom(snapshot);
    expect(f.electricalPoints.single.mounting!.distanceMm, 600.125);
    expect(f.electricalPoints.single.mounting!.source, MountingSource.designed);
    expect(
      ElectricalMountingService.problem(f, f.electricalPoints.single),
      isNull,
    );
  });
  for (final value in [-1.0, double.nan, double.infinity, 3200.01]) {
    test('invalid distance $value cannot partially mutate the point', () {
      final f = mountingFixture();
      final p = f.electricalPoints.single;
      final before = jsonEncode(p.toJson());
      expect(
        () => ElectricalMountingService.apply(
          f,
          p,
          dimension(f, distance: value),
        ),
        throwsFormatException,
      );
      expect(jsonEncode(p.toJson()), before);
    });
  }
  test('door centre collision is rejected; higher position clears opening', () {
    final f = mountingFixture();
    f.walls.single.openings.add(
      WallOpening(
        id: 'door',
        type: OpeningType.door,
        widthMm: 900,
        heightMm: 2100,
        offsetFromStartMm: 500,
      ),
    );
    expect(
      () => ElectricalMountingService.resolve(f, dimension(f)),
      throwsFormatException,
    );
    expect(
      ElectricalMountingService.resolve(f, dimension(f, height: 2300)).xMm,
      700,
    );
  });
  test(
    'changed point, opening, side or wall never keeps an up-to-date result',
    () {
      for (final mutate in <void Function(FloorPlan, ElectricalPoint)>[
        (f, p) => p.xMm += 1,
        (f, p) => p.wallSide = -1,
        (f, p) => p.heightMm += 10,
        (f, p) => p.wallOffsetMm = null,
        (f, p) => f.walls.single.thicknessMm += 20,
        (f, p) => f.walls.clear(),
        (f, p) => f.nodes.removeLast(),
      ]) {
        final f = mountingFixture();
        final p = f.electricalPoints.single;
        ElectricalMountingService.apply(f, p, dimension(f));
        mutate(f, p);
        expect(ElectricalMountingService.problem(f, p), isNotNull);
      }
    },
  );
  test('stale editor snapshot cannot overwrite changed geometry', () {
    final f = mountingFixture();
    final m = dimension(f);
    f.nodes[1].xMm += 30;
    expect(
      () => ElectricalMountingService.apply(f, f.electricalPoints.single, m),
      throwsFormatException,
    );
    expect(f.electricalPoints.single.mounting, isNull);
  });
  test('unsupported curved wall and missing datum are rejected', () {
    final f = mountingFixture();
    expect(
      () => ElectricalMountingService.resolve(f, dimension(f, node: 'deleted')),
      throwsFormatException,
    );
    f.walls.single.curveGroupId = 'curve';
    expect(
      () => ElectricalMountingService.resolve(f, dimension(f)),
      throwsFormatException,
    );
  });
}
