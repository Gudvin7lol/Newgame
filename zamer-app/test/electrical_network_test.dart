import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/services/electrical_network_service.dart';

FloorPlan networkFixture() {
  final floor = FloorPlan(id: 'f', name: 'Электрика', electricalPoints: [
    ElectricalPoint(id: 'board', type: ElectricalPointType.panel,
        xMm: 0, yMm: 0),
    ElectricalPoint(id: 'box', type: ElectricalPointType.junctionBox,
        xMm: 1500, yMm: 0),
    ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 3000, yMm: 0, circuit: 'Розетки'),
    ElectricalPoint(id: 'light', type: ElectricalPointType.ceilingLight,
        xMm: 4000, yMm: 0, circuit: 'Свет'),
  ], electricalRuns: [
    ElectricalRun(id: 'r1', startPointId: 'board', endPointId: 'box'),
    ElectricalRun(id: 'r2', startPointId: 'box', endPointId: 'socket'),
  ]);
  floor.electricalNetwork = ElectricalNetwork(circuits: [
    ElectricalCircuitRecord(id: 'c1', name: 'Розетки',
        kind: ElectricalCircuitKind.power, sourcePanelPointId: 'board',
        legacyGroupName: 'Розетки'),
  ], cables: [
    ElectricalCableRecord(id: 'cable1', circuitId: 'c1',
        fromPointId: 'board', toPointId: 'box', routeRunId: 'r1',
        cores: [
          ElectricalCableCore(id: 'L', purpose: ElectricalCorePurpose.phase),
          ElectricalCableCore(id: 'N', purpose: ElectricalCorePurpose.neutral),
          ElectricalCableCore(id: 'PE', purpose: ElectricalCorePurpose.protectiveEarth),
        ]),
    ElectricalCableRecord(id: 'cable2', circuitId: 'c1',
        fromPointId: 'box', toPointId: 'socket', routeRunId: 'r2',
        cores: [
          ElectricalCableCore(id: 'L', purpose: ElectricalCorePurpose.phase),
          ElectricalCableCore(id: 'N', purpose: ElectricalCorePurpose.neutral),
          ElectricalCableCore(id: 'PE', purpose: ElectricalCorePurpose.protectiveEarth),
        ]),
  ], terminals: [
    ElectricalTerminalRecord(id: 'tL', junctionPointId: 'box',
        mark: 'L', members: [
          const ElectricalCoreReference(cableId: 'cable1', coreId: 'L'),
          const ElectricalCoreReference(cableId: 'cable2', coreId: 'L'),
        ]),
    ElectricalTerminalRecord(id: 'tN', junctionPointId: 'box',
        mark: 'N', members: [
          const ElectricalCoreReference(cableId: 'cable1', coreId: 'N'),
          const ElectricalCoreReference(cableId: 'cable2', coreId: 'N'),
        ]),
    ElectricalTerminalRecord(id: 'tPE', junctionPointId: 'box',
        mark: 'PE', members: [
          const ElectricalCoreReference(cableId: 'cable1', coreId: 'PE'),
          const ElectricalCoreReference(cableId: 'cable2', coreId: 'PE'),
        ]),
  ]);
  return floor;
}

List<String> errors(FloorPlan floor) => ElectricalNetworkService.inspect(floor)
    .where((e) => e.severity == ElectricalNetworkSeverity.error)
    .map((e) => e.code)
    .toList();

