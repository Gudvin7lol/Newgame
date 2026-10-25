import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/wall_topology_diagnostics.dart';
import 'package:zamer_app/services/wall_topology_repair_service.dart';

FloorPlan detachedSegments() => FloorPlan(
  id: 'gap', name: 'Разрыв',
  nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 1000, yMm: 0),
    PlanNode(id: 'c', xMm: 1012, yMm: 0),
    PlanNode(id: 'd', xMm: 2000, yMm: 0),
  ],
  walls: [
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
  ],
);

FloorPlan tee({bool protectedOpening = false}) {
  final floor = FloorPlan(id: 'tee', name: 'Т-стык', nodes: [
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 2000, yMm: 0),
    PlanNode(id: 'tip', xMm: 1000, yMm: 18),
    PlanNode(id: 'out', xMm: 1000, yMm: 1200),
  ], walls: [
    PlanWall(
      id: 'host', startNodeId: 'a', endNodeId: 'b',
      openings: protectedOpening
          ? [WallOpening(
              id: 'door', type: OpeningType.door, widthMm: 500,
              heightMm: 2100, offsetFromStartMm: 750,
            )]
          : [],
    ),
    PlanWall(id: 'branch', startNodeId: 'tip', endNodeId: 'out'),
  ]);
  floor.electricalPoints.addAll([
    ElectricalPoint(
      id: 'host-socket', type: ElectricalPointType.socket,
      xMm: 300, yMm: 0, wallId: 'host', wallOffsetMm: 300,
    ),
    ElectricalPoint(
      id: 'branch-socket', type: ElectricalPointType.socket,
      xMm: 1000, yMm: 418, wallId: 'branch', wallOffsetMm: 400,
    ),
  ]);
  return floor;
}

void main() {
  test('repairs a detached endpoint by merging the real nodes', () {
    final floor = detachedSegments();
    final gaps = WallTopologyDiagnostics.findGaps(floor);
    expect(gaps.length, 1);

    final result = WallTopologyRepairService.repair(floor, gaps.single);

    expect(result.isValid, isTrue, reason: result.message);
    expect(floor.nodes.length, 3);
    expect(WallTopologyDiagnostics.findGaps(floor), isEmpty);
    expect(floor.walls.every((wall) => floor.wallLengthMm(wall) > 0), isTrue);
  });

  test('repairs a T-junction and preserves host and branch device offsets', () {
    final floor = tee();
    final gap = WallTopologyDiagnostics.findGaps(floor).single;
    expect(gap.targetWallId, 'host');
    expect(gap.target, const math.Point<double>(1000, 0));

    final result = WallTopologyRepairService.repair(floor, gap);

    expect(result.isValid, isTrue, reason: result.message);
    expect(WallTopologyDiagnostics.findGaps(floor), isEmpty);
    expect(floor.nodeDegree('tip'), 3);
    final hostSocket = floor.electricalPoints
        .firstWhere((point) => point.id == 'host-socket');
    expect(hostSocket.wallId, isNot('host'));
    expect(hostSocket.wallOffsetMm, 300);
    final branchSocket = floor.electricalPoints
        .firstWhere((point) => point.id == 'branch-socket');
    expect(branchSocket.xMm, 1000);
    expect(branchSocket.yMm, 400);
    expect(branchSocket.wallOffsetMm, 400);
  });

  test('blocked T-junction restores the complete floor', () {
    final floor = tee(protectedOpening: true);
    final before = floor.toJson().toString();
    final result = WallTopologyRepairService.repair(
      floor, WallTopologyDiagnostics.findGaps(floor).single,
    );

    expect(result.isValid, isFalse);
    expect(result.message, contains('проём'));
    expect(floor.toJson().toString(), before);
  });
}
