import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_din_move_service.dart';
import 'package:zamer_app/widgets/electrical_din_board_editor.dart';

FloorPlan floor() => FloorPlan(
  id: 'floor', name: 'Квартира',
  electricalPoints: [
    ElectricalPoint(id: 'panel', type: ElectricalPointType.panel,
      xMm: 0, yMm: 0, label: 'ЩР'),
  ],
);

ElectricalDinDeviceDraft apparatus(String id, {
    int? row, int? start, int? width = 2, bool locked = false,
    String model = 'Model X', String? circuitId}) =>
    ElectricalDinDeviceDraft(
      id: id,
      kind: ElectricalDinDeviceKind.breaker,
      label: id, model: model,
      widthHalfModules: width,
      row: row, startHalfModule: start,
      positionLocked: locked, circuitId: circuitId,
    );

ElectricalDinBoardDraft board(List<ElectricalDinDeviceDraft> devices,
    {int rows = 1, int capacity = 4}) =>
    ElectricalDinBoardDraft(
      panelPointId: 'panel',
      rows: rows,
      modulesPerRow: capacity,
      devices: devices,
    );

void main() {
  test('moving exactly one device preserves locked and unrelated records', () {
    final b = board([
      apparatus('fixed', row: 0, start: 0, locked: true),
      apparatus('free', row: 0, start: 2, width: 3),
      apparatus('other', row: 0, start: 6),
    ]);
    final original = b.toJson().toString();
    final result = ElectricalDinMoveService.prepare(floor(), b,
      deviceId: 'free', targetRow: 0, targetHalfModule: 3);
    // Collides with old occupied row, not with the moved item's old slots.
    expect(result.canApply, isTrue);
    expect(result.preview!.devices[1].startHalfModule, 3);
    expect(result.preview!.devices[1].widthHalfModules, 3);
    expect(result.preview!.devices[0].positionLocked, isTrue);
    expect(result.preview!.devices[2].startHalfModule, 6);
    expect(result.approvedForInstallation, isFalse);
    expect(b.toJson().toString(), original);
  });

  test('locked apparatus cannot move even into empty space', () {
    final b = board([apparatus('fixed',
      row: 0, start: 0, locked: true)]);
    final r = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'fixed', targetRow: 0, targetHalfModule: 2);
    expect(r.canApply, isFalse);
    expect(r.preview, isNull);
    expect(r.problem, contains('закреплена'));
  });

  test('target in occupied interval and exact edge are handled precisely', () {
    final b = board([
      apparatus('fixed', start: 0, row: 0, width: 3, locked: true),
      apparatus('free', start: 4, row: 0, width: 2),
    ]);
    final bad = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 2);
    expect(bad.canApply, isFalse);
    expect(bad.problem, contains('занято'));
    final good = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 3);
    expect(good.canApply, isTrue);
  });

  test('moving beyond row or end never snaps to a different row', () {
    final b = board([apparatus('free', width: 3)], capacity: 4);
    for (final (row, slot) in [(1, 0), (0, 6), (-1, 0), (0, -1)]) {
      final r = ElectricalDinMoveService.prepare(floor(), b,
          deviceId: 'free', targetRow: row, targetHalfModule: slot);
      expect(r.canApply, isFalse);
      expect(r.preview, isNull);
    }
  });

  test('missing dimensions and occupied apparatus without dimensions fail closed',
      () {
    final b = board([
      apparatus('free', width: 3),
      apparatus('other', row: 0, start: 5, width: null),
    ]);
    expect(ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 0)
        .problem, contains('неизвестная паспортная ширина'));
    b.devices[0] = apparatus('free', width: null);
    expect(ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 0)
        .problem, contains('паспортная ширина'));
  });

  test('missing panel and ambiguous device ID reject moves without mutation',
      () {
    final f = floor();
    final b = board([
      apparatus('free'),
    ]);
    final original = b.toJson().toString();
    f.electricalPoints.clear();
    expect(ElectricalDinMoveService.prepare(f, b, deviceId: 'free',
        targetRow: 0, targetHalfModule: 0).canApply, isFalse);
    final duplicated = board([
      apparatus('free'), apparatus('free'),
    ]);
    expect(ElectricalDinMoveService.prepare(floor(), duplicated,
        deviceId: 'free', targetRow: 0, targetHalfModule: 0)
        .problem, contains('Повторяется'));
    expect(b.toJson().toString(), original);
  });

  test('unresolved circuit reference blocks a mechanically plausible move',
      () {
    final b = board([apparatus('free', circuitId: 'deleted')]);
    final r = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 0);
    expect(r.canApply, isFalse);
    expect(r.problem, contains('физическая группа'));
  });

  test('multi-row move and source-equal destination preserve data', () {
    final b = board([apparatus('free', row: 0, start: 1)],
        rows: 2, capacity: 4);
    final move = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 1, targetHalfModule: 2);
    expect(move.canApply, isTrue);
    expect(move.preview!.devices.single.row, 1);
    expect(move.preview!.devices.single.startHalfModule, 2);
    final noOp = ElectricalDinMoveService.prepare(floor(), b,
        deviceId: 'free', targetRow: 0, targetHalfModule: 1);
    expect(noOp.canApply, isFalse);
    expect(noOp.problem, contains('уже находится'));
  });

  testWidgets('one-handed tap selection places an unlocked device',
      (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = floor();
    f.electricalDesignDraft = ElectricalDesignDraft(dinBoards: {
      'panel': board([
        apparatus('free', width: 2),
        apparatus('fixed', row: 0, start: 5, locked: true),
      ]),
    });
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ElectricalDinBoardEditor(
        floor: f,
        onSave: (next) async {
          f.electricalDesignDraft!.dinBoards['panel'] =
              ElectricalDinBoardDraft.fromJson(next.toJson());
          saves++;
        },
      )),
    )));
    await tester.pumpAndSettle();
    final choose = find.byKey(const ValueKey('din-device-free'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('din-selected-device')),
        findsOneWidget);
    final target = find.byKey(const ValueKey('din-cell-tap-0-2'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Переместить DIN-аппарат?'), findsOneWidget);
    expect(saves, 0);
    await tester.tap(find.byKey(const ValueKey('din-move-confirm')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(f.electricalDesignDraft!.dinBoards['panel']!.devices[0]
        .startHalfModule, 2);
    expect(f.electricalDesignDraft!.dinBoards['panel']!.devices[1]
        .startHalfModule, 5);
    expect(find.byKey(const ValueKey('din-selected-device')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag from DIN rail asks confirmation, cancel is non-mutating',
      (tester) async {
    tester.view.physicalSize = const Size(390, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = floor();
    f.electricalDesignDraft = ElectricalDesignDraft(dinBoards: {
      'panel': board([
        apparatus('move', row: 0, start: 0),
        apparatus('lock', row: 0, start: 5, locked: true),
      ]),
    });
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ElectricalDinBoardEditor(
        floor: f,
        onSave: (next) async {
          f.electricalDesignDraft!.dinBoards['panel'] =
              ElectricalDinBoardDraft.fromJson(next.toJson());
          saves++;
        },
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('din-rail-drag-move')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('din-rail-locked-lock')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('din-cell-0-2')),
        findsOneWidget);

    Future<void> drag() async {
      final start = find.byKey(const ValueKey('din-rail-drag-move'));
      final end = find.byKey(const ValueKey('din-cell-0-2'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(start));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(tester.getCenter(end));
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Переместить DIN-аппарат?'), findsOneWidget);
    }

    final original = f.toJson().toString();
    await drag();
    await tester.tap(find.byKey(const ValueKey('din-move-cancel')));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(f.toJson().toString(), original);

    await drag();
    await tester.tap(find.byKey(const ValueKey('din-move-confirm')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    final devices = f.electricalDesignDraft!.dinBoards['panel']!.devices;
    expect(devices[0].startHalfModule, 2);
    expect(devices[1].startHalfModule, 5);
    expect(devices[1].positionLocked, isTrue);
    expect(tester.takeException(), isNull);
  });
}
