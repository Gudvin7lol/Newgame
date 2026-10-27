import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_wall_face.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_wall_face_service.dart';
import 'package:zamer_app/services/electrical_wall_datum_service.dart';
import 'package:zamer_app/widgets/electrical_wall_datum_screen.dart';
import 'package:zamer_app/widgets/electrical_wall_face_screen.dart';

FloorPlan datumFixture() {
  final floor = FloorPlan(
    id: 'f', name: 'Объект', defaultHeightMm: 2700,
    nodes: [
      PlanNode(id: 'corner', xMm: 0, yMm: 0),
      PlanNode(id: 'right', xMm: 4000, yMm: 0),
      PlanNode(id: 'top', xMm: 0, yMm: 3000),
    ],
    walls: [
      PlanWall(
        id: 'primary', startNodeId: 'corner', endNodeId: 'right',
        thicknessMm: 100,
        openings: [
          WallOpening(
            id: 'door', type: OpeningType.door, widthMm: 900,
            heightMm: 2100, offsetFromStartMm: 1800,
          ),
        ],
      ),
      PlanWall(id: 'adjacent', startNodeId: 'corner', endNodeId: 'top',
          thicknessMm: 100),
    ],
    electricalPoints: [
      ElectricalPoint(
        id: 'outlet', type: ElectricalPointType.socket,
        xMm: 900, yMm: 0, heightMm: 300,
        wallId: 'primary', wallSide: 1, label: 'Розетка',
      ),
      ElectricalPoint(
        id: 'other-side', type: ElectricalPointType.socket,
        xMm: 2900, yMm: 0, heightMm: 300,
        wallId: 'primary', wallSide: -1,
      ),
    ],
  );
  ElectricalWallFaceService.apply(floor, 'primary', 1,
      const WallFaceFinish(thicknessMm: 15,
          source: WallFinishSource.design));
  ElectricalWallFaceService.apply(floor, 'adjacent', -1,
      const WallFaceFinish(thicknessMm: 15,
          source: WallFinishSource.document));
  return floor;
}

