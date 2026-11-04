import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_circuit_path_service.dart';
import 'package:zamer_app/services/electrical_issue_register_service.dart';

FloorPlan fixture({bool withConnections = true}) {
  final floor = FloorPlan(id: 'f', name: 'Этаж', electricalPoints: [
    ElectricalPoint(id: 'panel', type: ElectricalPointType.panel,
        xMm: 0, yMm: 0),
    ElectricalPoint(id: 'rk', type: ElectricalPointType.junctionBox,
        xMm: 1000, yMm: 0),
    ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 2000, yMm: 0),
  ]);
  floor.electricalNetwork = ElectricalNetwork(
    circuits: [
      ElectricalCircuitRecord(
        id: 'C', name: 'Розетки', sourcePanelPointId: 'panel'),
    ],
    cables: [
      ElectricalCableRecord(id: 'feed', circuitId: 'C',
        fromPointId: 'panel', toPointId: 'rk', cores: [
          ElectricalCableCore(id: '1', purpose: ElectricalCorePurpose.phase),
          ElectricalCableCore(id: '2', purpose: ElectricalCorePurpose.neutral),
          ElectricalCableCore(id: '3',
            purpose: ElectricalCorePurpose.protectiveEarth),
        ]),
      ElectricalCableRecord(id: 'branch', circuitId: 'C',
        fromPointId: 'rk', toPointId: 'socket', cores: [
          ElectricalCableCore(id: '1', purpose: ElectricalCorePurpose.phase),
          ElectricalCableCore(id: '2', purpose: ElectricalCorePurpose.neutral),
          ElectricalCableCore(id: '3',
            purpose: ElectricalCorePurpose.protectiveEarth),
        ]),
    ],
    terminals: withConnections ? [
      for (final id in ['1', '2', '3'])
        ElectricalTerminalRecord(id: 'T' + id, junctionPointId: 'rk',
          members: [
            ElectricalCoreReference(cableId: 'feed', coreId: id),
            ElectricalCoreReference(cableId: 'branch', coreId: id),
          ]),
    ] : [],
  );
  return floor;
}

void main() {
  test('three distinct role paths trace through recorded RK terminals', () {
    final floor = fixture();
    final before = floor.toJson().toString();
    expect(ElectricalCircuitPathService.inspect(floor), isEmpty);
    expect(floor.toJson().toString(), before);
  });

  test('missing PE terminal is a review, not approved by equal marks', () {
    final floor = fixture();
    floor.electricalNetwork!.terminals.removeLast();
    final before = floor.toJson().toString();
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.code, 'unverifiedPanelPath');
    expect(issues.single.cableId, 'branch');
    expect(issues.single.message, contains('PE'));
    expect(issues.single.message, isNot(contains('для L')));
    final register = ElectricalIssueRegisterService.inspect(floor).entries;
    final linked = register.singleWhere((e) =>
      e.code == 'unverifiedPanelPath' && e.objectId == 'branch');
    expect(linked.severity, ElectricalIssueSeverity.review);
    expect(linked.focusPointId, 'rk');
    expect(floor.toJson().toString(), before);
  });

  test('same junction and same L/N/PE roles do not imply connections', () {
    final floor = fixture(withConnections: false);
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.cableId, 'branch');
    expect(issues.single.message, contains('L'));
    expect(issues.single.message, contains('N'));
    expect(issues.single.message, contains('PE'));
  });

  test('empty unassigned feed does not manufacture a source link', () {
    final floor = fixture();
    floor.electricalNetwork!.cables.removeAt(0);
    final snapshot = floor.toJson().toString();
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.code, 'unverifiedPanelFeed');
    expect(issues.single.cableId, isNull);
    expect(floor.toJson().toString(), snapshot);
  });

  test('legacy circuits with no selected panel stay unverified elsewhere', () {
    final floor = fixture(withConnections: false);
    floor.electricalNetwork!.circuits.single.sourcePanelPointId = null;
    expect(ElectricalCircuitPathService.inspect(floor), isEmpty);
  });

  test('a reused conductor end in one RK never proves a panel path', () {
    final floor = fixture();
    final network = floor.electricalNetwork!;
    network.terminals.add(ElectricalTerminalRecord(
      id: 'duplicate', junctionPointId: 'rk',
      members: const [
        ElectricalCoreReference(cableId: 'feed', coreId: '1'),
        ElectricalCoreReference(cableId: 'branch', coreId: '1'),
      ],
    ));
    final before = floor.toJson().toString();
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.cableId, 'branch');
    expect(issues.single.message, contains('L'));
    expect(floor.toJson().toString(), before);
  });

  test('two cores of one cable cannot be a junction bridge', () {
    final floor = fixture();
    final network = floor.electricalNetwork!;
    network.terminals.removeAt(0);
    network.terminals.add(ElectricalTerminalRecord(
      id: 'self', junctionPointId: 'rk',
      members: const [
        ElectricalCoreReference(cableId: 'feed', coreId: '1'),
        ElectricalCoreReference(cableId: 'feed', coreId: '2'),
      ],
    ));
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.cableId, 'branch');
    expect(issues.single.message, contains('L'));
  });

  test('mixed-role terminal cannot fake continuity', () {
    final floor = fixture();
    final junction = floor.electricalNetwork!.terminals.first;
    junction.members
      ..clear()
      ..addAll(const [
        ElectricalCoreReference(cableId: 'feed', coreId: '1'),
        ElectricalCoreReference(cableId: 'branch', coreId: '2'),
      ]);
    final issues = ElectricalCircuitPathService.inspect(floor);
    expect(issues, hasLength(1));
    expect(issues.single.cableId, 'branch');
    expect(issues.single.message, contains('L'));
  });
}
