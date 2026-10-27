import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_finished_reveal.dart';
import 'package:zamer_app/models/electrical_wall_face.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_mounting_service.dart';
import 'package:zamer_app/services/electrical_opening_reveal_service.dart';
import 'package:zamer_app/services/electrical_wall_datum_service.dart';
import 'package:zamer_app/services/electrical_wall_face_service.dart';
import 'package:zamer_app/widgets/electrical_finished_reveal_screen.dart';
import 'package:zamer_app/widgets/electrical_wall_face_screen.dart';

FloorPlan revealFixture() {
  final floor = FloorPlan(
    id: 'floor', name: 'Объект', defaultHeightMm: 2700,
    nodes: [
      PlanNode(id: 'a', xMm: 100, yMm: 200),
      PlanNode(id: 'b', xMm: 4100, yMm: 200),
    ],
    walls: [
      PlanWall(id: 'wall', startNodeId: 'a', endNodeId: 'b',
        thicknessMm: 100,
        openings: [
          WallOpening(id: 'door', type: OpeningType.door,
            offsetFromStartMm: 1800, widthMm: 900, heightMm: 2100),
        ]),
    ],
    electricalPoints: [
      ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 1350, yMm: 200, heightMm: 300,
        wallId: 'wall', wallSide: 1, label: 'Розетка'),
    ],
  );
  ElectricalWallFaceService.apply(floor, 'wall', 1,
    const WallFaceFinish(thicknessMm: 12,
      source: WallFinishSource.design));
  ElectricalWallFaceService.apply(floor, 'wall', -1,
    const WallFaceFinish(thicknessMm: 19,
      source: WallFinishSource.measured));
  return floor;
}

ElectricalFinishedReveal draft({
  double from = 1822, double to = 2680,
  OpeningRevealSource source = OpeningRevealSource.measured,
  double? uncertainty = 2,
}) => ElectricalFinishedReveal(
  startUMm: from,
  endUMm: to,
  geometrySnapshot: '',
  source: source,
  uncertaintyMm: uncertainty,
  note: 'Проверено по рулетке',
);

