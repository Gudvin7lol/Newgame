import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_finished_reveal.dart';
import 'package:zamer_app/models/electrical_wall_face.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_datum_assignment_service.dart';
import 'package:zamer_app/services/electrical_opening_reveal_service.dart';
import 'package:zamer_app/services/electrical_wall_datum_service.dart';
import 'package:zamer_app/services/electrical_wall_face_service.dart';
import 'package:zamer_app/widgets/electrical_wall_datum_screen.dart';

FloorPlan assignmentFixture() {
  final floor = FloorPlan(
    id: 'floor', name: 'Квартира', defaultHeightMm: 2700,
    nodes: [
      PlanNode(id: 'A', xMm: 100, yMm: 200),
      PlanNode(id: 'B', xMm: 4100, yMm: 200),
    ],
    walls: [
      PlanWall(id: 'w', startNodeId: 'A', endNodeId: 'B',
        thicknessMm: 100,
        openings: [
          WallOpening(id: 'door', type: OpeningType.door,
              widthMm: 900, heightMm: 2100,
              offsetFromStartMm: 1800),
        ]),
    ],
    electricalPoints: [
      ElectricalPoint(id: 'socket',
          type: ElectricalPointType.socket,
          xMm: 1350, yMm: 200, heightMm: 300,
          wallId: 'w', wallSide: 1,
          label: 'Розетка'),
      ElectricalPoint(id: 'opposite',
          type: ElectricalPointType.socket,
          xMm: 3400, yMm: 200, heightMm: 300,
          wallId: 'w', wallSide: -1),
    ],
  );
  ElectricalWallFaceService.apply(floor, 'w', 1,
      const WallFaceFinish(
        thicknessMm: 12, source: WallFinishSource.design,
      ));
  ElectricalWallFaceService.apply(floor, 'w', -1,
      const WallFaceFinish(
        thicknessMm: 20, source: WallFinishSource.measured,
      ));
  ElectricalOpeningRevealService.apply(floor, 'w', 'door', 1,
      const ElectricalFinishedReveal(
        startUMm: 1822, endUMm: 2680,
        geometrySnapshot: '',
        source: OpeningRevealSource.measured,
        uncertaintyMm: 2,
      ));
  return floor;
}

const finishStart = 'opening:door:finished:start';
const roughStart = 'opening:door:start';