void main() {
  test('finished corner is the intersection of two known offset faces', () {
    final f = datumFixture();
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final corners = catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedCorner).toList();
    expect(corners, hasLength(1));
    expect(corners.single.uMm, closeTo(65, .001));
    expect(corners.single.neighbourWallId, 'adjacent');
    expect(corners.single.finishedReference, true);
    expect(corners.single.source, WallFinishSource.unknown);
    final dimensions = ElectricalWallDatumService.dimensions(
        f, catalog, corners.single);
    expect(dimensions, hasLength(1));
    expect(dimensions.single.pointId, 'outlet');
    expect(dimensions.single.fromDatumMm, closeTo(835, .001));
    expect(dimensions.single.heightMm, 300);
  });

  test('corner measurements are invariant under plan rotation', () {
    final f = datumFixture();
    // Rotate every point and wall around the common origin by +90°.
    for (final n in f.nodes) {
      final x = n.xMm, y = n.yMm;
      n
        ..xMm = -y
        ..yMm = x;
    }
    for (final p in f.electricalPoints) {
      final x = p.xMm, y = p.yMm;
      p
        ..xMm = -y
        ..yMm = x;
    }
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final corner = catalog.datums.singleWhere((d) =>
        d.kind == ElectricalDatumKind.finishedCorner);
    expect(corner.uMm, closeTo(65, .001));
    expect(ElectricalWallDatumService.dimensions(
        f, catalog, corner).single.fromDatumMm, closeTo(835, .001));
  });

  test('opening edges are structural only and retain axis millimetres', () {
    final f = datumFixture();
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final edges = catalog.datums.where((d) =>
        d.openingId == 'door').toList();
    expect(edges, hasLength(2));
    expect(edges[0].uMm, 1800);
    expect(edges[1].uMm, 2700);
    expect(edges.every((d) => d.finishedReference == false), true);
    final dims = ElectricalWallDatumService.dimensions(
        f, catalog, edges.first);
    expect(dims.single.fromDatumMm, -900);
  });

  test('missing finish produces no fictional finished corner', () {
    final f = datumFixture();
    ElectricalWallFaceService.apply(f, 'adjacent', -1, null);
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    expect(catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedCorner), isEmpty);
    expect(catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.structuralOpeningStart), hasLength(1));
    expect(catalog.issues, isNotEmpty);
  });

  test('stale face orientation invalidates corner instead of silently flipping', () {
    final f = datumFixture();
    f.walls.last
      ..startNodeId = 'top'
      ..endNodeId = 'corner';
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    expect(catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedCorner), isEmpty);
    expect(catalog.issues.any((i) => i.contains('устарела')), true);
  });

  test('parallel adjacent axes cannot create a finite intersection', () {
    final f = datumFixture();
    f.nodes.last
      ..xMm = 3000
      ..yMm = 0;
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    expect(catalog.datums.where((d) =>
        d.kind == ElectricalDatumKind.finishedCorner), isEmpty);
  });

  test('invalid opening cannot define a reference station', () {
    final f = datumFixture();
    f.walls.first.openings.first.widthMm = 5000;
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    expect(catalog.datums.any((d) => d.openingId == 'door'), false);
    expect(catalog.issues.any((i) => i.contains('Проём door')), true);
  });

  test('opening beyond wall height never supplies a marking baseline', () {
    final f = datumFixture();
    f.walls.first.openings.first
      ..sillHeightMm = 900
      ..heightMm = 2100;
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    expect(catalog.datums.any((d) => d.openingId == 'door'), false);
    expect(catalog.issues.any((issue) =>
        issue.contains('Проём door')), true);
  });

  test('old or moved datum is rejected before returning centre dimensions', () {
    final f = datumFixture();
    final previous = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final corner = previous.datums.firstWhere((d) =>
        d.kind == ElectricalDatumKind.finishedCorner);
    ElectricalWallFaceService.apply(f, 'adjacent', -1,
        const WallFaceFinish(thicknessMm: 25));
    expect(() => ElectricalWallDatumService.dimensions(
        f, previous, corner), throwsFormatException);
  });

  test('datum cache expires even if coordinate U happens to stay equal', () {
    final f = datumFixture();
    final old = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final corner = old.datums.firstWhere((d) =>
        d.kind == ElectricalDatumKind.finishedCorner);
    // Stretch the adjacent wall: its axis and calculated U of the corner
    // are unchanged, but it is no longer the same surveyed model geometry.
    f.nodes.last.yMm = 3200;
    final updated = ElectricalWallDatumService.catalog(f, 'primary', 1);
    final refreshed = updated.datums.firstWhere((d) =>
        d.kind == ElectricalDatumKind.finishedCorner);
    expect(refreshed.uMm, closeTo(corner.uMm, .001));
    expect(() => ElectricalWallDatumService.dimensions(f, old, corner),
        throwsFormatException);
    expect(ElectricalWallDatumService.dimensions(f, updated, refreshed),
        isNotEmpty);
  });

  test('read-only stations never modify floor or move outlets', () {
    final f = datumFixture();
    final before = jsonEncode(f.toJson());
    final catalog = ElectricalWallDatumService.catalog(f, 'primary', 1);
    for (final datum in catalog.datums) {
      ElectricalWallDatumService.dimensions(f, catalog, datum);
    }
    expect(jsonEncode(f.toJson()), before);
  });

  testWidgets('390px datum screen shows corner, opening and signed dimensions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = datumFixture();
    await tester.pumpWidget(MaterialApp(home: ElectricalWallDatumScreen(
      floor: f, wallId: 'primary', wallSide: 1,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Базы монтажной разметки'), findsOneWidget);
    expect(find.byKey(const ValueKey('datum-base-position')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('datum-dimension-outlet')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished face opens dimensional bases without saving project',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = datumFixture();
    final before = jsonEncode(f.toJson());
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: ElectricalWallFaceScreen(
      floor: f,
      onSaveFace: (wall, side, finish) async { saves++; },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('wall-datums-open')));
    await tester.tap(find.byKey(const ValueKey('wall-datums-open')));
    await tester.pumpAndSettle();
    expect(find.text('Базы монтажной разметки'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(saves, 0);
    expect(jsonEncode(f.toJson()), before);
  });
}
