import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/orthogonal_wall_edit_service.dart';
import 'package:zamer_app/services/wall_drawing_service.dart';
import 'package:zamer_app/widgets/cad_wall_join_geometry.dart';

FloorPlan rectangle() {
  final f = FloorPlan(id: 'floor', name: 'Комната');
  f.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  f.walls.addAll([
    PlanWall(id: 'top', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'right', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'bottom', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'left', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return f;
}

void main() {
  test('typed 3123-mm length is exact, including at a 45-degree bearing', () {
    final origin = const math.Point<double>(0, 0);
    final endpoint = WallDrawingService.lengthEndpoint(
      start: origin, lengthMm: 3123, angleDegrees: 45,
    );
    expect(WallDrawingService.distance(origin, endpoint),
        closeTo(3123, 1e-8));
    final f = FloorPlan(id: 'f', name: 'Wall');
    f.nodes.add(PlanNode(id: 'start', xMm: 0, yMm: 0));
    final end = GeometryService.addWallFromNode(
      f,
      startNodeId: 'start',
      endPoint: endpoint,
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
      endpointCaptureMm: .5,
      endpointRoundingMm: 0,
    );
    expect(WallDrawingService.distance(origin,
        math.Point<double>(end.xMm, end.yMm)), closeTo(3123, 1e-8));
    expect(f.walls.length, 1);
    expect(f.wallLengthMm(f.walls.single), closeTo(3123, 1e-8));
  });

  test('entered length does not jump 50 mm to an unrelated nearby node', () {
    final f = FloorPlan(id: 'f', name: 'Wall');
    f.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'near', xMm: 3123, yMm: 50),
    ]);
    final end = GeometryService.addWallFromNode(
      f, startNodeId: 'a',
      endPoint: const math.Point<double>(3123, 0),
      type: WallType.exterior,
      thicknessMm: 300,
      material: WallMaterial.brick,
      endpointCaptureMm: .5,
      endpointRoundingMm: 0,
    );
    expect(end.id, isNot('near'));
    expect(end.xMm, 3123);
    expect(end.yMm, 0);
  });

  test('90-degree snap meets host wall precisely and forms a real T node', () {
    final f = FloorPlan(id: 'f', name: 'T');
    f.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'start', xMm: 2000, yMm: 1000),
    ]);
    f.walls.add(PlanWall(
      id: 'host', startNodeId: 'a', endNodeId: 'b', thicknessMm: 300,
    ));
    final snap = WallDrawingService.snap(
      f, startNodeId: 'start',
      raw: const math.Point<double>(2014, 28),
      enabled: true, angleStepDegrees: 90,
      nodeCaptureMm: 70, wallCaptureMm: 80,
    );
    expect(snap.targetWallId, 'host');
    expect(snap.point.x, closeTo(2000, .001));
    expect(snap.point.y, closeTo(0, .001));
    final end = GeometryService.addWallFromNode(
      f, startNodeId: 'start', endPoint: snap.point,
      type: WallType.partition, thicknessMm: 100,
      material: WallMaterial.drywall,
    );
    expect(f.nodeDegree(end.id), 3);
  });

  test('90-degree lock does not snap to a diagonal nearby node', () {
    final f = FloorPlan(id: 'f', name: 'Snap');
    f.nodes.addAll([
      PlanNode(id: 's', xMm: 0, yMm: 0),
      PlanNode(id: 'diagonal', xMm: 65, yMm: 3000),
    ]);
    final target = WallDrawingService.snap(
      f, startNodeId: 's',
      raw: const math.Point<double>(6, 2970),
      enabled: true, angleStepDegrees: 90,
      nodeCaptureMm: 100, wallCaptureMm: 100,
    );
    expect(target.kind, NodeSnapKind.ortho);
    expect(target.targetNodeId, isNull);
    expect(target.point.x, closeTo(0, .001));
  });

  test('45-degree snap stays on a 45-degree direction', () {
    final f = FloorPlan(id: 'f', name: 'Snap');
    f.nodes.add(PlanNode(id: 's', xMm: 0, yMm: 0));
    final target = WallDrawingService.snap(
      f, startNodeId: 's',
      raw: const math.Point<double>(1010, 980),
      enabled: true, angleStepDegrees: 45,
      nodeCaptureMm: 30, wallCaptureMm: 30,
    );
    expect(target.kind, NodeSnapKind.angle45);
    expect(target.point.x, closeTo(target.point.y, 1e-7));
  });

  test('disabled snapping does not alter touch coordinates', () {
    final f = FloorPlan(id: 'f', name: 'Snap');
    f.nodes.add(PlanNode(id: 's', xMm: 0, yMm: 0));
    const raw = math.Point<double>(987, 654);
    final target = WallDrawingService.snap(
      f, startNodeId: 's',
      raw: raw, enabled: false, angleStepDegrees: 90,
    );
    expect(target.point, raw);
    expect(target.kind, NodeSnapKind.none);
  });

  test('parallel wall shift preserves joins and both room dimensions', () {
    final f = rectangle();
    final before = f.toJson().toString();
    final moved = OrthogonalWallEditService.move(
      f, wallId: 'right', offsetMm: 300,
    );
    expect(moved.isValid, isTrue, reason: moved.message);
    expect(f.nodeById('b')!.xMm, 4300);
    expect(f.nodeById('c')!.xMm, 4300);
    expect(f.wallLengthMm(f.wallById('top')!), 4300);
    final reject = OrthogonalWallEditService.move(
      f, wallId: 'right', offsetMm: -4500,
    );
    expect(reject.isValid, isFalse);
    expect(f.nodeById('b')!.xMm, 4300);
    expect(f.toJson().toString(), isNot(before));
  });

  test('thick 300-mm host plus thin 100-mm branch has no square cap bulge', () {
    final f = FloorPlan(id: 'f', name: 'T');
    f.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'j', xMm: 2000, yMm: 0),
      PlanNode(id: 'b', xMm: 4000, yMm: 0),
      PlanNode(id: 'c', xMm: 2000, yMm: 2000),
    ]);
    f.walls.addAll([
      PlanWall(id: 'first', startNodeId: 'a', endNodeId: 'j',
        thicknessMm: 300),
      PlanWall(id: 'second', startNodeId: 'j', endNodeId: 'b',
        thicknessMm: 300),
      PlanWall(id: 'branch', startNodeId: 'j', endNodeId: 'c',
        thicknessMm: 100),
    ]);
    final solids = CadWallJoinGeometry.bodies(
      floor: f, mmToPx: 1, origin: Offset.zero,
      visibleLayers: ProjectLayer.values.toSet(),
    );
    final body = solids[ProjectLayer.existing]!;
    expect(body.contains(const Offset(2000, -140)), isTrue);
    expect(body.contains(const Offset(2000, 140)), isTrue);
    expect(body.contains(const Offset(2040, 400)), isTrue);
    expect(body.contains(const Offset(2080, 400)), isFalse);
    expect(body.contains(const Offset(2000, -175)), isFalse);
  });

  test('L joint with unequal widths adds square miter, not rounded join', () {
    final center = PlanNode(id: 'j', xMm: 0, yMm: 0);
    final a = PlanNode(id: 'a', xMm: 2000, yMm: 0);
    final b = PlanNode(id: 'b', xMm: 0, yMm: 2000);
    final patch = CadWallJoinGeometry.cornerPatch(
      center: center, a: a, b: b,
      thicknessA: 100, thicknessB: 300,
      mmToPx: 1, origin: Offset.zero,
    );
    expect(patch.length, 4);
    expect(patch[1].dx, closeTo(-150, 0.01));
    expect(patch[1].dy, closeTo(-50, 0.01));
    final f = FloorPlan(id: 'f', name: 'L');
    f.nodes.addAll([center, a, b]);
    f.walls.addAll([
      PlanWall(id: 'thin', startNodeId: 'j', endNodeId: 'a',
        thicknessMm: 100),
      PlanWall(id: 'thick', startNodeId: 'j', endNodeId: 'b',
        thicknessMm: 300),
    ]);
    final body = CadWallJoinGeometry.bodies(
      floor: f, mmToPx: 1, origin: Offset.zero,
      visibleLayers: ProjectLayer.values.toSet(),
    )[ProjectLayer.existing]!;
    expect(body.contains(const Offset(-140, -40)), isTrue);
    expect(body.contains(const Offset(-170, -60)), isFalse);
  });
}
