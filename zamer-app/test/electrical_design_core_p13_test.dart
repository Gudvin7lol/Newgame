import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/services/electrical_design_engine.dart';

FloorPlan example() {
  final floor = FloorPlan(id: 'f', name: 'Этаж');
  void point(String id, ElectricalPointType type) =>
      floor.electricalPoints.add(ElectricalPoint(
          id: id, type: type, xMm: 0, yMm: 0));
  point('hob', ElectricalPointType.appliance);
  point('oven', ElectricalPointType.appliance);
  point('dish', ElectricalPointType.appliance);
  point('s1', ElectricalPointType.socket);
  point('s2', ElectricalPointType.socket);
  point('s3', ElectricalPointType.socket);
  point('s4', ElectricalPointType.socket);
  return floor;
}

ElectricalConsumerDraft consumer(
    String id, ElectricalConsumerKind kind, double power, {
    String? room = 'kitchen',
    double factor = 1,
    bool dedicated = false,
    bool wet = false,
    bool threePhase = false,
    String? lockedLine,
    String? catalog,
}) => ElectricalConsumerDraft(
    pointId: id, kind: kind, roomId: room,
    installedWatts: power, demandFactor: factor,
    isDedicated: dedicated, isWetZone: wet,
    threePhase: threePhase, lockedLineId: lockedLine,
    catalogId: catalog);