void main() {
  test('unknown finished edges differ from rough opening dimensions', () {
    final f = revealFixture();
    final o = f.walls.single.openings.single;
    expect(ElectricalOpeningRevealService.saved(o, 1), isNull);
    expect(ElectricalOpeningRevealService.saved(o, -1), isNull);
    final stations = ElectricalWallDatumService.catalog(f, 'wall', 1);
    expect(stations.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedOpeningStart), isEmpty);
    expect(stations.datums.where((d) =>
        d.kind == ElectricalDatumKind.structuralOpeningStart), hasLength(1));
  });

  test('independent per-face finished edges become true separate stations', () {
    final f = revealFixture();
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    final left = ElectricalOpeningRevealService.saved(
        f.walls.single.openings.single, 1)!;
    expect(left.startUMm, 1822);
    expect(left.endUMm, 2680);
    expect(left.source, OpeningRevealSource.measured);
    expect(left.uncertaintyMm, 2);
    expect(ElectricalOpeningRevealService.problem(
        f, 'wall', 'door', 1), isNull);

    final catalog = ElectricalWallDatumService.catalog(f, 'wall', 1);
    final finished = catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedOpeningStart ||
        d.kind == ElectricalDatumKind.finishedOpeningEnd).toList();
    expect(finished, hasLength(2));
    expect(finished[0].uMm, 1822);
    expect(finished[1].uMm, 2680);
    expect(finished[0].finishedReference, true);
    expect(finished[0].revealSource, OpeningRevealSource.measured);
    expect(catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.structuralOpeningStart).single.uMm,
        1800);
    final dim = ElectricalWallDatumService.dimensions(
        f, catalog, finished.first).single;
    expect(dim.fromDatumMm, -572);
    expect(dim.heightMm, 300);

    ElectricalOpeningRevealService.apply(f, 'wall', 'door', -1,
        draft(from: 1810, to: 2693,
            source: OpeningRevealSource.designed));
    expect(ElectricalOpeningRevealService.saved(
        f.walls.single.openings.single, 1)!.startUMm, 1822);
    expect(ElectricalOpeningRevealService.saved(
        f.walls.single.openings.single, -1)!.startUMm, 1810);
  });

  test('bad/reversed/off-wall input never partially updates a reveal', () {
    final f = revealFixture();
    final before = jsonEncode(f.toJson());
    for (final proposal in [
      draft(from: 2800, to: 2500),
      draft(from: -1, to: 2400),
      draft(from: 200, to: 5000),
      draft(from: double.nan),
      draft(uncertainty: -1),
      draft(uncertainty: double.infinity),
    ]) {
      expect(() => ElectricalOpeningRevealService.apply(
          f, 'wall', 'door', 1, proposal), throwsFormatException);
      expect(jsonEncode(f.toJson()), before);
    }
    expect(() => ElectricalOpeningRevealService.apply(
        f, 'wall', 'missing', 1, draft()), throwsFormatException);
    expect(() => ElectricalOpeningRevealService.apply(
        f, 'wall', 'door', 0, draft()), throwsFormatException);
  });

  test('saving with no finish on selected side is not allowed', () {
    final f = revealFixture();
    ElectricalWallFaceService.apply(f, 'wall', -1, null);
    expect(() => ElectricalOpeningRevealService.apply(
        f, 'wall', 'door', -1, draft()), throwsFormatException);
    expect(f.walls.single.openings.single.electricalRevealRight, isNull);
  });

  test('rough opening or finish changes stale previous finished stations', () {
    final f = revealFixture();
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    f.walls.single.openings.single.widthMm = 910;
    expect(ElectricalOpeningRevealService.problem(
        f, 'wall', 'door', 1), isNotNull);
    final catalog = ElectricalWallDatumService.catalog(f, 'wall', 1);
    expect(catalog.datums.any((d) =>
        d.kind == ElectricalDatumKind.finishedOpeningStart), false);
    expect(catalog.issues.any((s) =>
        s.contains('недостоверны')), true);
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    expect(ElectricalOpeningRevealService.problem(
        f, 'wall', 'door', 1), isNull);
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 21));
    expect(ElectricalOpeningRevealService.problem(
        f, 'wall', 'door', 1), isNotNull);
  });

  test('axis reversal cannot silently reuse saved opening-side dimension', () {
    final f = revealFixture();
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    f.walls.single
      ..startNodeId = 'b'
      ..endNodeId = 'a';
    expect(ElectricalOpeningRevealService.problem(
        f, 'wall', 'door', 1), isNotNull);
    final catalog = ElectricalWallDatumService.catalog(f, 'wall', 1);
    expect(catalog.datums.any((d) =>
        d.kind == ElectricalDatumKind.finishedOpeningStart), false);
  });

  test('JSON clone/restore and clearing preserve raw plan geometry', () {
    final f = revealFixture();
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    final j = jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>;
    final roundTrip = FloorPlan.fromJson(j);
    final opening = roundTrip.walls.single.openings.single;
    expect(opening.electricalRevealLeft?.startUMm, 1822);
    expect(opening.electricalRevealLeft?.note, 'Проверено по рулетке');
    expect(roundTrip.walls.single.copyWith().openings.single
        .electricalRevealLeft?.startUMm, 1822);
    final restored = revealFixture();
    restored.restoreFrom(roundTrip);
    expect(restored.walls.single.openings.single.electricalRevealLeft?.endUMm,
        2680);
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, null);
    expect(f.walls.single.openings.single.widthMm, 900);
    expect(f.walls.single.openings.single.electricalRevealLeft, isNull);
    expect(f.walls.single.openings.single.electricalRevealRight, isNull);
  });

  test('finish metadata cannot invalidate mounting geometry snapshot', () {
    final f = revealFixture();
    final wall = f.walls.single;
    final before = ElectricalMountingService.snapshot(f, wall);
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    expect(ElectricalMountingService.snapshot(f, wall), before);
    // Real rough opening width changes should still invalidate it.
    wall.openings.single.widthMm = 920;
    expect(ElectricalMountingService.snapshot(f, wall), isNot(before));
  });

  test('new finished station edits do not move socket or cable geometry', () {
    final f = revealFixture();
    final beforePoint = f.electricalPoints.single.toJson();
    ElectricalOpeningRevealService.apply(f, 'wall', 'door', 1, draft());
    final catalog = ElectricalWallDatumService.catalog(f, 'wall', 1);
    for (final datum in catalog.datums) {
      ElectricalWallDatumService.dimensions(f, catalog, datum);
    }
    expect(f.electricalPoints.single.toJson(), beforePoint);
  });

  testWidgets('390px mobile editor saves, then cancels without a second write',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = revealFixture();
    var writes = 0;
    await tester.pumpWidget(MaterialApp(home: ElectricalFinishedRevealScreen(
      floor: f, wallId: 'wall', wallSide: 1,
      onSave: (wall, opening, side, proposal) async {
        ElectricalOpeningRevealService.apply(
            f, wall, opening, side, proposal);
        writes++;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Чистовые грани проёмов'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reveal-edit-door')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reveal-start-input')), '1822,5');
    await tester.enterText(
        find.byKey(const ValueKey('reveal-end-input')), '2680');
    await tester.tap(find.byKey(const ValueKey('reveal-save')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(f.walls.single.openings.single.electricalRevealLeft?.startUMm,
        1822.5);
    await tester.tap(find.byKey(const ValueKey('reveal-edit-door')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P7 wall-side page can open P9 reveal editor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = revealFixture();
    final before = jsonEncode(f.toJson());
    await tester.pumpWidget(MaterialApp(home: ElectricalWallFaceScreen(
      floor: f,
      onSaveFace: (wall, side, finish) async {},
      onSaveReveal: (wall, opening, side, reveal) async {},
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('wall-reveals-open')));
    await tester.tap(find.byKey(const ValueKey('wall-reveals-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finished-reveals-screen')),
        findsOneWidget);
    expect(jsonEncode(f.toJson()), before);
    expect(tester.takeException(), isNull);
  });
}
