import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_din_layout_proposal_service.dart';
import 'package:zamer_app/widgets/electrical_din_board_editor.dart';

FloorPlan _floor() => FloorPlan(
  id: 'f',
  name: 'Тест',
  electricalPoints: [
    ElectricalPoint(id: 'p', type: ElectricalPointType.panel,
        xMm: 0, yMm: 0, label: 'ЩР'),
  ],
);

ElectricalDinDeviceDraft _device(String id, {
    required int width, int? row, int? start,
    bool locked = false, String model = 'Паспорт X'}) =>
    ElectricalDinDeviceDraft(
      id: id,
      label: id,
      model: model,
      kind: ElectricalDinDeviceKind.other,
      widthHalfModules: width,
      row: row,
      startHalfModule: start,
      positionLocked: locked,
    );

ElectricalDinBoardDraft _board({int rows = 1, int modules = 6,
    required List<ElectricalDinDeviceDraft> devices}) =>
    ElectricalDinBoardDraft(
      panelPointId: 'p',
      rows: rows,
      modulesPerRow: modules,
      devices: devices,
    );

void main() {
  test('stable packing reserves locked half-modules and never mutates source',
      () {
    final f = _floor();
    final b = _board(devices: [
      _device('fixed', width: 3, row: 0, start: 2, locked: true),
      _device('small', width: 2),
      _device('wide', width: 4),
    ]);
    final snapshot = b.toJson().toString();
    final p1 = ElectricalDinLayoutProposalService.propose(f, b);
    final p2 = ElectricalDinLayoutProposalService.propose(f, b);
    expect(p1.canApply, isTrue);
    expect(p1.problems, isEmpty);
    expect(p1.changes, hasLength(2));
    expect(p1.preview!.devices.map((e) => e.id),
        ['fixed', 'small', 'wide']);
    final positions = {for (final d in p1.preview!.devices)
        d.id: (d.row, d.startHalfModule)};
    expect(positions['fixed'], (0, 2));
    expect(positions['wide'], (0, 5));
    expect(positions['small'], (0, 0));
    expect(p1.preview!.devices.first.positionLocked, isTrue);
    expect(p2.preview!.toJson().toString(), p1.preview!.toJson().toString());
    expect(b.toJson().toString(), snapshot);
    expect(f.electricalDesignDraft, isNull);
    expect(p1.approvedForInstallation, isFalse);
  });

  test('unlocked stale position is reflowed rather than blocking valid layout',
      () {
    final b = _board(devices: [
      _device('locked', width: 2, row: 0, start: 0, locked: true),
      _device('free', width: 2, row: 99, start: 99),
    ]);
    final proposal = ElectricalDinLayoutProposalService.propose(_floor(), b);
    expect(proposal.canApply, isTrue);
    expect(proposal.preview!.devices[1].row, 0);
    expect(proposal.preview!.devices[1].startHalfModule, 2);
    expect(b.devices[1].row, 99);
  });

  test('overlapping locked devices fail atomically', () {
    final b = _board(devices: [
      _device('A', width: 4, row: 0, start: 1, locked: true),
      _device('B', width: 4, row: 0, start: 3, locked: true),
      _device('C', width: 2),
    ]);
    final snapshot = b.toJson().toString();
    final proposal = ElectricalDinLayoutProposalService.propose(_floor(), b);
    expect(proposal.canApply, isFalse);
    expect(proposal.preview, isNull);
    expect(proposal.changes, isEmpty);
    expect(proposal.problems.join(' '), contains('пересекаются'));
    expect(b.toJson().toString(), snapshot);
  });

  test('insufficient contiguous slots does not partially move any device', () {
    final b = _board(modules: 4, devices: [
      _device('fixed', width: 2, row: 0, start: 3, locked: true),
      _device('wide', width: 4),
      _device('small', width: 3),
    ]);
    final snapshot = b.toJson().toString();
    final proposal = ElectricalDinLayoutProposalService.propose(_floor(), b);
    expect(proposal.canApply, isFalse);
    expect(proposal.preview, isNull);
    expect(proposal.changes, isEmpty);
    expect(proposal.problems.join(' '), contains('Недостаточно'));
    expect(b.toJson().toString(), snapshot);
  });

  test('locked out-of-bounds position cannot be moved automatically', () {
    final b = _board(devices: [
      _device('locked', width: 4, row: 8, start: 0, locked: true),
      _device('free', width: 2),
    ]);
    final proposal = ElectricalDinLayoutProposalService.propose(_floor(), b);
    expect(proposal.canApply, isFalse);
    expect(proposal.preview, isNull);
    expect(b.devices.first.row, 8);
  });

  test('unknown footprint and stale circuit cannot be guessed', () {
    final b = _board(devices: [
      _device('unknown', width: 2, model: ''),
    ]);
    expect(ElectricalDinLayoutProposalService.propose(_floor(), b)
        .problems.join(' '), contains('паспортной ширины'));
    final stale = _board(devices: [
      ElectricalDinDeviceDraft(
        id: 'stale',
        model: 'Model 1',
        widthHalfModules: 2,
        circuitId: 'deleted',
      ),
    ]);
    expect(ElectricalDinLayoutProposalService.propose(_floor(), stale)
        .problems.join(' '), contains('физическую группу'));
  });

  test('complete current layout gives a no-op, never a forced save', () {
    final b = _board(devices: [
      _device('fixed', width: 2, row: 0, start: 0, locked: true),
    ]);
    final proposal = ElectricalDinLayoutProposalService.propose(_floor(), b);
    expect(proposal.preview, isNotNull);
    expect(proposal.changes, isEmpty);
    expect(proposal.canApply, isFalse);
  });

  test('multi-row packing is deterministic and retains all device metadata',
      () {
    final f = _floor();
    final b = _board(rows: 2, modules: 3, devices: [
      _device('fixed', width: 4, row: 0, start: 0, locked: true),
      _device('first', width: 3),
      _device('second', width: 3),
    ]);
    final proposal = ElectricalDinLayoutProposalService.propose(f, b);
    expect(proposal.canApply, isTrue);
    expect(proposal.preview!.devices[1].row, 1);
    expect(proposal.preview!.devices[1].startHalfModule, 0);
    expect(proposal.preview!.devices[2].row, 1);
    expect(proposal.preview!.devices[2].startHalfModule, 3);
    expect(proposal.preview!.devices[1].model, 'Паспорт X');
  });

  testWidgets('deleted source panel blocks confirming a stale DIN preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = _floor();
    f.electricalDesignDraft = ElectricalDesignDraft(dinBoards: {
      'p': _board(modules: 4, devices: [
        _device('fixed', width: 2, row: 0, start: 0, locked: true),
        _device('movable', width: 2),
      ]),
    });
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ElectricalDinBoardEditor(
        floor: f,
        onSave: (draft) async { saves++; },
      )),
    )));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('din-suggest-layout'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Предложение DIN-компоновки'), findsOneWidget);
    f.electricalPoints.clear();
    await tester.tap(find.byKey(const ValueKey('din-proposal-apply')));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(f.electricalDesignDraft!.dinBoards['p']!.devices[1].row, isNull);
    expect(find.textContaining('Исходные данные изменились'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale preview cannot overwrite a newer manual edit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = _floor();
    f.electricalDesignDraft = ElectricalDesignDraft(dinBoards: {
      'p': _board(modules: 4, devices: [
        _device('locked', width: 2, row: 0, start: 0, locked: true),
        _device('free', width: 2),
      ]),
    });
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ElectricalDinBoardEditor(
        floor: f,
        onSave: (next) async {
          f.electricalDesignDraft!.dinBoards['p'] =
              ElectricalDinBoardDraft.fromJson(next.toJson());
          saves++;
        },
      )),
    )));
    await tester.pumpAndSettle();
    final propose = find.byKey(const ValueKey('din-suggest-layout'));
    await tester.ensureVisible(propose);
    await tester.pumpAndSettle();
    await tester.tap(propose);
    await tester.pumpAndSettle();
    expect(find.text('Предложение DIN-компоновки'), findsOneWidget);

    final now = f.electricalDesignDraft!.dinBoards['p']!;
    now.devices[1] = _device('free', width: 2, row: 0, start: 5);
    await tester.tap(find.byKey(const ValueKey('din-proposal-apply')));
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(now.devices[1].startHalfModule, 5);
    expect(find.textContaining('Компоновка изменилась'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview cancel cannot change layout; confirm persists snapshot',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = _floor();
    f.electricalDesignDraft = ElectricalDesignDraft(
      dinBoards: {
        'p': _board(modules: 4, devices: [
          _device('lock', width: 2, row: 0, start: 0, locked: true),
          _device('move', width: 3),
        ]),
      },
    );
    var saves = 0;
    final before = f.toJson().toString();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ElectricalDinBoardEditor(
        floor: f,
        onSave: (next) async {
          f.electricalDesignDraft!.dinBoards['p'] =
              ElectricalDinBoardDraft.fromJson(next.toJson());
          saves++;
        },
      )),
    )));
    await tester.pumpAndSettle();

    Future<void> openSuggestion() async {
      final button = find.byKey(const ValueKey('din-suggest-layout'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Предложение DIN-компоновки'), findsOneWidget);
    }
    await openSuggestion();
    await tester.tap(find.byKey(const ValueKey('din-proposal-cancel')));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(f.toJson().toString(), before);

    await openSuggestion();
    await tester.tap(find.byKey(const ValueKey('din-proposal-apply')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    final devices = f.electricalDesignDraft!.dinBoards['p']!.devices;
    expect(devices[0].startHalfModule, 0);
    expect(devices[0].positionLocked, isTrue);
    expect(devices[1].startHalfModule, 2);
    expect(tester.takeException(), isNull);
  });
}
