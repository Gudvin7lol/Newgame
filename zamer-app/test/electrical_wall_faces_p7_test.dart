import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_wall_face.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_wall_face_service.dart';
import 'package:zamer_app/services/electrical_wall_elevation_service.dart';
import 'package:zamer_app/services/electrical_mounting_service.dart';
import 'package:zamer_app/widgets/electrical_wall_face_screen.dart';

FloorPlan faceFixture() => FloorPlan(
  id: 'f', name: 'Объект',
  nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3000, yMm: 0),
  ],
  walls: [
    PlanWall(id: 'wall', startNodeId: 'a', endNodeId: 'b',
        thicknessMm: 100),
  ],
  electricalPoints: [
    ElectricalPoint(id: 'left', type: ElectricalPointType.socket,
      xMm: 900, yMm: 0, heightMm: 300, wallId: 'wall',
      wallSide: 1, label: 'Слева'),
    ElectricalPoint(id: 'right', type: ElectricalPointType.switchPoint,
      xMm: 1700, yMm: 0, heightMm: 900, wallId: 'wall',
      wallSide: -1, label: 'Справа'),
    ElectricalPoint(id: 'unassigned', type: ElectricalPointType.socket,
      xMm: 1800, yMm: 10, heightMm: 300, label: 'Без стены'),
  ],
);

