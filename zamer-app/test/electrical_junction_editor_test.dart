import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/services/electrical_junction_edit_service.dart';
import 'package:zamer_app/widgets/electrical_junction_editor.dart';

FloorPlan junctionFixture() => FloorPlan(
  id: 'f', name: 'Квартира',
  electricalPoints: [
    ElectricalPoint(id: 'j', type: ElectricalPointType.junctionBox,
        xMm: 500, yMm: 500, label: 'РК-1'),
    ElectricalPoint(id: 'p', type: ElectricalPointType.panel,
        xMm: 0, yMm: 500, label: 'ЩР'),
    ElectricalPoint(id: 's', type: ElectricalPointType.socket,
        xMm: 1500, yMm: 500, label: 'Розетка кухни'),
  ],
  electricalRuns: [
    ElectricalRun(id: 'line1', startPointId: 'j', endPointId: 'p'),
  ],
);

void main() {
  test('draft has no effects until application; legacy strings stay strings', () {
    final live = junctionFixture();
    final untouched = jsonEncode(live.toJson());
    final draft = ElectricalJunctionEditService.copy(live.electricalNetwork);
    ElectricalJunctionEditService.createCircuit(
      draft, id: 'g1', name: 'Кухня',
      kind: ElectricalCircuitKind.power,
    );
    expect(jsonEncode(live.toJson()), untouched);
    expect(live.electricalNetwork, isNull);
    expect(draft.circuits.single.name, 'Кухня');
  });

  test('explicit cable and terminal creation, validation and undo', () {
    final live = junctionFixture();
    final original = FloorPlan.fromJson(live.toJson());
    final draft = ElectricalJunctionEditService.copy(null);
    ElectricalJunctionEditService.createCircuit(
      draft, id: 'g1', name: 'Розетки', kind: ElectricalCircuitKind.power,
    );
    ElectricalJunctionEditService.createCable(
      live, draft, id: 'c1', junctionId: 'j',
      otherPointId: 'p', circuitId: 'g1', fromBox: false, coreCount: 3,
      routeRunId: 'line1',
    );
    ElectricalJunctionEditService.createCable(
      live, draft, id: 'c2', junctionId: 'j',
      otherPointId: 's', circuitId: 'g1', fromBox: true, coreCount: 3,
    );
    expect(draft.cables.first.cores.first.purpose,
        ElectricalCorePurpose.unspecified,
        reason: 'Cable core function is never guessed');
    ElectricalJunctionEditService.setCorePurpose(
      draft, cableId: 'c1', coreId: '1',
      purpose: ElectricalCorePurpose.phase,
    );
    ElectricalJunctionEditService.setCorePurpose(
      draft, cableId: 'c2', coreId: '1',
      purpose: ElectricalCorePurpose.phase,
    );
    ElectricalJunctionEditService.createTerminal(
      live, draft, id: 't1', junctionId: 'j', mark: 'L',
      members: const [
        ElectricalCoreReference(cableId: 'c1', coreId: '1'),
        ElectricalCoreReference(cableId: 'c2', coreId: '1'),
      ],
    );
    ElectricalJunctionEditService.validateForSave(live, 'j', draft);
    expect(live.electricalNetwork, isNull);
    live.electricalNetwork = ElectricalJunctionEditService.copy(draft);
    expect(live.electricalNetwork!.terminals.single.members.length, 2);
    live.restoreFrom(original);
    expect(live.electricalNetwork, isNull);
  });

  test('disallow invalid endpoints, accidental route and duplicate cable IDs', () {
    final live = junctionFixture();
    final draft = ElectricalNetwork(circuits: [
      ElectricalCircuitRecord(id: 'g', name: 'Розетки'),
    ]);
    expect(() => ElectricalJunctionEditService.createCable(
      live, draft, id: 'c', junctionId: 'j', otherPointId: 'missing',
      circuitId: 'g', fromBox: true, coreCount: 3,
    ), throwsFormatException);
    expect(() => ElectricalJunctionEditService.createCable(
      live, draft, id: 'c', junctionId: 'j', otherPointId: 's',
      circuitId: 'g', fromBox: true, coreCount: 3, routeRunId: 'line1',
    ), throwsFormatException);
    expect(draft.cables, isEmpty);
    ElectricalJunctionEditService.createCable(
      live, draft, id: 'c', junctionId: 'j', otherPointId: 's',
      circuitId: 'g', fromBox: true, coreCount: 3,
    );
    expect(() => ElectricalJunctionEditService.createCable(
      live, draft, id: 'c', junctionId: 'j', otherPointId: 's',
      circuitId: 'g', fromBox: true, coreCount: 3,
    ), throwsFormatException);
    expect(draft.cables, hasLength(1));
  });

  test('reject cross-group klemmas and duplicate termination atomically', () {
    final live = junctionFixture();
    final draft = ElectricalNetwork(circuits: [
      ElectricalCircuitRecord(id: 'g1', name: 'Первая'),
      ElectricalCircuitRecord(id: 'g2', name: 'Вторая'),
    ]);
    ElectricalJunctionEditService.createCable(
      live, draft, id: 'a', junctionId: 'j', otherPointId: 'p',
      circuitId: 'g1', fromBox: false, coreCount: 2,
    );
    ElectricalJunctionEditService.createCable(
      live, draft, id: 'b', junctionId: 'j', otherPointId: 's',
      circuitId: 'g2', fromBox: true, coreCount: 2,
    );
    const refs = [
      ElectricalCoreReference(cableId: 'a', coreId: '1'),
      ElectricalCoreReference(cableId: 'b', coreId: '1'),
    ];
    expect(() => ElectricalJunctionEditService.createTerminal(
      live, draft, id: 't', junctionId: 'j', mark: 'X', members: refs,
    ), throwsFormatException);
    expect(draft.terminals, isEmpty);
    draft.cables.last.circuitId = 'g1';
    ElectricalJunctionEditService.createTerminal(
      live, draft, id: 't', junctionId: 'j', mark: 'X', members: refs,
    );
    expect(() => ElectricalJunctionEditService.createTerminal(
      live, draft, id: 't2', junctionId: 'j', mark: 'Y', members: refs,
    ), throwsFormatException);
    expect(draft.terminals, hasLength(1));
    expect(() => ElectricalJunctionEditService.removeCable(draft, 'a'),
        throwsFormatException);
    expect(draft.cables, hasLength(2));
    ElectricalJunctionEditService.removeTerminal(draft, 't');
    ElectricalJunctionEditService.removeCable(draft, 'a');
    expect(draft.cables.map((c) => c.id), ['b']);
  });

  test('roles are not silently fused and reference validation fails safely', () {
    final live = junctionFixture();
    final draft = ElectricalNetwork(circuits: [
      ElectricalCircuitRecord(id: 'g', name: 'Питание'),
    ]);
    for (final other in ['p', 's']) {
      ElectricalJunctionEditService.createCable(
        live, draft, id: other, junctionId: 'j', otherPointId: other,
        circuitId: 'g', fromBox: false, coreCount: 1,
      );
    }
    ElectricalJunctionEditService.setCorePurpose(
      draft, cableId: 'p', coreId: '1', purpose: ElectricalCorePurpose.neutral,
    );
    ElectricalJunctionEditService.setCorePurpose(
      draft, cableId: 's', coreId: '1', purpose: ElectricalCorePurpose.phase,
    );
    expect(() => ElectricalJunctionEditService.createTerminal(
      live, draft, id: 'bad', junctionId: 'j', mark: 'X', members: const [
        ElectricalCoreReference(cableId: 'p', coreId: '1'),
        ElectricalCoreReference(cableId: 's', coreId: '1'),
      ],
    ), throwsFormatException);
    expect(draft.terminals, isEmpty);
    live.electricalPoints.removeWhere((p) => p.id == 'p');
    expect(() => ElectricalJunctionEditService.validateForSave(
      live, 'j', draft,
    ), throwsFormatException);
  });

  test('in-use point protection covers box, cable and panel', () {
    final network = ElectricalNetwork(circuits: [
      ElectricalCircuitRecord(id: 'g', name: 'Свет',
          sourcePanelPointId: 'p'),
    ], cables: [
      ElectricalCableRecord(id: 'c', circuitId: 'g',
          fromPointId: 'p', toPointId: 'j'),
    ]);
    expect(ElectricalJunctionEditService.pointInUse(network, 'j'), true);
    expect(ElectricalJunctionEditService.pointInUse(network, 'p'), true);
    expect(ElectricalJunctionEditService.pointInUse(network, 's'), false);
    expect(ElectricalJunctionEditService.pointInUse(null, 'j'), false);
  });

  testWidgets('mobile editor cancels without changing floor', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = junctionFixture();
    final before = jsonEncode(floor.toJson());
    ElectricalNetwork? saved;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            saved = await Navigator.push<ElectricalNetwork>(
              context, MaterialPageRoute(builder: (_) =>
                  ElectricalJunctionEditor(
                    floor: floor, junctionPointId: 'j',
                  )),
            );
          },
          child: const Text('Редактор'),
        ),
      ),
    )));
    await tester.tap(find.text('Редактор'));
    await tester.pumpAndSettle();
    expect(find.text('Соединения коробки'), findsOneWidget);
    expect(find.byKey(const ValueKey('junction-add-circuit')), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть без сохранения'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(jsonEncode(floor.toJson()), before);
  });

  testWidgets('UI can add a circuit and save a detached network', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = junctionFixture();
    ElectricalNetwork? saved;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            saved = await Navigator.push<ElectricalNetwork>(
              context, MaterialPageRoute(builder: (_) =>
                  ElectricalJunctionEditor(
                    floor: floor, junctionPointId: 'j',
                  )),
            );
          },
          child: const Text('Редактор'),
        ),
      ),
    )));
    await tester.tap(find.text('Редактор'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('junction-add-circuit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('junction-circuit-name')), 'Кухня',
    );
    await tester.tap(find.byKey(const ValueKey('junction-circuit-create')));
    await tester.pumpAndSettle();
    expect(find.text('Кухня'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('junction-save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.circuits.single.name, 'Кухня');
    expect(floor.electricalNetwork, isNull,
        reason: 'Editor returns draft; caller is responsible for one undoable commit');
    expect(tester.takeException(), isNull);
  });
}