void main() {
  test('P11 plan compatibility and P13 JSON/undo preserve manual locks', () {
    final floor = example();
    final legacy = FloorPlan.fromJson(floor.toJson());
    expect(legacy.electricalDesignDraft, isNull);
    floor.electricalDesignDraft = ElectricalDesignDraft(
      settings: const ElectricalSupplyDraft(phasesCount: 3,
          inputBreakerAmps: 25),
      consumers: {'hob': consumer('hob', ElectricalConsumerKind.dedicated,
          7000, dedicated: true)},
      lineOverrides: {
        'point:hob': const ElectricalLineManualDraft(
          lineId: 'point:hob', phase: ElectricalPhase.l1,
          cableSectionMm2: 6, breakerAmps: 32,
          lockedFields: {'phase', 'breaker', 'cable'},
        ),
      },
    );
    final copy = FloorPlan.fromJson(floor.toJson());
    expect(copy.electricalDesignDraft!.settings.phasesCount, 3);
    expect(copy.electricalDesignDraft!.lineOverrides['point:hob']!
        .lockedFields.contains('breaker'), isTrue);
    floor.restoreFrom(legacy);
    expect(floor.electricalDesignDraft, isNull);
    floor.restoreFrom(copy);
    expect(floor.electricalDesignDraft!.lineOverrides['point:hob']!.phase,
        ElectricalPhase.l1);
  });

  test('separate kitchen dedicated loads from backsplash sockets', () {
    final floor = example();
    final design = ElectricalDesignDraft(consumers: {
      'hob': consumer('hob', ElectricalConsumerKind.dedicated,
          7000, factor: .8, dedicated: true),
      'oven': consumer('oven', ElectricalConsumerKind.dedicated,
          3500, factor: .8, dedicated: true),
      'dish': consumer('dish', ElectricalConsumerKind.dedicated,
          2000, factor: .8, dedicated: true, wet: true),
      for (var i = 1; i <= 4; i++)
        's$i': consumer('s$i', ElectricalConsumerKind.sockets,
            700, factor: .7, catalog: 'socket_kitchen', wet: true),
    });
    final result = ElectricalDesignEngine.calculate(floor, design);
    expect(result.lines, hasLength(4));
    expect(result.lines.where((l) => l.id.startsWith('point:')),
        hasLength(3));
    final socketLine = result.lines.singleWhere(
        (l) => l.kind == ElectricalConsumerKind.sockets);
    expect(socketLine.pointIds, hasLength(4));
    expect(socketLine.demandWatts, closeTo(1960, .001));
    expect(result.installedWatts, closeTo(15300, .001));
    expect(result.approvedForInstallation, isFalse);
    // The engine never hallucinates cable sizes or automatically accepted MCBs.
    expect(result.issues.map((e) => e.code),
        contains('UNVERIFIED_INSTALLATION'));
  });

  test('phase locks persist and unfixed lines balance around them', () {
    final floor = FloorPlan(id: '3ph', name: 'Три фазы');
    for (final id in ['a', 'b', 'c', 'light']) {
      floor.electricalPoints.add(ElectricalPoint(id: id,
          type: id == 'light' ? ElectricalPointType.ceilingLight
              : ElectricalPointType.appliance, xMm: 0, yMm: 0));
    }
    final design = ElectricalDesignDraft(
      settings: const ElectricalSupplyDraft(phasesCount: 3,
          inputBreakerAmps: 25),
      consumers: {
        for (final id in ['a', 'b', 'c'])
          id: consumer(id, ElectricalConsumerKind.dedicated,
              2200, dedicated: true),
        'light': consumer('light', ElectricalConsumerKind.lighting,
            400, room: 'kitchen'),
      },
      lineOverrides: {
        'point:a': const ElectricalLineManualDraft(
          lineId: 'point:a', phase: ElectricalPhase.l3,
          lockedFields: {'phase'},
        ),
      },
    );
    final result = ElectricalDesignEngine.calculate(floor, design);
    expect(result.lines.singleWhere((l) => l.id == 'point:a').phase,
        ElectricalPhase.l3);
    expect(result.lines.where((l) => l.phase == ElectricalPhase.l1),
        isNotEmpty);
    expect(result.lines.where((l) => l.phase == ElectricalPhase.l2),
        isNotEmpty);
  });

  test('manual protection conflict remains visible, not silently fixed', () {
    final floor = FloorPlan(id: 's', name: 'Санузел');
    floor.electricalPoints.add(ElectricalPoint(id: 'socket',
        type: ElectricalPointType.socket, xMm: 0, yMm: 0));
    final draft = ElectricalDesignDraft(
      consumers: {
        'socket': consumer('socket', ElectricalConsumerKind.sockets,
            2200, room: 'bath', wet: true),
      },
      lineOverrides: {
        'auto:sockets:bath:1': const ElectricalLineManualDraft(
          lineId: 'auto:sockets:bath:1',
          breakerAmps: 25, cableSectionMm2: 2.5,
          adjustedAmpacityAmps: 20,
          lockedFields: {'breaker', 'cable'},
        ),
      },
    );
    final result = ElectricalDesignEngine.calculate(floor, draft);
    expect(result.issues.map((e) => e.code),
        containsAll(['ERR_CABLE_OVERLOAD', 'ERR_SOCKET_RATING',
          'ERR_WET_NO_RCD']));
    expect(draft.lineOverrides['auto:sockets:bath:1']!.breakerAmps, 25);
    expect(result.approvedForInstallation, isFalse);
  });

  test('unknown demand never becomes an apparently complete zero load', () {
    final floor = FloorPlan(id: 'u', name: 'Этаж');
    floor.electricalPoints.add(ElectricalPoint(
        id: 'p', type: ElectricalPointType.socket, xMm: 0, yMm: 0));
    final result = ElectricalDesignEngine.calculate(
        floor, ElectricalDesignDraft());
    expect(result.demandWatts, isNull);
    expect(result.issues.map((e) => e.code),
        containsAll(['MISSING_LOAD_ASSUMPTIONS', 'INCOMPLETE_LOADS']));
    expect(result.approvedForInstallation, isFalse);
  });

  test('invalid supply and invalid lock payload fail closed', () {
    final design = ElectricalDesignDraft(
      settings: const ElectricalSupplyDraft(phasesCount: 2));
    expect(design.validate, throwsFormatException);
    final broken = ElectricalDesignDraft(
      lineOverrides: {
        'x': const ElectricalLineManualDraft(
          lineId: 'x', lockedFields: {'unrecognised'}),
      },
    );
    expect(broken.validate, throwsFormatException);
  });
}