void main() {
  test('new projects do not invent finish thickness for either wall side', () {
    final f = faceFixture();
    final left = ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0);
    final right = ElectricalWallFaceService.project(f, 'wall', -1,
        xMm: 1700, yMm: 0);
    expect(left.faceKnown, false);
    expect(left.signedDistanceToFaceMm, isNull);
    expect(right.signedDistanceToFaceMm, isNull);
    expect(f.walls.single.electricalFaceLeft, isNull);
  });

  test('left and right finishes independently compute signed face offsets', () {
    final f = faceFixture();
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 13,
            source: WallFinishSource.design));
    final left = ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0);
    expect(left.uMm, 900);
    expect(left.offsetFromAxisMm, 0);
    expect(left.signedFaceOffsetMm, 63);
    expect(left.signedDistanceToFaceMm, -63);
    expect(left.surveyedFinish, false);
    expect(ElectricalWallFaceService.project(f, 'wall', -1,
        xMm: 900, yMm: 0).signedDistanceToFaceMm, isNull);
    ElectricalWallFaceService.apply(f, 'wall', -1,
        const WallFaceFinish(thicknessMm: 20,
            source: WallFinishSource.measured));
    final right = ElectricalWallFaceService.project(f, 'wall', -1,
        xMm: 1700, yMm: 0);
    expect(right.signedFaceOffsetMm, -70);
    expect(right.signedDistanceToFaceMm, 70);
    expect(right.surveyedFinish, true);
  });

  test('explicit zero-mm finish differs from missing finish', () {
    final f = faceFixture();
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 0));
    expect(ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0).signedDistanceToFaceMm, -50);
    ElectricalWallFaceService.apply(f, 'wall', 1, null);
    expect(ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0).signedDistanceToFaceMm, isNull);
  });

  test('reverse wall orientation flips left/right projection in world space', () {
    final f = faceFixture();
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 10));
    final before = ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0);
    f.walls.single
      ..startNodeId = 'b'
      ..endNodeId = 'a';
    expect(before.signedDistanceToFaceMm, -60);
    expect(before.uMm, 900);
    expect(() => ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0), throwsFormatException);
    expect(ElectricalWallFaceService.orientationProblem(
        f.walls.single, 1), isNotNull);
    // A deliberate new confirmation is required: left/right has changed.
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 10));
    final after = ElectricalWallFaceService.project(f, 'wall', 1,
        xMm: 900, yMm: 0);
    expect(after.signedDistanceToFaceMm, -60);
    expect(after.uMm, 2100);
  });

  test('invalid source dimensions are rejected without mutating wall', () {
    final f = faceFixture();
    final before = jsonEncode(f.toJson());
    expect(() => ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: -10)), throwsFormatException);
    expect(() => ElectricalWallFaceService.apply(f, 'wall', 0,
        const WallFaceFinish(thicknessMm: 10)), throwsFormatException);
    expect(() => ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: double.infinity)),
        throwsFormatException);
    expect(jsonEncode(f.toJson()), before);
  });

  test('JSON, clone and restore preserve independent surface data', () {
    final f = faceFixture();
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 14,
          source: WallFinishSource.document, note: 'Акт'));
    ElectricalWallFaceService.apply(f, 'wall', -1,
        const WallFaceFinish(thicknessMm: 28,
          source: WallFinishSource.measured));
    final restored = FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(f.toJson())) as Map));
    expect(restored.walls.single.electricalFaceLeft?.thicknessMm, 14);
    expect(restored.walls.single.electricalFaceLeft?.note, 'Акт');
    expect(restored.walls.single.electricalFaceRight?.thicknessMm, 28);
    expect(restored.walls.single.copyWith().electricalFaceLeft?.source,
        WallFinishSource.document);
    final blank = faceFixture();
    blank.restoreFrom(restored);
    expect(blank.walls.single.electricalFaceRight?.thicknessMm, 28);
    expect(blank.electricalPoints.first.xMm, 900);
  });

  test('changing finish does not stale axis-based mounting geometry', () {
    final f = faceFixture();
    final wall = f.walls.single;
    final original = ElectricalMountingService.snapshot(f, wall);
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 14));
    expect(ElectricalMountingService.snapshot(f, wall), original);
    // Unlike cosmetic finish metadata, structural wall width matters.
    wall.thicknessMm = 150;
    expect(ElectricalMountingService.snapshot(f, wall), isNot(original));
  });

  test('wall elevations filter explicitly assigned points by side', () {
    final f = faceFixture();
    final left = ElectricalWallElevationService.build(f, 'wall',
        wallSide: 1);
    final right = ElectricalWallElevationService.build(f, 'wall',
        wallSide: -1);
    expect(left.points.map((p) => p.pointId), ['left']);
    expect(right.points.map((p) => p.pointId), ['right']);
    expect(() => ElectricalWallElevationService.build(f, 'wall',
        wallSide: 0), throwsFormatException);
  });

  test('finish edits do not silently move existing socket coordinates', () {
    final f = faceFixture();
    final before = f.electricalPoints.first.toJson();
    ElectricalWallFaceService.apply(f, 'wall', 1,
        const WallFaceFinish(thicknessMm: 15));
    expect(f.electricalPoints.first.toJson(), before);
  });

  testWidgets('mobile face editor cancels, then saves only selected side',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = faceFixture();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: ElectricalWallFaceScreen(
      floor: f,
      onSaveFace: (id, side, finish) async {
        ElectricalWallFaceService.apply(f, id, side, finish);
        saves++;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Стороны и отделка стен'), findsOneWidget);
    expect(find.byKey(const ValueKey('face-finish-status')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('face-edit-button')));
    await tester.tap(find.byKey(const ValueKey('face-edit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tester.tap(find.byKey(const ValueKey('face-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(
        const ValueKey('face-thickness-input')), '12,5');
    await tester.tap(find.byKey(const ValueKey('face-save')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(f.walls.single.electricalFaceLeft?.thicknessMm, 12.5);
    expect(f.walls.single.electricalFaceRight, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('electrical layers menu opens face editor with persistence',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = faceFixture();
    var changed = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: f, embedded: true,
          onChanged: () async { changed++; }),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-plan-layers')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Стороны и отделка стен'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-wall-faces')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('face-edit-button')));
    await tester.tap(find.byKey(const ValueKey('face-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(
        const ValueKey('face-thickness-input')), '0');
    await tester.tap(find.byKey(const ValueKey('face-save')));
    await tester.pumpAndSettle();
    expect(changed, 1);
    expect(f.walls.single.electricalFaceLeft?.thicknessMm, 0);
    expect(tester.takeException(), isNull);
  });
}