void main() {
  test('legacy strings and geometric lines do not invent connectivity', () {
    final floor = networkFixture();
    floor.electricalNetwork = null;
    expect(floor.electricalPoints[2].circuit, 'Розетки');
    expect(floor.toJson().containsKey('electricalNetwork'), false);
    expect(FloorPlan.fromJson(floor.toJson()).electricalNetwork, isNull);
    expect(ElectricalNetworkService.inspect(floor).single.code, 'noNetwork');
    expect(ElectricalNetworkService.junction(floor, 'box').isMapped, isFalse);
  });

  test('explicit cable ends and terminations produce stable junction count', () {
    final floor = networkFixture();
    expect(errors(floor), isEmpty);
    expect(ElectricalNetworkService.inspect(floor), isEmpty);
    final box = ElectricalNetworkService.junction(floor, 'box');
    expect(box.isMapped, true);
    expect(box.incoming.map((e) => e.id), ['cable1']);
    expect(box.outgoing.map((e) => e.id), ['cable2']);
    expect(box.terminals.length, 3);
    expect(box.unterminatedCoreEnds, 0);
  });

  test('JSON, clone and restore preserve explicit terminal memberships', () {
    final floor = networkFixture();
    final snapshot = FloorPlan.fromJson(
        jsonDecode(jsonEncode(floor.toJson())) as Map<String, dynamic>);
    expect(snapshot.electricalNetwork!.cables[0].cores[2].purpose,
        ElectricalCorePurpose.protectiveEarth);
    floor.electricalNetwork!.terminals.clear();
    floor.electricalNetwork!.circuits.clear();
    floor.restoreFrom(snapshot);
    expect(errors(floor), isEmpty);
    expect(floor.electricalNetwork!.terminals[1].members[1].key, 'cable2/N');
    expect(floor.electricalNetwork!.circuits.first.legacyGroupName, 'Розетки');
  });

  test('project cannot silently accept a future topology schema', () {
    final raw = networkFixture().electricalNetwork!.toJson();
    raw['version'] = 3;
    expect(() => ElectricalNetwork.fromJson(raw), throwsFormatException);
  });

  test('wires drawn through a box are not joined without a terminal', () {
    final floor = networkFixture();
    floor.electricalNetwork!.terminals.clear();
    final box = ElectricalNetworkService.junction(floor, 'box');
    expect(box.incoming.length, 1);
    expect(box.outgoing.length, 1);
    expect(box.unterminatedCoreEnds, 6);
    expect(box.terminals, isEmpty);
  });

  test('references to deleted points, circuits, or routes are reported', () {
    final floor = networkFixture();
    floor.electricalPoints.removeWhere((p) => p.id == 'socket');
    floor.electricalNetwork!.circuits.clear();
    floor.electricalRuns.clear();
    final found = errors(floor);
    expect(found, contains('invalidCableEnds'));
    expect(found, contains('unknownCircuit'));
    expect(found, contains('staleRoute'));
  });

  test('same conductor end cannot be assigned to two box terminals', () {
    final floor = networkFixture();
    floor.electricalNetwork!.terminals.last.members.add(
        const ElectricalCoreReference(cableId: 'cable1', coreId: 'L'));
    expect(errors(floor), contains('doubleTermination'));
    expect(errors(floor), contains('mixedCoreRoles'));
  });

  test('box cannot connect a core on a cable that never enters the box', () {
    final floor = networkFixture();
    floor.electricalNetwork!.cables.add(ElectricalCableRecord(
        id: 'other', circuitId: 'c1', fromPointId: 'board',
        toPointId: 'light',
        cores: [ElectricalCableCore(id: 'L')]));
    floor.electricalNetwork!.terminals.first.members.add(
        const ElectricalCoreReference(cableId: 'other', coreId: 'L'));
    expect(errors(floor), contains('foreignCore'));
  });

  test('terminals cannot join different circuit IDs', () {
    final floor = networkFixture();
    floor.electricalNetwork!.circuits.add(
        ElectricalCircuitRecord(id: 'c2', name: 'Свет'));
    floor.electricalNetwork!.cables[1].circuitId = 'c2';
    expect(errors(floor), contains('mixedCircuits'));
  });

  test('wrong physical source and orphan drawing lines are visible', () {
    final floor = networkFixture();
    floor.electricalNetwork!.circuits.first.sourcePanelPointId = 'socket';
    floor.electricalNetwork!.cables.first.routeRunId = null;
    final issues = ElectricalNetworkService.inspect(floor);
    expect(issues.map((e) => e.code), contains('badPanel'));
    expect(issues.map((e) => e.code), contains('unmappedRuns'));
  });

  test('repeated core IDs are rejected within the same cable only', () {
    final floor = networkFixture();
    floor.electricalNetwork!.cables.first.cores.add(
        ElectricalCableCore(id: 'L'));
    expect(errors(floor), contains('duplicateCore'));
    // Both separate cables may legitimately name their own cores L, N, PE.
    expect(floor.electricalNetwork!.cables.last.cores.first.id, 'L');
  });

  test('missing terminal refs produce errors and incomplete terminals warn', () {
    final floor = networkFixture();
    floor.electricalNetwork!.terminals.first.members
      ..clear()
      ..add(const ElectricalCoreReference(cableId: 'gone', coreId: 'L'));
    final issues = ElectricalNetworkService.inspect(floor);
    expect(issues.map((e) => e.code), contains('unknownCore'));
    expect(issues.map((e) => e.code), contains('incompleteTerminal'));
  });
}
