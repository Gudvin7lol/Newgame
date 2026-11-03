import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_din_layout_service.dart';
import 'package:zamer_app/services/electrical_issue_register_service.dart';
import 'package:zamer_app/widgets/electrical_din_board_editor.dart';

FloorPlan fixture() => FloorPlan(
  id: 'floor',
  name: 'Квартира',
  electricalPoints: [
    ElectricalPoint(id: 'panel', type: ElectricalPointType.panel,
        xMm: 0, yMm: 0, label: 'ЩР'),
  ],
);

ElectricalDinDeviceDraft device(
    String id, {int row = 0, int start = 0, int? width = 4}) =>
    ElectricalDinDeviceDraft(
      id: id, kind: ElectricalDinDeviceKind.rcbo,
      label: 'Аппарат $id', model: 'Паспортная модель $id',
      widthHalfModules: width, row: row,
      startHalfModule: start, positionLocked: true,
    );

void main() {
  test('explicit footprints occupy half-module slots without selecting ratings',
      () {
    final floor = fixture();
    final board = ElectricalDinBoardDraft(
      panelPointId: 'panel', rows: 2, modulesPerRow: 12,
      devices: [device('a', width: 3), device('b', start: 3, width: 4)],
    );
    final report = ElectricalDinLayoutService.inspect(floor, board);
    expect(report.totalHalfModules, 48);
    expect(report.occupiedHalfModules, 7);
    expect(report.freeHalfModules, 41);
    expect(report.issues, isEmpty);
    expect(report.approvedForInstallation, isFalse);
  });

  test('overlap does not inflate physically occupied half-module count', () {
    final floor = fixture();
    final board = ElectricalDinBoardDraft(
      panelPointId: 'panel', rows: 1, modulesPerRow: 6,
      devices: [device('a', width: 4), device('b', start: 3, width: 4)],
    );
    final result = ElectricalDinLayoutService.inspect(floor, board);
    expect(result.occupiedHalfModules, 7);
    expect(result.freeHalfModules, 5);
    expect(result.issues.map((e) => e.code), contains('overlap'));
  });

  test('out-of-range locked device stays saved but is never silently moved',
      () {
    final floor = fixture();
    final board = ElectricalDinBoardDraft(
      panelPointId: 'panel', rows: 1, modulesPerRow: 6,
      devices: [device('locked', row: 2, width: 8)],
    );
    final snapshot = board.toJson().toString();
    final result = ElectricalDinLayoutService.inspect(floor, board);
    expect(result.issues.map((e) => e.code), contains('outOfRail'));
    expect(result.occupiedHalfModules, 0);
    expect(board.devices.single.positionLocked, isTrue);
    expect(board.toJson().toString(), snapshot);
  });

  test('absent cabinet capacity, unknown widths and incomplete placement stay visible',
      () {
    final board = ElectricalDinBoardDraft(panelPointId: 'panel', devices: [
      const ElectricalDinDeviceDraft(
        id: 'unknown', model: '', widthHalfModules: null,
        positionLocked: true,
      ),
    ]);
    final report = ElectricalDinLayoutService.inspect(fixture(), board);
    expect(report.totalHalfModules, isNull);
    expect(report.issues.map((e) => e.code),
        containsAll(['unknownRails', 'unknownFootprint', 'unplacedDevice']));
    expect(report.approvedForInstallation, isFalse);
  });

  test('deleted panel, ambiguous ID and stale physical circuit all detected',
      () {
    final floor = fixture();
    final board = ElectricalDinBoardDraft(
      panelPointId: 'panel', rows: 1, modulesPerRow: 12,
      devices: [
        ElectricalDinDeviceDraft(
          id: 'a', model: 'X', widthHalfModules: 2,
          circuitId: 'deleted', row: 0, startHalfModule: 0,
        ),
        ElectricalDinDeviceDraft(
          id: 'a', model: 'Y', widthHalfModules: 2,
          row: 0, startHalfModule: 1,
        ),
      ],
    );
    floor.electricalPoints.clear();
    final result = ElectricalDinLayoutService.inspect(floor, board);
    expect(result.issues.map((e) => e.code),
        containsAll(['invalidPanel', 'duplicateDevice', 'invalidCircuit',
          'overlap']));
  });

  test('DIN overlap is a navigable blocking error in unified issue register',
      () {
    final floor = fixture();
    floor.electricalDesignDraft = ElectricalDesignDraft(dinBoards: {
      'panel': ElectricalDinBoardDraft(
        panelPointId: 'panel', rows: 1, modulesPerRow: 6,
        devices: [device('a', width: 4), device('b', start: 3, width: 4)],
      ),
    });
    final before = floor.toJson().toString();
    final entries = ElectricalIssueRegisterService.inspect(floor).entries;
    final overlap = entries.singleWhere((e) => e.code == 'din:overlap');
    expect(overlap.severity, ElectricalIssueSeverity.error);
    expect(overlap.focusPointId, 'panel');
    expect(overlap.objectId, 'panel');
    expect(floor.toJson().toString(), before);
  });

  test('persisted DIN layout survives FloorPlan JSON and undo restore', () {
    final floor = fixture();
    final board = ElectricalDinBoardDraft(
      panelPointId: 'panel', rows: 2, modulesPerRow: 12,
      devices: [device('locked', row: 1, start: 5, width: 3)],
    );
    floor.electricalDesignDraft = ElectricalDesignDraft(
      dinBoards: {'panel': board},
    );
    final snapshot = floor.toJson().toString();
    final restored = FloorPlan.fromJson(floor.toJson());
    final unit = restored.electricalDesignDraft!.dinBoards['panel']!
        .devices.single;
    expect(unit.positionLocked, isTrue);
    expect(unit.row, 1);
    expect(unit.startHalfModule, 5);
    expect(unit.widthHalfModules, 3);
    expect(restored.toJson().toString(), snapshot);
    expect(() => ElectricalDesignDraft.fromJson({
      'dinBoards': {
        'wrong': ElectricalDinBoardDraft(panelPointId: 'panel').toJson(),
      },
    }), throwsFormatException);
  });

  test('fractional stored half-slot numbers are rejected, not rounded', () {
    expect(() => ElectricalDinDeviceDraft.fromJson({
      'id': 'bad',
      'widthHalfModules': 2.5,
    }), throwsFormatException);
    expect(() => ElectricalDinBoardDraft.fromJson({
      'panelPointId': 'panel',
      'rows': 1.5,
      'modulesPerRow': 12,
    }), throwsFormatException);
  });

  testWidgets('mobile DIN editor saves rail size and a locked device',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = fixture();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(
        child: ElectricalDinBoardEditor(
          floor: floor,
          onSave: (board) async {
            floor.electricalDesignDraft ??= ElectricalDesignDraft();
            floor.electricalDesignDraft!.dinBoards[board.panelPointId] =
                ElectricalDinBoardDraft.fromJson(board.toJson());
            saves++;
          },
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('din-configure')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('din-rail-rows')), '2');
    await tester.enterText(
        find.byKey(const ValueKey('din-rail-modules')), '12');
    await tester.tap(find.byKey(const ValueKey('din-save-enclosure')));
    await tester.pumpAndSettle();
    final saved = floor.electricalDesignDraft!.dinBoards['panel']!;
    expect(saved.rows, 2);
    expect(saved.modulesPerRow, 12);
    expect(find.byKey(const ValueKey('din-rail-preview-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('din-cell-0-0')),
        findsOneWidget);

    final add = find.byKey(const ValueKey('din-add-device'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('din-device-label')), 'QF1');
    await tester.enterText(
        find.byKey(const ValueKey('din-device-model')), 'Модель X');
    await tester.enterText(
        find.byKey(const ValueKey('din-device-width')), '1.5');
    await tester.enterText(
        find.byKey(const ValueKey('din-device-row')), '1');
    await tester.enterText(
        find.byKey(const ValueKey('din-device-position')), '2.5');
    final lock = find.byKey(const ValueKey('din-device-lock'));
    await tester.ensureVisible(lock);
    await tester.pumpAndSettle();
    await tester.tap(lock);
    await tester.tap(find.byKey(const ValueKey('din-save-device')));
    await tester.pumpAndSettle();

    final d = floor.electricalDesignDraft!.dinBoards['panel']!.devices.single;
    expect(d.label, 'QF1');
    expect(d.widthHalfModules, 3);
    expect(d.row, 0);
    expect(d.startHalfModule, 3);
    expect(d.positionLocked, isTrue);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });
}