void main() {
  test('explicit finished opening reference stores signed size, U and Z',
      () {
    final f = assignmentFixture();
    final beforePoint = f.electricalPoints.first.toJson();
    final assignment = ElectricalDatumAssignmentService.prepare(
        f, 'socket', 'w', 1, finishStart);
    expect(assignment.datumUMm, 1822);
    expect(assignment.pointUMm, 1250);
    expect(assignment.pointHeightMm, 300);
    expect(assignment.fromDatumMm, -572);
    // Preview never moves or mutates the device.
    expect(f.electricalPoints.first.toJson(), beforePoint);
    ElectricalDatumAssignmentService.apply(f, 'socket', assignment);
    expect(f.electricalPoints.first.xMm, 1350);
    expect(ElectricalDatumAssignmentService.problem(
        f, f.electricalPoints.first), isNull);
  });

  test('rough opening cannot be saved as a finished mounting reference',
      () {
    final f = assignmentFixture();
    final before = jsonEncode(f.toJson());
    expect(
      () => ElectricalDatumAssignmentService.prepare(
          f, 'socket', 'w', 1, roughStart),
      throwsFormatException,
    );
    expect(jsonEncode(f.toJson()), before);
  });

  test('wrong side, unknown device and unassigned base are rejected',
      () {
    final f = assignmentFixture();
    expect(() => ElectricalDatumAssignmentService.prepare(
        f, 'socket', 'w', -1, finishStart), throwsFormatException);
    expect(() => ElectricalDatumAssignmentService.prepare(
        f, 'missing', 'w', 1, finishStart), throwsFormatException);
    expect(() => ElectricalDatumAssignmentService.prepare(
        f, 'opposite', 'w', -1, finishStart), throwsFormatException);
    expect(f.electricalPoints.every((p) =>
        p.datumAssignment == null), true);
  });

  test('changing point coordinates stales but does not re-position it', () {
    final f = assignmentFixture();
    final original = ElectricalDatumAssignmentService.prepare(
        f, 'socket', 'w', 1, finishStart);
    ElectricalDatumAssignmentService.apply(f, 'socket', original);
    final point = f.electricalPoints.first;
    point.xMm += 25;
    expect(ElectricalDatumAssignmentService.problem(f, point), isNotNull);
    expect(point.datumAssignment?.fromDatumMm, -572);
    final fresh = ElectricalDatumAssignmentService.prepare(
        f, 'socket', 'w', 1, finishStart);
    expect(fresh.fromDatumMm, -547);
    ElectricalDatumAssignmentService.apply(f, 'socket', fresh);
    expect(ElectricalDatumAssignmentService.problem(f, point), isNull);
    expect(point.xMm, 1375);
  });

  test('wall or reveal edits invalidate saved station automatically', () {
    final f = assignmentFixture();
    final point = f.electricalPoints.first;
    ElectricalDatumAssignmentService.apply(f, 'socket',
        ElectricalDatumAssignmentService.prepare(
            f, 'socket', 'w', 1, finishStart));
    ElectricalOpeningRevealService.apply(f, 'w', 'door', 1,
        const ElectricalFinishedReveal(
          startUMm: 1825, endUMm: 2679, geometrySnapshot: '',
          source: OpeningRevealSource.measured,
        ));
    expect(ElectricalDatumAssignmentService.problem(f, point), isNotNull);
    expect(point.datumAssignment?.datumUMm, 1822);
    ElectricalDatumAssignmentService.apply(f, 'socket',
        ElectricalDatumAssignmentService.prepare(
            f, 'socket', 'w', 1, finishStart));
    f.walls.first.openings.single.widthMm = 910;
    expect(ElectricalDatumAssignmentService.problem(f, point), isNotNull);
  });

  test('cannot apply stale selection if centre moved while saving', () {
    final f = assignmentFixture();
    final candidate = ElectricalDatumAssignmentService.prepare(
        f, 'socket', 'w', 1, finishStart);
    f.electricalPoints.first.heightMm = 450;
    final before = jsonEncode(f.toJson());
    expect(() => ElectricalDatumAssignmentService.apply(
        f, 'socket', candidate), throwsFormatException);
    expect(jsonEncode(f.toJson()), before);
  });

  test('assignment survives JSON and undo-like restore; clearing is atomic',
      () {
    final f = assignmentFixture();
    final point = f.electricalPoints.first;
    ElectricalDatumAssignmentService.apply(f, 'socket',
        ElectricalDatumAssignmentService.prepare(
            f, 'socket', 'w', 1, finishStart));
    final serial = jsonEncode(f.toJson());
    final restored = FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(serial) as Map));
    expect(restored.electricalPoints.first.datumAssignment?.fromDatumMm, -572);
    expect(ElectricalDatumAssignmentService.problem(
        restored, restored.electricalPoints.first), isNull);
    ElectricalDatumAssignmentService.apply(f, 'socket', null);
    expect(point.datumAssignment, isNull);
    expect(point.xMm, 1350);
    f.restoreFrom(restored);
    expect(f.electricalPoints.first.datumAssignment?.fromDatumMm, -572);
  });

  test('existing P1 axis datum and P9 face remain unchanged', () {
    final f = assignmentFixture();
    final beforeOpening = jsonEncode(f.walls.first.openings.single.toJson());
    ElectricalDatumAssignmentService.apply(f, 'socket',
        ElectricalDatumAssignmentService.prepare(
            f, 'socket', 'w', 1, finishStart));
    expect(jsonEncode(f.walls.first.openings.single.toJson()),
        beforeOpening);
    expect(f.electricalPoints.first.mounting, isNull);
    expect(f.electricalPoints.first.wallOffsetMm, isNull);
  });

  testWidgets('mobile P10 finished station can be assigned and cleared',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = assignmentFixture();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: ElectricalWallDatumScreen(
      floor: f, wallId: 'w', wallSide: 1,
      onAssign: (pointId, wallId, side, datumId) async {
        final proposal = datumId == null ? null :
            ElectricalDatumAssignmentService.prepare(
                f, pointId, wallId, side, datumId);
        ElectricalDatumAssignmentService.apply(f, pointId, proposal);
        saves++;
      },
    )));
    await tester.pumpAndSettle();
    // Opening rough-start is initially first and deliberately disabled.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('datum-assign-socket')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<IconButton>(
      find.byKey(const ValueKey('datum-assign-socket'))).onPressed, isNull);
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проём door · чистовая грань 1').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('datum-assign-socket')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('datum-assign-socket')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(f.electricalPoints.first.datumAssignment?.fromDatumMm, -572);
    await tester.tap(find.byKey(const ValueKey('datum-assign-socket')));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(f.electricalPoints.first.datumAssignment, isNull);
    expect(tester.takeException(), isNull);
  });
}
