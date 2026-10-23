import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_board_draft_service.dart';

void main() {
  FloorPlan sample() => FloorPlan(id: 'f', name: 'Щит', electricalPoints: [
    ElectricalPoint(id: 'k1', type: ElectricalPointType.appliance,
      xMm: 0, yMm: 0, circuit: 'Кухня', powerW: 2000),
    ElectricalPoint(id: 'k2', type: ElectricalPointType.socket,
      xMm: 1000, yMm: 3000, circuit: 'Кухня', powerW: 400),
    ElectricalPoint(id: 'l1', type: ElectricalPointType.ceilingLight,
      xMm: 0, yMm: 0, circuit: 'Свет', powerW: 120),
    ElectricalPoint(id: 'l2', type: ElectricalPointType.switchPoint,
      xMm: 0, yMm: 2000, circuit: 'Свет', powerW: 0),
  ], electricalRuns: [
    ElectricalRun(id: 'k-wire', startPointId: 'k1', endPointId: 'k2',
      cable: 'ВВГнг-LS 3×2.5', routeMode: 'orthogonal', reservePct: 10),
    ElectricalRun(id: 'l-wire', startPointId: 'l1', endPointId: 'l2',
      cable: 'ВВГнг-LS 3×1.5', routeMode: 'direct', reservePct: 0),
  ]);

  test('draft creates a distinct logical cabinet section for each circuit', () {
    final board = ElectricalBoardDraftService.create(sample());
    expect(board.circuits.length, 2);
    expect(board.knownConnectedWatts, 2520);
    expect(board.knownLoadAmps, closeTo(2520 / 230, .00001));
    expect(board.unratedLoads, 0);
    expect(board.sections.map((e) => e.id), [
      'supply', 'protection', 'circuit-0', 'circuit-1', 'reserve',
    ]);
    expect(board.isComplete, isFalse);
    expect(board.protectionStatus, contains('не выполнен'));
    expect(board.requiredChecks.length, greaterThanOrEqualTo(6));
  });

  test('route lengths and cable labels follow the group and reserve', () {
    final board = ElectricalBoardDraftService.create(sample());
    final kitchen = board.circuits.firstWhere((e) => e.load.name == 'Кухня');
    final light = board.circuits.firstWhere((e) => e.load.name == 'Свет');
    expect(kitchen.routedCableMeters, closeTo(4.4, .0001));
    expect(light.routedCableMeters, closeTo(2, .0001));
    expect(kitchen.runCount, 1);
    expect(kitchen.cableTypes, ['ВВГнг-LS 3×2.5']);
    expect(kitchen.load.estimatedAmps, closeTo(2400 / 230, .0001));
    expect(light.load.unratedCount, 0,
      reason: 'A light switch controls power but is not an unknown load');
  });

  test('cross-group cable is flagged, never charged to either circuit', () {
    final floor = sample();
    floor.electricalRuns.add(ElectricalRun(
      id: 'cross', startPointId: 'k2', endPointId: 'l1'));
    final board = ElectricalBoardDraftService.create(floor);
    expect(board.crossCircuitRuns, 1);
    expect(board.circuits.every((e) => e.crossCircuitRuns == 1), isTrue);
    expect(board.circuits.firstWhere((e) => e.load.name == 'Кухня')
        .routedCableMeters, closeTo(4.4, .0001));
    expect(board.circuits.every((e) => e.incomplete), isTrue);
  });

  test('unknown outlet rating does not become a safe zero current', () {
    final floor = FloorPlan(id: 'f', name: 'Новая квартира', electricalPoints: [
      ElectricalPoint(id: 'p', type: ElectricalPointType.socket,
        xMm: 0, yMm: 0, circuit: '', powerW: 0),
    ]);
    final board = ElectricalBoardDraftService.create(floor);
    expect(board.unratedLoads, 1);
    expect(board.knownConnectedWatts, 0);
    expect(board.circuits.single.hasUnassignedCircuit, isTrue);
    expect(board.circuits.single.incomplete, isTrue);
    expect(board.isComplete, isFalse);
    expect(board.circuits.single.protectiveDeviceStatus,
      contains('Требует'));
  });

  test('invalid supply assumptions throw rather than emit misleading values', () {
    expect(() => ElectricalBoardDraftService.create(sample(),
      voltageV: 0), throwsArgumentError);
    expect(() => ElectricalBoardDraftService.create(sample(),
      powerFactor: 1.2), throwsArgumentError);
  });

  test('no invented breakers or arbitrary DIN module widths', () {
    final board = ElectricalBoardDraftService.create(
      FloorPlan(id: 'empty', name: 'Нет точек'));
    expect(board.circuits, isEmpty);
    expect(board.sections.length, 3);
    expect(board.sections.first.label, 'Ввод');
    expect(board.sections.last.label, 'Резерв');
    expect(board.sections.every((s) => s.role.isNotEmpty), isTrue);
  });
}
